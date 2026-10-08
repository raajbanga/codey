-- RLS + constraint tests (NFR-07: "cross-account successes = 0").
-- Run with: supabase test db   (pgTAP; everything rolls back at the end)

begin;
create extension if not exists pgtap with schema extensions;
select plan(30);

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

select is(
    (with changed as (update public.decks set title = 'hacked' returning 1) select count(*)::int from changed),
    0, 'B''s update of A''s deck changes 0 rows');
select is(
    (with gone as (delete from public.decks returning 1) select count(*)::int from gone),
    0, 'B''s delete of A''s deck removes 0 rows');
select is(
    (with changed as (update public.profiles set total_xp = 999999
                      where id = '00000000-0000-0000-0000-00000000000a' returning 1)
     select count(*)::int from changed),
    0, 'B can''t change A''s XP');

-- sync_log is append-only, even for your own rows.
insert into public.sync_log (entity, entity_id, op, client_ts)
values ('profile', '00000000-0000-0000-0000-00000000000b', 'upsert', now());
select is(
    (with changed as (update public.sync_log set op = 'delete' returning 1) select count(*)::int from changed),
    0, 'sync_log rows can''t be updated');

-- ── anon sees nothing ────────────────────────────────────────────────────
set local role anon;
set local request.jwt.claims to '{"role": "anon"}';
select is((select count(*)::int from public.decks), 0, 'anon sees no decks');

-- Back as A: everything A made is intact.
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select is((select title from public.decks where id = '10000000-0000-0000-0000-00000000000a'),
          'A deck', 'A''s deck is unchanged after B''s attempts');

select * from finish();
rollback;
