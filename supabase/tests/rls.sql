-- RLS + constraint tests (NFR-07: "cross-account successes = 0").
-- Run with: supabase test db   (pgTAP; everything rolls back at the end)

begin;
create extension if not exists pgtap with schema extensions;
select plan(51);

-- Two users. The sign-up trigger should give each a profile.
insert into auth.users (id, email, raw_user_meta_data) values
    ('00000000-0000-0000-0000-00000000000a', 'a@test.codey', '{"full_name": "Ana Example"}'),
    ('00000000-0000-0000-0000-00000000000b', 'b@test.codey', '{}');

select is((select count(*)::int from public.profiles), 2, 'sign-up trigger creates a profile per user');
select is((select display_name from public.profiles where id = '00000000-0000-0000-0000-00000000000a'),
          'Ana Example', 'profile takes the Google display name');
select is((select display_name from public.profiles where id = '00000000-0000-0000-0000-00000000000b'),
          'Codey Learner', 'profile falls back to the default name');

-- RLS is on for every public table.
select is(
    (select count(*)::int from pg_tables where schemaname = 'public' and not rowsecurity),
    0, 'RLS enabled on 100% of public tables');

-- ── User A creates a deck, a card, and a sync_log row ────────────────────
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select lives_ok($$
    insert into public.decks (id, title, topic_id, created_at, updated_at, server_updated_at)
    values ('10000000-0000-0000-0000-00000000000a', 'A deck', 'topic-swift', now(), now(), '2000-01-01')
$$, 'A can insert a deck (owner_id defaults to auth.uid())');

select isnt((select server_updated_at from public.decks where id = '10000000-0000-0000-0000-00000000000a'),
            '2000-01-01'::timestamptz, 'server_updated_at is set by the server, not the client');

select lives_ok($$
    insert into public.flashcards (id, deck_id, prompt, answer, code_language, code_source, difficulty, created_at, updated_at)
    values ('20000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-00000000000a',
            'What prints?', '1', 'python', 'print(1)', 'easy', now(), now())
$$, 'A can insert a card into their own deck');

select lives_ok($$
    insert into public.sync_log (entity, entity_id, op, client_ts)
    values ('deck', '10000000-0000-0000-0000-00000000000a', 'upsert', now())
$$, 'A can append to sync_log');

select is((select count(*)::int from public.decks), 1, 'A sees their deck');
select is((select count(*)::int from public.profiles), 1, 'A sees only their own profile');

-- ── Constraints mirror ModelValidator ────────────────────────────────────
select throws_ok($$
    insert into public.decks (id, title, topic_id, created_at, updated_at)
    values (gen_random_uuid(), repeat('x', 61), 'topic-swift', now(), now())
$$, '23514', null, 'title over 60 characters is rejected');

select throws_ok($$
    insert into public.decks (id, title, topic_id, created_at, updated_at)
    values (gen_random_uuid(), '   ', 'topic-swift', now(), now())
$$, '23514', null, 'whitespace-only title is rejected');

select lives_ok($$
    insert into public.flashcards (id, deck_id, prompt, answer, created_at, updated_at)
    values (gen_random_uuid(), '10000000-0000-0000-0000-00000000000a', repeat('p', 500), repeat('a', 500), now(), now())
$$, 'prompt and answer of exactly 500 characters are allowed');

select throws_ok($$
    insert into public.flashcards (id, deck_id, prompt, answer, created_at, updated_at)
    values (gen_random_uuid(), '10000000-0000-0000-0000-00000000000a', repeat('p', 501), 'a', now(), now())
$$, '23514', null, 'prompt over 500 characters is rejected');

select throws_ok($$
    insert into public.flashcards (id, deck_id, prompt, answer, code_language, created_at, updated_at)
    values (gen_random_uuid(), '10000000-0000-0000-0000-00000000000a', 'p', 'a', 'swift', now(), now())
$$, '23514', null, 'a language without source is rejected');

select throws_ok($$
    insert into public.flashcards (id, deck_id, prompt, answer, code_language, code_source, created_at, updated_at)
    values (gen_random_uuid(), '10000000-0000-0000-0000-00000000000a', 'p', 'a', 'kotlin', 'x', now(), now())
$$, '23514', null, 'an unsupported language is rejected');

