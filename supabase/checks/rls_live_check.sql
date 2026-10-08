-- Same checks as tests/rls.sql, written to run against the LIVE project
-- through the Supabase MCP (execute_sql) or the SQL editor, without pgTAP.
--
-- It ALWAYS ends with an error whose message holds the results, e.g.
--   "RLS TESTS: 0 failed of 30. ok 1 … | ok 30 …"
-- Raising it rolls back every test user and row, so nothing persists.
-- Last run: 2026-10-08, 0 failed of 30.

do $test$
declare
    a constant uuid := '00000000-0000-0000-0000-00000000000a';
    b constant uuid := '00000000-0000-0000-0000-00000000000b';
    deck_a constant uuid := '10000000-0000-0000-0000-00000000000a';
    claims_a constant text := '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
    claims_b constant text := '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
    results text[] := '{}';
    failed int := 0;
    n int;
    v text;
    ts timestamptz;
begin
    insert into auth.users (id, email, raw_user_meta_data) values
        (a, 'a@test.codey', '{"full_name": "Ana Example"}'),
        (b, 'b@test.codey', '{}');

    select count(*) into n from public.profiles where id in (a, b);
    if n = 2 then results := results || 'ok 1 trigger creates profiles'::text; else failed := failed + 1; results := results || ('FAIL 1 profiles=' || n); end if;
    select display_name into v from public.profiles where id = a;
    if v = 'Ana Example' then results := results || 'ok 2 google name'::text; else failed := failed + 1; results := results || ('FAIL 2 name=' || coalesce(v, 'null')); end if;
    select display_name into v from public.profiles where id = b;
    if v = 'Codey Learner' then results := results || 'ok 3 default name'::text; else failed := failed + 1; results := results || ('FAIL 3 name=' || coalesce(v, 'null')); end if;
    select count(*) into n from pg_tables where schemaname = 'public' and not rowsecurity;
    if n = 0 then results := results || 'ok 4 RLS on 100% of tables'::text; else failed := failed + 1; results := results || ('FAIL 4 tables without RLS=' || n); end if;

    -- As user A
    perform set_config('request.jwt.claims', claims_a, true);
    execute 'set local role authenticated';

    begin
        insert into public.decks (id, title, topic_id, created_at, updated_at, server_updated_at)
        values (deck_a, 'A deck', 'topic-swift', now(), now(), '2000-01-01');
        results := results || 'ok 5 A inserts deck'::text;
    exception when others then failed := failed + 1; results := results || ('FAIL 5 ' || sqlstate || ' ' || sqlerrm); end;

    select server_updated_at into ts from public.decks where id = deck_a;
    if ts is not null and ts <> '2000-01-01'::timestamptz then results := results || 'ok 6 server sets server_updated_at'::text; else failed := failed + 1; results := results || ('FAIL 6 ts=' || coalesce(ts::text, 'null')); end if;

    begin
        insert into public.flashcards (id, deck_id, prompt, answer, code_language, code_source, difficulty, created_at, updated_at)
        values ('20000000-0000-0000-0000-00000000000a', deck_a, 'What prints?', '1', 'python', 'print(1)', 'easy', now(), now());
        results := results || 'ok 7 A inserts card'::text;
    exception when others then failed := failed + 1; results := results || ('FAIL 7 ' || sqlstate || ' ' || sqlerrm); end;

    begin
        insert into public.sync_log (entity, entity_id, op, client_ts) values ('deck', deck_a, 'upsert', now());
        results := results || 'ok 8 A appends sync_log'::text;
    exception when others then failed := failed + 1; results := results || ('FAIL 8 ' || sqlstate || ' ' || sqlerrm); end;

    select count(*) into n from public.decks;
    if n = 1 then results := results || 'ok 9 A sees own deck'::text; else failed := failed + 1; results := results || ('FAIL 9 decks=' || n); end if;
    select count(*) into n from public.profiles;
    if n = 1 then results := results || 'ok 10 A sees only own profile'::text; else failed := failed + 1; results := results || ('FAIL 10 profiles=' || n); end if;

    begin
        insert into public.decks (id, title, topic_id, created_at, updated_at) values (gen_random_uuid(), repeat('x', 61), 't', now(), now());
        failed := failed + 1; results := results || 'FAIL 11 61-char title accepted'::text;
    exception when check_violation then results := results || 'ok 11 title > 60 rejected'::text;
              when others then failed := failed + 1; results := results || ('FAIL 11 ' || sqlstate); end;
    begin
        insert into public.decks (id, title, topic_id, created_at, updated_at) values (gen_random_uuid(), '   ', 't', now(), now());
        failed := failed + 1; results := results || 'FAIL 12 blank title accepted'::text;
    exception when check_violation then results := results || 'ok 12 blank title rejected'::text;
              when others then failed := failed + 1; results := results || ('FAIL 12 ' || sqlstate); end;
    begin
        insert into public.flashcards (id, deck_id, prompt, answer, created_at, updated_at) values (gen_random_uuid(), deck_a, repeat('p', 500), repeat('a', 500), now(), now());
        results := results || 'ok 13 500-char prompt/answer allowed'::text;
    exception when others then failed := failed + 1; results := results || ('FAIL 13 ' || sqlstate || ' ' || sqlerrm); end;
    begin
        insert into public.flashcards (id, deck_id, prompt, answer, created_at, updated_at) values (gen_random_uuid(), deck_a, repeat('p', 501), 'a', now(), now());
        failed := failed + 1; results := results || 'FAIL 14 501-char prompt accepted'::text;
    exception when check_violation then results := results || 'ok 14 prompt > 500 rejected'::text;
              when others then failed := failed + 1; results := results || ('FAIL 14 ' || sqlstate); end;
    begin
        insert into public.flashcards (id, deck_id, prompt, answer, code_language, created_at, updated_at) values (gen_random_uuid(), deck_a, 'p', 'a', 'swift', now(), now());
        failed := failed + 1; results := results || 'FAIL 15 language without source accepted'::text;
    exception when check_violation then results := results || 'ok 15 language without source rejected'::text;
              when others then failed := failed + 1; results := results || ('FAIL 15 ' || sqlstate); end;
    begin
        insert into public.flashcards (id, deck_id, prompt, answer, code_language, code_source, created_at, updated_at) values (gen_random_uuid(), deck_a, 'p', 'a', 'kotlin', 'x', now(), now());
        failed := failed + 1; results := results || 'FAIL 16 kotlin accepted'::text;
    exception when check_violation then results := results || 'ok 16 unsupported language rejected'::text;
              when others then failed := failed + 1; results := results || ('FAIL 16 ' || sqlstate); end;
    begin
        insert into public.flashcards (id, deck_id, prompt, answer, code_language, code_source, created_at, updated_at)
        values (gen_random_uuid(), deck_a, 'p', 'a', 'cpp', array_to_string(array_fill('x'::text, array[80]), E'\n'), now(), now());
        results := results || 'ok 17 80-line snippet allowed'::text;
    exception when others then failed := failed + 1; results := results || ('FAIL 17 ' || sqlstate || ' ' || sqlerrm); end;
    begin
        insert into public.flashcards (id, deck_id, prompt, answer, code_language, code_source, created_at, updated_at)
        values (gen_random_uuid(), deck_a, 'p', 'a', 'cpp', array_to_string(array_fill('x'::text, array[81]), E'\n'), now(), now());
        failed := failed + 1; results := results || 'FAIL 18 81-line snippet accepted'::text;
    exception when check_violation then results := results || 'ok 18 81-line snippet rejected'::text;
              when others then failed := failed + 1; results := results || ('FAIL 18 ' || sqlstate); end;

    -- As user B
    perform set_config('request.jwt.claims', claims_b, true);

    select count(*) into n from public.decks;
    if n = 0 then results := results || 'ok 19 B sees 0 of A''s decks'::text; else failed := failed + 1; results := results || ('FAIL 19 decks=' || n); end if;
    select count(*) into n from public.flashcards;
    if n = 0 then results := results || 'ok 20 B sees 0 of A''s cards'::text; else failed := failed + 1; results := results || ('FAIL 20 cards=' || n); end if;
    select count(*) into n from public.sync_log;
    if n = 0 then results := results || 'ok 21 B sees 0 of A''s sync_log'::text; else failed := failed + 1; results := results || ('FAIL 21 log=' || n); end if;
    select count(*) into n from public.profiles;
    if n = 1 then results := results || 'ok 22 B sees only own profile'::text; else failed := failed + 1; results := results || ('FAIL 22 profiles=' || n); end if;

    begin
        insert into public.flashcards (id, deck_id, owner_id, prompt, answer, created_at, updated_at) values (gen_random_uuid(), deck_a, b, 'p', 'a', now(), now());
        failed := failed + 1; results := results || 'FAIL 23 B inserted a card into A''s deck'::text;
    exception when insufficient_privilege then results := results || 'ok 23 B can''t add a card to A''s deck'::text;
              when others then failed := failed + 1; results := results || ('FAIL 23 ' || sqlstate || ' ' || sqlerrm); end;
    begin
        insert into public.decks (id, owner_id, title, topic_id, created_at, updated_at) values (gen_random_uuid(), a, 'spoof', 't', now(), now());
        failed := failed + 1; results := results || 'FAIL 24 B created a deck owned by A'::text;
    exception when insufficient_privilege then results := results || 'ok 24 B can''t create a deck as A'::text;
              when others then failed := failed + 1; results := results || ('FAIL 24 ' || sqlstate || ' ' || sqlerrm); end;

    update public.decks set title = 'hacked' where id = deck_a;
    get diagnostics n = row_count;
    if n = 0 then results := results || 'ok 25 B''s update of A''s deck: 0 rows'::text; else failed := failed + 1; results := results || ('FAIL 25 updated=' || n); end if;
    delete from public.decks where id = deck_a;
    get diagnostics n = row_count;
    if n = 0 then results := results || 'ok 26 B''s delete of A''s deck: 0 rows'::text; else failed := failed + 1; results := results || ('FAIL 26 deleted=' || n); end if;
    update public.profiles set total_xp = 999999 where id = a;
    get diagnostics n = row_count;
    if n = 0 then results := results || 'ok 27 B can''t change A''s XP'::text; else failed := failed + 1; results := results || ('FAIL 27 updated=' || n); end if;

    insert into public.sync_log (entity, entity_id, op, client_ts) values ('profile', b, 'upsert', now());
    update public.sync_log set op = 'delete';
    get diagnostics n = row_count;
    if n = 0 then results := results || 'ok 28 sync_log is append-only'::text; else failed := failed + 1; results := results || ('FAIL 28 updated=' || n); end if;

    -- anon
    execute 'set local role anon';
    perform set_config('request.jwt.claims', '{"role": "anon"}', true);
    select count(*) into n from public.decks;
    if n = 0 then results := results || 'ok 29 anon sees no decks'::text; else failed := failed + 1; results := results || ('FAIL 29 decks=' || n); end if;

    -- Back as A
    execute 'set local role authenticated';
    perform set_config('request.jwt.claims', claims_a, true);
    select title into v from public.decks where id = deck_a;
    if v = 'A deck' then results := results || 'ok 30 A''s deck intact'::text; else failed := failed + 1; results := results || ('FAIL 30 title=' || coalesce(v, 'missing')); end if;

    raise exception 'RLS TESTS: % failed of %. %', failed, coalesce(array_length(results, 1), 0), array_to_string(results, ' | ');
end
$test$;
