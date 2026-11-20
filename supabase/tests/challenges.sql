-- Coding challenges (migration 20261117224554_challenges.sql): challenges
-- and starters are public, only example tests are readable, nobody but the
-- service role touches challenge_runs, and the CHECKs hold (NFR-07).
-- Run with: supabase test db   (pgTAP; everything rolls back at the end)

begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into public.content_topics (id, title, summary, icon_name)
    values ('topic-ch-test', 'Test', 'A test topic.', 'star');
insert into public.content_challenges (id, topic_id, title, difficulty, statement, hints, function_name, params, return_type)
    values ('ch-test', 'topic-ch-test', 'Add', 'easy', 'Add a and b.', '["Use +", "Return it"]',
            'add', '[{"name": "a", "type": "int"}, {"name": "b", "type": "int"}]', 'int');
insert into public.content_challenge_starters (challenge_id, language, code)
    values ('ch-test', 'python', 'def add(a, b):\n    pass');
insert into public.content_challenge_tests (id, challenge_id, ordinal, args, expected, is_example) values
    ('ch-test-1', 'ch-test', 1, '[1, 2]', '3', true),
    ('ch-test-2', 'ch-test', 2, '[5, 5]', '10', false);

-- ── Guests (anon) ────────────────────────────────────────────────────────
set local role anon;

select is((select count(*)::int from public.content_challenges where id = 'ch-test'), 1, 'anon can read a challenge');
select is((select count(*)::int from public.content_challenge_starters where challenge_id = 'ch-test'), 1, 'anon can read starters');
select is((select count(*)::int from public.content_challenge_tests where challenge_id = 'ch-test'), 1, 'anon reads only the example test');
select is((select count(*)::int from public.content_challenge_tests where id = 'ch-test-2'), 0, 'anon cannot read a hidden test');
select throws_ok($$ select count(*) from public.challenge_runs $$, '42501', null, 'anon cannot read challenge_runs');
select throws_ok($$
    insert into public.content_challenge_tests (id, challenge_id, ordinal, args, expected) values ('evil', 'ch-test', 9, '[]', '0')
$$, '42501', null, 'anon cannot insert a test');

-- ── Signed-in users ──────────────────────────────────────────────────────
reset role;
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000c1', 'ch@test.codey');
set local role authenticated;
set local request.jwt.claims to '{"sub": "00000000-0000-0000-0000-0000000000c1", "role": "authenticated"}';

select is((select count(*)::int from public.content_challenge_tests where challenge_id = 'ch-test'), 1, 'a signed-in user reads only the example test');
select throws_ok($$ insert into public.challenge_runs (subject, mode) values ('x', 'run') $$, '42501', null, 'a signed-in user cannot write challenge_runs');
update public.content_challenge_tests set is_example = true where id = 'ch-test-2';
update public.content_challenges set title = 'Hacked' where id = 'ch-test';

-- ── As the owner: nothing changed, and the CHECKs hold ───────────────────
reset role;
select is((select is_example from public.content_challenge_tests where id = 'ch-test-2'), false, 'a user update did not reveal a hidden test');
select is((select title from public.content_challenges where id = 'ch-test'), 'Add', 'a user update changed no challenge');
select throws_ok($$
    insert into public.content_challenges (id, topic_id, title, difficulty, statement, function_name, params, return_type)
    values ('bad-id', 'topic-ch-test', 'x', 'easy', 'x', 'f', '[{"name":"a","type":"int"}]', 'int')
$$, '23514', null, 'a challenge id must start with ch-');
select throws_ok($$
    insert into public.content_challenge_starters (challenge_id, language, code) values ('ch-test', 'ruby', 'x')
$$, '23514', null, 'starter language is one of the four');
select throws_ok($$
    insert into public.content_exercises (id, topic_id, title, language, prompt, code, blanks, explanation, hints)
    values ('ex-hint-test', 'topic-ch-test', 'x', 'swift', 'x', '___', '[{"accepted": ["1"]}]', 'x', '["a", "b", "c", "d"]')
$$, '23514', null, 'a drill has at most 3 hints');

select * from finish();
rollback;