select lives_ok($$
    insert into public.flashcards (id, deck_id, prompt, answer, code_language, code_source, created_at, updated_at)
    values (gen_random_uuid(), '10000000-0000-0000-0000-00000000000a', 'p', 'a', 'cpp',
            array_to_string(array_fill('x'::text, array[80]), E'\n'), now(), now())
$$, 'an 80-line snippet is allowed');

select throws_ok($$
    insert into public.flashcards (id, deck_id, prompt, answer, code_language, code_source, created_at, updated_at)
    values (gen_random_uuid(), '10000000-0000-0000-0000-00000000000a', 'p', 'a', 'cpp',
            array_to_string(array_fill('x'::text, array[81]), E'\n'), now(), now())
$$, '23514', null, 'an 81-line snippet is rejected');

-- ── User B can't see or touch any of A's rows ────────────────────────────
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';

select is((select count(*)::int from public.decks), 0, 'B sees 0 of A''s decks');
select is((select count(*)::int from public.flashcards), 0, 'B sees 0 of A''s cards');
select is((select count(*)::int from public.sync_log), 0, 'B sees 0 of A''s sync_log rows');
select is((select count(*)::int from public.profiles), 1, 'B sees only their own profile');

select throws_ok($$
    insert into public.flashcards (id, deck_id, owner_id, prompt, answer, created_at, updated_at)
    values (gen_random_uuid(), '10000000-0000-0000-0000-00000000000a',
            '00000000-0000-0000-0000-00000000000b', 'p', 'a', now(), now())
$$, '42501', null, 'B can''t insert a card into A''s deck');

select throws_ok($$
    insert into public.decks (id, owner_id, title, topic_id, created_at, updated_at)
    values (gen_random_uuid(), '00000000-0000-0000-0000-00000000000a', 'spoof', 'topic-swift', now(), now())
$$, '42501', null, 'B can''t create a deck owned by A');

with changed as (update public.decks set title = 'hacked' returning 1)
select is(count(*)::int, 0, 'B''s update of A''s deck changes 0 rows') from changed;
with gone as (delete from public.decks returning 1)
select is(count(*)::int, 0, 'B''s delete of A''s deck removes 0 rows') from gone;
with changed as (update public.profiles set total_xp = 999999
                      where id = '00000000-0000-0000-0000-00000000000a' returning 1)
select is(count(*)::int, 0, 'B can''t change A''s XP') from changed;

-- sync_log is append-only, even for your own rows.
insert into public.sync_log (entity, entity_id, op, client_ts)
values ('profile', '00000000-0000-0000-0000-00000000000b', 'upsert', now());
with changed as (update public.sync_log set op = 'delete' returning 1)
select is(count(*)::int, 0, 'sync_log rows can''t be updated') from changed;

-- ── anon sees nothing ────────────────────────────────────────────────────
set local role anon;
set local request.jwt.claims to '{"role": "anon"}';
select is((select count(*)::int from public.decks), 0, 'anon sees no decks');

-- Back as A: everything A made is intact.
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select is((select title from public.decks where id = '10000000-0000-0000-0000-00000000000a'),
          'A deck', 'A''s deck is unchanged after B''s attempts');

-- ── S3-C: avatar set (FR-04) + feedback_reports (FR-49) ──────────────────
select lives_ok($$
    update public.profiles set avatar_id = 'bolt.fill' where id = '00000000-0000-0000-0000-00000000000a'
$$, 'A can pick an avatar from the set');
select throws_ok($$
    update public.profiles set avatar_id = 'skull.fill' where id = '00000000-0000-0000-0000-00000000000a'
$$, '23514', null, 'an avatar outside the set is rejected');
select lives_ok($$
    insert into public.feedback_reports (description, app_version, os_version) values ('Button overlaps text', '1.0 (1)', '26.0')
$$, 'A can send a feedback report (owner_id defaults to auth.uid())');
select throws_ok($$
    insert into public.feedback_reports (description) values (repeat('x', 1001))
$$, '23514', null, 'a report over 1000 characters is rejected');
select is((select count(*)::int from public.feedback_reports), 0, 'reports can''t be read back, even your own');

set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select throws_ok($$
    insert into public.feedback_reports (owner_id, description) values ('00000000-0000-0000-0000-00000000000a', 'spoof')
$$, '42501', null, 'B can''t send a report as A');

