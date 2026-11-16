-- FR-61 study progress: RLS (NFR-07), CHECKs, and the merge triggers.
-- Run with: supabase test db   (pgTAP; everything rolls back at the end)

begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, email) values
    ('00000000-0000-0000-0000-0000000000a1', 'pa@test.codey'),
    ('00000000-0000-0000-0000-0000000000b1', 'pb@test.codey');

-- ── User A writes one row of each ────────────────────────────────────────
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-0000000000a1", "role": "authenticated"}';

select lives_ok($$
    insert into public.card_progress (card_id, mastery_score, last_reviewed_at, server_updated_at)
    values ('30000000-0000-0000-0000-000000000001', 3, '2026-11-01 10:00+00', '2000-01-01')
$$, 'A can insert card progress (owner_id defaults to auth.uid())');

select isnt((select server_updated_at from public.card_progress),
            '2000-01-01'::timestamptz, 'card_progress.server_updated_at is set by the server');

select lives_ok($$
    insert into public.question_progress (question_id, topic_id, difficulty, consecutive_correct,
        total_attempts, total_correct, last_answered_at)
    values ('q-swift-1', 'topic-swift', 'easy', 2, 3, 2, '2026-11-01 10:00+00')
$$, 'A can insert question progress');

select lives_ok($$
    insert into public.topic_progress (topic_id, medium_unlocked_at)
    values ('topic-swift', '2026-11-02 10:00+00')
$$, 'A can insert topic progress');

-- ── Merge: latest review wins ────────────────────────────────────────────
insert into public.card_progress (card_id, mastery_score, last_reviewed_at)
values ('30000000-0000-0000-0000-000000000001', 5, '2026-10-01 10:00+00')
on conflict (owner_id, card_id) do update set mastery_score = excluded.mastery_score,
    last_reviewed_at = excluded.last_reviewed_at;
select is((select mastery_score from public.card_progress), 3,
          'an older card review does not overwrite a newer one');

insert into public.card_progress (card_id, mastery_score, last_reviewed_at)
values ('30000000-0000-0000-0000-000000000001', 1, '2026-11-03 10:00+00')
on conflict (owner_id, card_id) do update set mastery_score = excluded.mastery_score,
    last_reviewed_at = excluded.last_reviewed_at;
select is((select mastery_score from public.card_progress), 1,
          'a newer card review wins, even when it lowers mastery');

insert into public.question_progress (question_id, topic_id, difficulty, consecutive_correct,
    total_attempts, total_correct, last_answered_at)
values ('q-swift-1', 'topic-swift', 'easy', 0, 1, 0, '2026-10-01 10:00+00')
on conflict (owner_id, question_id) do update set total_attempts = excluded.total_attempts,
    total_correct = excluded.total_correct, consecutive_correct = excluded.consecutive_correct,
    last_answered_at = excluded.last_answered_at;
select is((select total_attempts from public.question_progress), 3,
          'an older quiz answer does not overwrite a newer one');

-- ── Merge: sticky unlocks ────────────────────────────────────────────────
insert into public.topic_progress (topic_id, medium_unlocked_at, hard_unlocked_at)
values ('topic-swift', null, '2026-11-04 10:00+00')
on conflict (owner_id, topic_id) do update set medium_unlocked_at = excluded.medium_unlocked_at,
    hard_unlocked_at = excluded.hard_unlocked_at;
select is((select medium_unlocked_at from public.topic_progress), '2026-11-02 10:00+00'::timestamptz,
          'a null unlock does not relock a tier');
select is((select hard_unlocked_at from public.topic_progress), '2026-11-04 10:00+00'::timestamptz,
          'a new unlock is added');

insert into public.topic_progress (topic_id, medium_unlocked_at)
values ('topic-swift', '2026-11-05 10:00+00')
on conflict (owner_id, topic_id) do update set medium_unlocked_at = excluded.medium_unlocked_at;
select is((select medium_unlocked_at from public.topic_progress), '2026-11-02 10:00+00'::timestamptz,
          'the earliest unlock date is kept');

-- ── CHECKs match the app ─────────────────────────────────────────────────
select throws_ok($$
    insert into public.card_progress (card_id, mastery_score, last_reviewed_at)
    values ('30000000-0000-0000-0000-000000000002', 6, now())
$$, '23514', null, 'mastery above 5 is rejected');

select throws_ok($$
    insert into public.card_progress (card_id, mastery_score, last_reviewed_at)
    values ('30000000-0000-0000-0000-000000000003', -1, now())
$$, '23514', null, 'negative mastery is rejected');

select throws_ok($$
    insert into public.question_progress (question_id, topic_id, difficulty, consecutive_correct,
        total_attempts, total_correct, last_answered_at)
    values ('q-2', 'topic-swift', 'easy', 0, 1, 2, now())
$$, '23514', null, 'more correct than attempts is rejected');

select throws_ok($$
    insert into public.question_progress (question_id, topic_id, difficulty, consecutive_correct,
        total_attempts, total_correct, last_answered_at)
    values ('q-3', 'topic-swift', 'expert', 0, 0, 0, now())
$$, '23514', null, 'an unknown difficulty is rejected');

select throws_ok($$
    insert into public.question_progress (question_id, topic_id, difficulty, consecutive_correct,
        total_attempts, total_correct, last_answered_at)
    values (repeat('q', 101), 'topic-swift', 'easy', 0, 0, 0, now())
$$, '23514', null, 'a question id over 100 characters is rejected');

select throws_ok($$
    insert into public.question_progress (question_id, topic_id, difficulty, consecutive_correct,
        total_attempts, total_correct, last_answered_at)
    values ('q-4', 'topic-swift', 'easy', 0, 100001, 0, now())
$$, '23514', null, 'counters over 100000 are rejected');

-- ── User B sees and changes none of A's rows ─────────────────────────────
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-0000000000b1", "role": "authenticated"}';

select is((select count(*)::int from public.card_progress), 0, 'B sees 0 of A''s card progress');
select is((select count(*)::int from public.question_progress), 0, 'B sees 0 of A''s question progress');
select is((select count(*)::int from public.topic_progress), 0, 'B sees 0 of A''s topic progress');

select throws_ok($$
    insert into public.card_progress (owner_id, card_id, mastery_score, last_reviewed_at)
    values ('00000000-0000-0000-0000-0000000000a1', '30000000-0000-0000-0000-000000000009', 5, now())
$$, '42501', null, 'B cannot insert progress for A');

update public.card_progress set mastery_score = 5, last_reviewed_at = now();
delete from public.question_progress;
delete from public.topic_progress;

reset role;
select is((select mastery_score from public.card_progress
           where owner_id = '00000000-0000-0000-0000-0000000000a1'), 1, 'B''s update changed 0 rows');
select is((select count(*)::int from public.question_progress), 1, 'B''s delete removed 0 question rows');
select is((select count(*)::int from public.topic_progress), 1, 'B''s delete removed 0 topic rows');

-- ── anon sees nothing ────────────────────────────────────────────────────
set local role anon;
select is((select count(*)::int from public.card_progress), 0, 'anon sees no card progress');

select * from finish();
rollback;
