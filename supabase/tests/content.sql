-- App content (content_* tables, migration 20261116000000_content.sql):
-- anyone can read it, no client can change it (NFR-07, TC-S01).
-- Run with: supabase test db   (pgTAP; everything rolls back at the end)

begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

-- One row of each kind, inserted as the table owner (as seed.sql does).
insert into public.content_topics (id, title, summary, icon_name)
    values ('topic-test', 'Test', 'A test topic.', 'star');
insert into public.content_questions (id, topic_id, prompt, options, correct_option_index, explanation, difficulty)
    values ('q-test-1', 'topic-test', 'Pick A', array['A', 'B'], 0, 'A is right.', 'easy');
insert into public.content_exercises (id, topic_id, title, language, prompt, code, blanks, explanation)
    values ('ex-test-1', 'topic-test', 'Fill it', 'swift', 'Fill the blank.', 'let x = ___', '[{"accepted": ["1"]}]', 'Any number.');
insert into public.content_decks (starter_key, topic_id, title)
    values ('starter-test', 'topic-test', 'Test deck');
insert into public.content_cards (id, deck_key, prompt, answer, difficulty)
    values ('card-test-1', 'starter-test', 'Front', 'Back', 'easy');

-- ── Guests (anon): read everything ───────────────────────────────────────
set local role anon;

select is((select count(*)::int from public.content_topics where id = 'topic-test'), 1, 'anon can read topics');
select is((select count(*)::int from public.content_questions where id = 'q-test-1'), 1, 'anon can read questions');
select is((select count(*)::int from public.content_exercises where id = 'ex-test-1'), 1, 'anon can read exercises');
select is((select count(*)::int from public.content_decks where starter_key = 'starter-test'), 1, 'anon can read starter decks');
select is((select count(*)::int from public.content_cards where id = 'card-test-1'), 1, 'anon can read starter cards');

-- ── Guests cannot write ──────────────────────────────────────────────────
select throws_ok($$
    insert into public.content_questions (id, topic_id, prompt, options, correct_option_index, explanation, difficulty)
    values ('q-evil', 'topic-test', 'x', array['a', 'b'], 0, 'x', 'easy')
$$, '42501', null, 'anon cannot insert a question');

update public.content_questions set correct_option_index = 1 where id = 'q-test-1';
delete from public.content_cards where id = 'card-test-1';

-- ── Signed-in users: read, but no writes either ──────────────────────────
reset role;
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000e1', 'ce@test.codey');
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-0000000000e1", "role": "authenticated"}';

select is((select count(*)::int from public.content_questions where id = 'q-test-1'), 1, 'a signed-in user can read questions');

select throws_ok($$
    insert into public.content_exercises (id, topic_id, title, language, prompt, code, blanks, explanation)
    values ('ex-evil', 'topic-test', 'x', 'swift', 'x', '___', '[]', 'x')
$$, '42501', null, 'a signed-in user cannot insert an exercise');

select throws_ok($$
    insert into public.content_topics (id, title, summary, icon_name) values ('topic-evil', 'x', 'x', 'x')
$$, '42501', null, 'a signed-in user cannot insert a topic');

update public.content_topics set title = 'Hacked' where id = 'topic-test';
update public.content_decks set title = 'Hacked' where starter_key = 'starter-test';
delete from public.content_exercises where id = 'ex-test-1';

-- ── Nothing changed (checked as the owner) ───────────────────────────────
reset role;

select is((select correct_option_index from public.content_questions where id = 'q-test-1'), 0, 'anon update changed no question (no update policy)');
select is((select count(*)::int from public.content_cards where id = 'card-test-1'), 1, 'anon delete removed no card (no delete policy)');
select is((select title from public.content_topics where id = 'topic-test'), 'Test', 'a user update changed no topic');
select is((select title from public.content_decks where starter_key = 'starter-test'), 'Test deck', 'a user update changed no deck');
select is((select count(*)::int from public.content_exercises where id = 'ex-test-1'), 1, 'a user delete removed no exercise');

select * from finish();
rollback;