-- ── S3-D: groups, weekly XP, leaderboard ─────────────────────────────────
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select lives_ok($$
    insert into public.groups (id, name, invite_code, created_by)
    values ('30000000-0000-0000-0000-00000000000a', '  CS 360  ', 'AAAAAA', '00000000-0000-0000-0000-00000000000b')
$$, 'A can create a group');
select ok((select invite_code ~ '^[A-Z0-9]{6}$' and invite_code <> 'AAAAAA' and created_by = '00000000-0000-0000-0000-00000000000a' and name = 'CS 360'
           from public.groups where id = '30000000-0000-0000-0000-00000000000a'),
          'the server sets the code and creator, and trims the name');
select is((select count(*)::int from public.group_members where group_id = '30000000-0000-0000-0000-00000000000a'),
          1, 'the creator becomes a member');
select throws_ok($$
    insert into public.group_members (group_id, user_id) values ('30000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b')
$$, '42501', null, 'memberships can only be added through join_group');
select lives_ok($$
    insert into public.weekly_xp (week_start, xp) values (date_trunc('week', now() at time zone 'utc')::date, 100);
    insert into public.weekly_xp (week_start, xp) values (date_trunc('week', now() at time zone 'utc')::date, 50)
        on conflict (owner_id, week_start) do update set xp = excluded.xp
$$, 'A can upsert their weekly XP');
select is((select xp from public.weekly_xp where owner_id = '00000000-0000-0000-0000-00000000000a'),
          100, 'weekly_xp keeps the max');
select throws_ok($$
    insert into public.weekly_xp (week_start, xp) values (date_trunc('week', now() at time zone 'utc')::date + 1, 10)
$$, '23514', null, 'week_start must be a Monday');

set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is((select count(*)::int from public.groups) + (select count(*)::int from public.group_leaderboard)
          + (select count(*)::int from public.weekly_xp),
          0, 'a non-member sees no groups, board rows, or XP');
select throws_ok($$ select public.join_group('ZZZZZZ') $$, 'P0002', null, 'an unknown code is rejected');

reset role;
select set_config('test.code', (select invite_code from public.groups where id = '30000000-0000-0000-0000-00000000000a'), true);
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is((select (public.join_group(lower(current_setting('test.code')))).id),
          '30000000-0000-0000-0000-00000000000a'::uuid, 'B joins by code, in any case');
select is((select xp from public.group_leaderboard where user_id = '00000000-0000-0000-0000-00000000000a'),
          100, 'members see each other on the board');
with gone as (delete from public.group_members where user_id = '00000000-0000-0000-0000-00000000000a' returning 1)
select is(count(*)::int, 0, 'B can''t remove A from the group') from gone;

-- ── weekly_xp pace limit: 600 XP per minute of server time ─────────
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
insert into public.weekly_xp (week_start, xp) values (date_trunc('week', now() at time zone 'utc')::date, 22500)
    on conflict (owner_id, week_start) do update set xp = excluded.xp;
select is((select xp from public.weekly_xp where owner_id = '00000000-0000-0000-0000-00000000000a'),
          100, 'a jump with no time elapsed is clamped to the last value');

-- Pretend A's last accepted write was 10 minutes ago. The stamping trigger
-- is switched off for that one update (rolled back with the rest).
reset role;
alter table public.weekly_xp disable trigger weekly_xp_before_update;
update public.weekly_xp set updated_at = now() - interval '10 minutes'
    where owner_id = '00000000-0000-0000-0000-00000000000a';
alter table public.weekly_xp enable trigger weekly_xp_before_update;
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
insert into public.weekly_xp (week_start, xp) values (date_trunc('week', now() at time zone 'utc')::date, 22500)
    on conflict (owner_id, week_start) do update set xp = excluded.xp;
select is((select xp from public.weekly_xp where owner_id = '00000000-0000-0000-0000-00000000000a'),
          6100, 'ten minutes later the cap is the last value + 6,000');

-- A brand-new row can claim at most 30 minutes' worth (18,000).
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
insert into public.weekly_xp (week_start, xp) values (date_trunc('week', now() at time zone 'utc')::date, 22500);
select ok((select xp from public.weekly_xp where owner_id = '00000000-0000-0000-0000-00000000000b') <= 18000,
          'a first write can''t claim the whole week');

select * from finish();
rollback;
