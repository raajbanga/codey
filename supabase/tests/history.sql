-- FR-61 (S43) progress history: RLS (NFR-07), CHECKs, and the merge rules
-- for quiz_answers, daily_activity, badge_awards and solved exercises.
-- Run with: supabase test db   (pgTAP; everything rolls back at the end)

begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

insert into auth.users (id, email) values
    ('00000000-0000-0000-0000-0000000000c1', 'hc@test.codey'),
    ('00000000-0000-0000-0000-0000000000d1', 'hd@test.codey');

set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-0000000000c1", "role": "authenticated"}';

-- ── quiz_answers: append-only, duplicates ignored ────────────────────────
select lives_ok($$
    insert into public.quiz_answers (question_id, topic_id, correct, answered_at)
    values ('q-swift-1', 'topic-swift', true, '2026-11-15 10:00+00')
$$, 'C can insert a quiz answer (owner_id defaults to auth.uid())');

select lives_ok($$
    insert into public.quiz_answers (question_id, topic_id, correct, answered_at)
    values ('q-swift-1', 'topic-swift', false, '2026-11-15 10:00+00')
    on conflict (owner_id, question_id, answered_at) do nothing
$$, 'a resent answer is skipped, not an error');

select is((select count(*)::int from public.quiz_answers), 1, 'the same answer is stored once');
select is((select correct from public.quiz_answers), true, 'the first copy is kept');

update public.quiz_answers set correct = false;
select is((select correct from public.quiz_answers), true, 'answers cannot be edited (no update policy)');

-- ── daily_activity: larger counter wins, per device ──────────────────────
select lives_ok($$
    insert into public.daily_activity (device_id, day, cards_rated, quiz_answers)
    values ('phone', '2026-11-15', 4, 9)
$$, 'C can insert a day');

insert into public.daily_activity (device_id, day, cards_rated, quiz_answers)
values ('phone', '2026-11-15', 2, 12)
on conflict (owner_id, device_id, day) do update
    set cards_rated = excluded.cards_rated, quiz_answers = excluded.quiz_answers;
select is((select cards_rated from public.daily_activity where device_id = 'phone'), 4,
          'a smaller cards_rated does not lower the counter');
select is((select quiz_answers from public.daily_activity where device_id = 'phone'), 12,
          'a larger quiz_answers raises it');

select lives_ok($$
    insert into public.daily_activity (device_id, day, quiz_answers) values ('sim', '2026-11-15', 8)
$$, 'a second device gets its own row for the same day');

select throws_ok($$
    insert into public.daily_activity (device_id, day) values ('phone', '15/11/2026')
$$, '23514', null, 'day must be yyyy-MM-dd');

-- ── badge_awards: earliest date wins, known badges only ──────────────────
select lives_ok($$
    insert into public.badge_awards (badge, earned_at) values ('firstDeck', '2026-11-10 10:00+00')
$$, 'C can insert a badge');

insert into public.badge_awards (badge, earned_at) values ('firstDeck', '2026-11-12 10:00+00')
on conflict (owner_id, badge) do update set earned_at = excluded.earned_at;
select is((select earned_at from public.badge_awards), '2026-11-10 10:00+00'::timestamptz,
          'a later date does not replace an earlier one');

insert into public.badge_awards (badge, earned_at) values ('firstDeck', '2026-11-01 10:00+00')
on conflict (owner_id, badge) do update set earned_at = excluded.earned_at;
select is((select earned_at from public.badge_awards), '2026-11-01 10:00+00'::timestamptz,
          'an earlier date replaces it');

select throws_ok($$
    insert into public.badge_awards (badge, earned_at) values ('madeUp', now())
$$, '23514', null, 'unknown badges are rejected');

-- ── solved exercises on the profile ──────────────────────────────────────
select lives_ok($$
    update public.profiles set solved_exercise_ids = '{ex-swift-guard,ex-swift-if-let}'
    where id = '00000000-0000-0000-0000-0000000000c1'
$$, 'C can store solved exercises');

-- ── RLS: D sees none of C's rows and cannot write as C ───────────────────
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-0000000000d1", "role": "authenticated"}';

select is((select count(*)::int from public.quiz_answers) + (select count(*)::int from public.daily_activity)
          + (select count(*)::int from public.badge_awards), 0, 'D sees none of C''s history');

select throws_ok($$
    insert into public.quiz_answers (owner_id, question_id, topic_id, correct, answered_at)
    values ('00000000-0000-0000-0000-0000000000c1', 'q-x', 'topic-swift', true, now())
$$, '42501', null, 'D cannot insert an answer as C');

select throws_ok($$
    insert into public.daily_activity (owner_id, device_id, day)
    values ('00000000-0000-0000-0000-0000000000c1', 'x', '2026-11-15')
$$, '42501', null, 'D cannot insert a day as C');

select * from finish();
rollback;
