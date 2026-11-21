-- Coding challenges (Nov 17, S45): LeetCode-style problems whose code runs
-- on the Codey runner (runner/SETUP.md) through the run-challenge Edge
-- Function. Drills (content_exercises) gain hints.
--
-- Read-only through the API, like the other content_* tables. Hidden test
-- cases are the exception to "content is public": anon and signed-in users
-- see only the examples; the Edge Function reads the rest with the service
-- role. Reference solutions are never stored here (they live in the repo,
-- supabase/content/challenges/<id>/).
--
-- Solved challenges reuse profiles.solved_exercise_ids (ids start "ch-"),
-- so they sync and pay XP once like drills, with no new column.
--
-- LIMITS MUST MATCH the app (ChallengeLoader, SupabaseSchemaTests).

alter table public.content_exercises
    add column hints jsonb not null default '[]'::jsonb
        check (jsonb_typeof(hints) = 'array' and jsonb_array_length(hints) <= 3);

create table public.content_challenges (
    id text primary key check (id ~ '^ch-[a-z0-9-]{1,96}$'),
    topic_id text not null references public.content_topics (id) on delete cascade,
    title text not null check (char_length(title) between 1 and 100),
    difficulty text not null check (difficulty in ('easy', 'medium', 'hard')),
    statement text not null check (char_length(statement) between 1 and 8000),
    constraints text[] not null default '{}',
    hints jsonb not null default '[]'::jsonb
        check (jsonb_typeof(hints) = 'array' and jsonb_array_length(hints) <= 3),
    function_name text not null check (function_name ~ '^[A-Za-z_][A-Za-z0-9_]{0,63}$'),
    -- [{"name": "nums", "type": "int[]"}, ...]
    params jsonb not null check (jsonb_typeof(params) = 'array' and jsonb_array_length(params) between 1 and 6),
    return_type text not null check (return_type in (
        'int', 'long', 'double', 'bool', 'string',
        'int[]', 'long[]', 'double[]', 'bool[]', 'string[]', 'int[][]', 'string[][]')),
    comparator text not null default 'exact' check (comparator in ('exact', 'unordered', 'float')),
    editorial text not null default '',
    sort_index int not null default 0
);

create table public.content_challenge_starters (
    challenge_id text not null references public.content_challenges (id) on delete cascade,
    language text not null check (language in ('swift', 'python', 'java', 'cpp')),
    code text not null check (char_length(code) between 1 and 8000),
    primary key (challenge_id, language)
);

create table public.content_challenge_tests (
    id text primary key,
    challenge_id text not null references public.content_challenges (id) on delete cascade,
    ordinal int not null check (ordinal >= 1),
    args jsonb not null check (jsonb_typeof(args) = 'array'),
    expected jsonb not null,
    is_example boolean not null default false,
    explanation text,
    unique (challenge_id, ordinal)
);

create index content_challenges_topic on public.content_challenges (topic_id);
create index content_challenge_tests_challenge on public.content_challenge_tests (challenge_id);

alter table public.content_challenges enable row level security;
alter table public.content_challenge_starters enable row level security;
alter table public.content_challenge_tests enable row level security;

create policy "content is public" on public.content_challenges for select to anon, authenticated using (true);
create policy "content is public" on public.content_challenge_starters for select to anon, authenticated using (true);
create policy "examples are public" on public.content_challenge_tests for select to anon, authenticated using (is_example);

-- Rate limiting for run-challenge: one row per Run/Submit. Service role
-- only (no policies; RLS on). subject = user id, or a hash of the IP.
create table public.challenge_runs (
    id bigint generated always as identity primary key,
    subject text not null check (char_length(subject) between 1 and 100),
    mode text not null check (mode in ('run', 'submit')),
    created_at timestamptz not null default now()
);
create index challenge_runs_subject_time on public.challenge_runs (subject, created_at);
alter table public.challenge_runs enable row level security;
revoke all on public.challenge_runs from anon, authenticated;

comment on table public.content_challenges is 'Coding challenges (S45). Edit here or via scripts/challenges.py; tests in content_challenge_tests.';
comment on table public.content_challenge_starters is 'Starter code per challenge and language (swift, python, java, cpp).';
comment on table public.content_challenge_tests is 'Test cases. args = JSON array (one per param). Only is_example rows are readable by the app.';
comment on table public.challenge_runs is 'run-challenge rate limit log. Service role only.';
comment on column public.content_exercises.hints is 'Drill hints: JSON array of up to 3 strings (2 expected), shown one at a time.';
