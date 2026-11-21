-- Same checks as tests/rls.sql, written to run against the LIVE project
-- through the Supabase MCP (execute_sql) or the SQL editor, without pgTAP.
--
-- It ALWAYS ends with an error whose message holds the results, e.g.
--   "RLS TESTS: 0 failed of 73. ok 1 … | ok 73 …"
-- Raising it rolls back every test user and row, so nothing persists.
-- Checks 58-63 cover the S43 history tables, 64-67 the read-only content
-- tables (both added 2026-11-15), 68-73 the coding challenges (S45). Last runs: see supabase/README.md.

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
    grp constant uuid := '30000000-0000-0000-0000-00000000000a';
    code text;
    monday constant date := date_trunc('week', now() at time zone 'utc')::date;
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

    -- S3-C: avatar set (FR-04) and feedback reports (FR-49), as A
    update public.profiles set avatar_id = 'star.fill' where id = a;
    get diagnostics n = row_count;
    if n = 1 then results := results || 'ok 31 listed avatar allowed'::text; else failed := failed + 1; results := results || ('FAIL 31 updated=' || n); end if;
    begin
        update public.profiles set avatar_id = 'skull.fill' where id = a;
        failed := failed + 1; results := results || 'FAIL 32 unlisted avatar accepted'::text;
    exception when check_violation then results := results || 'ok 32 unlisted avatar rejected'::text;
              when others then failed := failed + 1; results := results || ('FAIL 32 ' || sqlstate); end;
    begin
        insert into public.feedback_reports (description, app_version, os_version) values ('Button overlaps text', '1.0', '26.0');
        results := results || 'ok 33 A sends a report'::text;
    exception when others then failed := failed + 1; results := results || ('FAIL 33 ' || sqlstate || ' ' || sqlerrm); end;
    begin
        insert into public.feedback_reports (description) values (repeat('x', 1001));
        failed := failed + 1; results := results || 'FAIL 34 1001-char report accepted'::text;
    exception when check_violation then results := results || 'ok 34 report > 1000 rejected'::text;
              when others then failed := failed + 1; results := results || ('FAIL 34 ' || sqlstate); end;
    select count(*) into n from public.feedback_reports;
    if n = 0 then results := results || 'ok 35 reports aren''t readable, even own'::text; else failed := failed + 1; results := results || ('FAIL 35 visible=' || n); end if;

    -- As user B
    perform set_config('request.jwt.claims', claims_b, true);

    begin
        insert into public.feedback_reports (owner_id, description) values (a, 'spoof');
        failed := failed + 1; results := results || 'FAIL 36 B sent a report as A'::text;
    exception when insufficient_privilege then results := results || 'ok 36 B can''t send a report as A'::text;
              when others then failed := failed + 1; results := results || ('FAIL 36 ' || sqlstate || ' ' || sqlerrm); end;

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

    -- ── S3-D: groups, weekly XP, leaderboard (A is still the role here) ──
    begin
        insert into public.groups (id, name, invite_code, created_by) values (grp, '  Study Group  ', 'AAAAAA', b);
        select invite_code into code from public.groups where id = grp;
        select count(*) into n from public.group_members where group_id = grp and user_id = a;
        if code ~ '^[A-Z0-9]{6}$' and code <> 'AAAAAA' and n = 1 then results := results || 'ok 37 create group: server code, creator is a member'::text;
        else failed := failed + 1; results := results || ('FAIL 37 code=' || coalesce(code, 'null') || ' members=' || n); end if;
    exception when others then failed := failed + 1; results := results || ('FAIL 37 ' || sqlstate || ' ' || sqlerrm); end;
    select count(*) into n from public.groups where id = grp and created_by = a and name = 'Study Group';
    if n = 1 then results := results || 'ok 38 created_by forced to A, name trimmed'::text; else failed := failed + 1; results := results || ('FAIL 38 rows=' || n); end if;
    begin
        insert into public.group_members (group_id, user_id) values (grp, b);
        failed := failed + 1; results := results || 'FAIL 39 A added B to a group directly'::text;
    exception when insufficient_privilege then results := results || 'ok 39 memberships only via join_group'::text;
              when others then failed := failed + 1; results := results || ('FAIL 39 ' || sqlstate || ' ' || sqlerrm); end;
    begin
        insert into public.weekly_xp (week_start, xp) values (monday, 100);
        insert into public.weekly_xp (week_start, xp) values (monday, 50)
            on conflict (owner_id, week_start) do update set xp = excluded.xp;
        select xp into n from public.weekly_xp where owner_id = a and week_start = monday;
        if n = 100 then results := results || 'ok 40 weekly_xp keeps the max'::text; else failed := failed + 1; results := results || ('FAIL 40 xp=' || n); end if;
    exception when others then failed := failed + 1; results := results || ('FAIL 40 ' || sqlstate || ' ' || sqlerrm); end;
    begin
        insert into public.weekly_xp (week_start, xp) values (monday + 1, 10);
        failed := failed + 1; results := results || 'FAIL 41 non-Monday week accepted'::text;
    exception when check_violation then results := results || 'ok 41 week_start must be a Monday'::text;
              when others then failed := failed + 1; results := results || ('FAIL 41 ' || sqlstate || ' ' || sqlerrm); end;

    -- B, not a member yet
    perform set_config('request.jwt.claims', claims_b, true);
    select (select count(*) from public.groups) + (select count(*) from public.group_members)
         + (select count(*) from public.weekly_xp where owner_id = a) + (select count(*) from public.group_leaderboard) into n;
    if n = 0 then results := results || 'ok 42 non-member sees 0 groups, members, XP, board rows'::text; else failed := failed + 1; results := results || ('FAIL 42 rows=' || n); end if;
    begin
        perform public.join_group('ZZZZZZ');
        failed := failed + 1; results := results || 'FAIL 43 unknown code joined'::text;
    exception when no_data_found then results := results || 'ok 43 unknown code rejected'::text;
              when others then failed := failed + 1; results := results || ('FAIL 43 ' || sqlstate || ' ' || sqlerrm); end;
    begin
        perform public.join_group(lower(code));
        select count(*) into n from public.group_leaderboard where group_id = grp;
        if n = 2 then results := results || 'ok 44 join by code (any case); board shows both'::text; else failed := failed + 1; results := results || ('FAIL 44 board=' || n); end if;
    exception when others then failed := failed + 1; results := results || ('FAIL 44 ' || sqlstate || ' ' || sqlerrm); end;
    select xp into n from public.group_leaderboard where group_id = grp and user_id = a;
    if n = 100 then results := results || 'ok 45 member sees A''s weekly XP'::text; else failed := failed + 1; results := results || ('FAIL 45 xp=' || coalesce(n::text, 'null')); end if;
    delete from public.group_members where group_id = grp and user_id = a;
    get diagnostics n = row_count;
    if n = 0 then results := results || 'ok 46 B can''t remove A'::text; else failed := failed + 1; results := results || ('FAIL 46 deleted=' || n); end if;
    delete from public.group_members where group_id = grp and user_id = b;
    select count(*) into n from public.groups;
    select n + count(*) - 1 into n from public.profiles;
    if n = 0 then results := results || 'ok 47 after leaving, B sees 0 groups and only own profile'::text; else failed := failed + 1; results := results || ('FAIL 47 rows=' || n); end if;

    -- FR-61 study progress (2026-11-10): owner-only, latest review wins, sticky unlocks
    perform set_config('request.jwt.claims', claims_a, true);
    begin
        insert into public.card_progress (card_id, mastery_score, last_reviewed_at) values (deck_a, 3, '2026-11-01');
        insert into public.question_progress (question_id, topic_id, difficulty, consecutive_correct, total_attempts, total_correct, last_answered_at)
        values ('q-live', 'topic-swift', 'easy', 1, 2, 1, '2026-11-01');
        insert into public.topic_progress (topic_id, medium_unlocked_at) values ('topic-swift', '2026-11-02');
        results := results || 'ok 49 A inserts progress rows'::text;
    exception when others then failed := failed + 1; results := results || ('FAIL 49 ' || sqlstate || ' ' || sqlerrm); end;
    insert into public.card_progress (card_id, mastery_score, last_reviewed_at) values (deck_a, 5, '2026-10-01')
        on conflict (owner_id, card_id) do update set mastery_score = excluded.mastery_score, last_reviewed_at = excluded.last_reviewed_at;
    select mastery_score into n from public.card_progress where owner_id = a;
    if n = 3 then results := results || 'ok 50 older review skipped'::text; else failed := failed + 1; results := results || ('FAIL 50 mastery=' || coalesce(n::text, 'null')); end if;
    insert into public.card_progress (card_id, mastery_score, last_reviewed_at) values (deck_a, 0, '2026-11-03')
        on conflict (owner_id, card_id) do update set mastery_score = excluded.mastery_score, last_reviewed_at = excluded.last_reviewed_at;
    select mastery_score into n from public.card_progress where owner_id = a;
    if n = 0 then results := results || 'ok 51 newer review wins (even lower)'::text; else failed := failed + 1; results := results || ('FAIL 51 mastery=' || coalesce(n::text, 'null')); end if;
    insert into public.topic_progress (topic_id, medium_unlocked_at) values ('topic-swift', null)
        on conflict (owner_id, topic_id) do update set medium_unlocked_at = excluded.medium_unlocked_at;
    select medium_unlocked_at into ts from public.topic_progress where owner_id = a;
    if ts = '2026-11-02'::timestamptz then results := results || 'ok 52 unlocks are sticky'::text; else failed := failed + 1; results := results || ('FAIL 52 ts=' || coalesce(ts::text, 'null')); end if;
    begin
        insert into public.card_progress (card_id, mastery_score, last_reviewed_at) values (b, 6, now());
        failed := failed + 1; results := results || 'FAIL 53 mastery 6 accepted'::text;
    exception when check_violation then results := results || 'ok 53 mastery over 5 rejected'::text;
              when others then failed := failed + 1; results := results || ('FAIL 53 ' || sqlstate || ' ' || sqlerrm); end;

    perform set_config('request.jwt.claims', claims_b, true);
    select (select count(*) from public.card_progress) + (select count(*) from public.question_progress)
         + (select count(*) from public.topic_progress) into n;
    if n = 0 then results := results || 'ok 54 B sees 0 of A''s progress'::text; else failed := failed + 1; results := results || ('FAIL 54 rows=' || n); end if;
    update public.card_progress set mastery_score = 5, last_reviewed_at = now() where owner_id = a;
    get diagnostics n = row_count;
    if n = 0 then results := results || 'ok 55 B updates 0 of A''s progress'::text; else failed := failed + 1; results := results || ('FAIL 55 updated=' || n); end if;
    begin
        insert into public.card_progress (owner_id, card_id, mastery_score, last_reviewed_at) values (a, b, 1, now());
        failed := failed + 1; results := results || 'FAIL 56 B inserted for A'::text;
    exception when insufficient_privilege then results := results || 'ok 56 B can''t insert A''s progress'::text;
              when others then failed := failed + 1; results := results || ('FAIL 56 ' || sqlstate || ' ' || sqlerrm); end;

    -- S43 history: quiz_answers, daily_activity, badge_awards
    perform set_config('request.jwt.claims', claims_a, true);
    insert into public.quiz_answers (question_id, topic_id, correct, answered_at) values ('q-swift-1', 'topic-swift', true, '2026-11-15');
    insert into public.daily_activity (device_id, day, quiz_answers) values ('phone', '2026-11-15', 9);
    insert into public.badge_awards (badge, earned_at) values ('firstDeck', '2026-11-15');
    insert into public.daily_activity (device_id, day, quiz_answers) values ('phone', '2026-11-15', 4)
        on conflict (owner_id, device_id, day) do update set quiz_answers = excluded.quiz_answers;
    select quiz_answers into n from public.daily_activity where owner_id = a;
    if n = 9 then results := results || 'ok 58 day counters keep the larger'::text; else failed := failed + 1; results := results || ('FAIL 58 quiz_answers=' || n); end if;

    perform set_config('request.jwt.claims', claims_b, true);
    select (select count(*) from public.quiz_answers) + (select count(*) from public.daily_activity)
         + (select count(*) from public.badge_awards) into n;
    if n = 0 then results := results || 'ok 59 B sees 0 of A''s history'::text; else failed := failed + 1; results := results || ('FAIL 59 rows=' || n); end if;
    update public.daily_activity set quiz_answers = 99 where owner_id = a;
    get diagnostics n = row_count;
    if n = 0 then results := results || 'ok 60 B updates 0 of A''s days'::text; else failed := failed + 1; results := results || ('FAIL 60 updated=' || n); end if;
    begin
        insert into public.quiz_answers (owner_id, question_id, topic_id, correct, answered_at) values (a, 'q-x', 'topic-swift', true, now());
        failed := failed + 1; results := results || 'FAIL 61 B inserted an answer for A'::text;
    exception when insufficient_privilege then results := results || 'ok 61 B can''t insert A''s answers'::text;
              when others then failed := failed + 1; results := results || ('FAIL 61 ' || sqlstate || ' ' || sqlerrm); end;
    begin
        insert into public.badge_awards (badge, earned_at) values ('madeUp', now());
        failed := failed + 1; results := results || 'FAIL 62 unknown badge accepted'::text;
    exception when check_violation then results := results || 'ok 62 unknown badge rejected'::text;
              when others then failed := failed + 1; results := results || ('FAIL 62 ' || sqlstate || ' ' || sqlerrm); end;

    -- anon can't call the RPC
    execute 'set local role anon';
    perform set_config('request.jwt.claims', '{"role": "anon"}', true);
    begin
        perform public.join_group(code);
        failed := failed + 1; results := results || 'FAIL 48 anon called join_group'::text;
    exception when insufficient_privilege then results := results || 'ok 48 anon can''t call join_group'::text;
              when others then failed := failed + 1; results := results || ('FAIL 48 ' || sqlstate || ' ' || sqlerrm); end;
    begin
        select (select count(*) from public.card_progress) + (select count(*) from public.question_progress)
             + (select count(*) from public.topic_progress) into n;
        if n = 0 then results := results || 'ok 57 anon sees no progress'::text; else failed := failed + 1; results := results || ('FAIL 57 rows=' || n); end if;
    exception when insufficient_privilege then results := results || 'ok 57 anon sees no progress (no grant)'::text; end;
    begin
        select (select count(*) from public.quiz_answers) + (select count(*) from public.daily_activity)
             + (select count(*) from public.badge_awards) into n;
        if n = 0 then results := results || 'ok 63 anon sees no history'::text; else failed := failed + 1; results := results || ('FAIL 63 rows=' || n); end if;
    exception when insufficient_privilege then results := results || 'ok 63 anon sees no history (no grant)'::text; end;

    -- Content tables (2026-11-15): anon may read them and change nothing.
    begin
        select count(*) into n from public.content_questions;
        results := results || ('ok 64 anon reads content (' || n || ' questions)');
    exception when others then failed := failed + 1; results := results || ('FAIL 64 ' || sqlstate || ' ' || sqlerrm); end;
    begin
        insert into public.content_topics (id, title, summary, icon_name) values ('topic-evil', 'x', 'x', 'x');
        failed := failed + 1; results := results || 'FAIL 65 anon inserted content'::text;
    exception when insufficient_privilege then results := results || 'ok 65 anon can''t insert content'::text;
              when others then failed := failed + 1; results := results || ('FAIL 65 ' || sqlstate || ' ' || sqlerrm); end;
    begin
        update public.content_questions set correct_option_index = 0;
        get diagnostics n = row_count;
        if n = 0 then results := results || 'ok 66 anon updates 0 content rows'::text; else failed := failed + 1; results := results || ('FAIL 66 updated=' || n); end if;
    exception when insufficient_privilege then results := results || 'ok 66 anon can''t update content (no grant)'::text; end;
    begin
        delete from public.content_cards;
        get diagnostics n = row_count;
        if n = 0 then results := results || 'ok 67 anon deletes 0 content rows'::text; else failed := failed + 1; results := results || ('FAIL 67 deleted=' || n); end if;
    exception when insufficient_privilege then results := results || 'ok 67 anon can''t delete content (no grant)'::text; end;

    -- Coding challenges (S45, 2026-11-18): challenges and starters are
    -- public, hidden tests and the run log are not, and nobody writes.
    begin
        select count(*) into n from public.content_challenges;
        if n > 0 then results := results || ('ok 68 anon reads challenges (' || n || ')'); else failed := failed + 1; results := results || 'FAIL 68 no challenges visible'::text; end if;
    exception when others then failed := failed + 1; results := results || ('FAIL 68 ' || sqlstate || ' ' || sqlerrm); end;
    begin
        select count(*) into n from public.content_challenge_tests where not is_example;
        if n = 0 then results := results || 'ok 69 anon reads 0 hidden tests'::text; else failed := failed + 1; results := results || ('FAIL 69 hidden=' || n); end if;
    exception when others then failed := failed + 1; results := results || ('FAIL 69 ' || sqlstate || ' ' || sqlerrm); end;
    begin
        select count(*) into n from public.challenge_runs;
        if n = 0 then results := results || 'ok 70 anon sees no run log'::text; else failed := failed + 1; results := results || ('FAIL 70 rows=' || n); end if;
    exception when insufficient_privilege then results := results || 'ok 70 anon can''t read the run log (no grant)'::text; end;
    begin
        update public.content_challenge_tests set is_example = true where not is_example;
        get diagnostics n = row_count;
        if n = 0 then results := results || 'ok 71 anon reveals 0 hidden tests'::text; else failed := failed + 1; results := results || ('FAIL 71 updated=' || n); end if;
    exception when insufficient_privilege then results := results || 'ok 71 anon can''t update tests (no grant)'::text; end;

    -- As user A: still only the examples.
    perform set_config('request.jwt.claims', claims_a, true);
    execute 'set local role authenticated';
    begin
        select count(*) into n from public.content_challenge_tests where not is_example;
        if n = 0 then results := results || 'ok 72 A reads 0 hidden tests'::text; else failed := failed + 1; results := results || ('FAIL 72 hidden=' || n); end if;
    exception when others then failed := failed + 1; results := results || ('FAIL 72 ' || sqlstate || ' ' || sqlerrm); end;
    begin
        insert into public.challenge_runs (subject, mode) values ('u:evil', 'run');
        failed := failed + 1; results := results || 'FAIL 73 A wrote the run log'::text;
    exception when insufficient_privilege then results := results || 'ok 73 A can''t write the run log'::text;
              when others then failed := failed + 1; results := results || ('FAIL 73 ' || sqlstate || ' ' || sqlerrm); end;

    raise exception 'RLS TESTS: % failed of %. %', failed, coalesce(array_length(results, 1), 0), array_to_string(results, ' | ');
end
$test$;
