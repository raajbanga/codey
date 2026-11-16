-- FR-61 (S43): the rest of a learner's progress syncs, so a second device
-- shows the same quests, streak, accuracy, badges and solved exercises.
-- Only resumable study sessions stay on the device (a half-done session is
-- per device, and it expires).
--
-- Merge (same rules as the client's pull, ProgressSync):
--   quiz_answers    append-only history; a resent answer (same question and
--                   time) is ignored. Feeds accuracy (FR-36) and the weekly
--                   challenge (FR-43).
--   daily_activity  one row per device and day; a device only adds, so the
--                   larger counter wins. The day's total is the sum over
--                   devices. Feeds the daily goal and streak (FR-32/33).
--   badge_awards    one row per badge; the earliest earned date is kept.
--   profiles.solved_exercise_ids  union of every device's solved set; the
--                   client merges it like total_xp (an explicit reset wins).
--
-- LIMITS MUST MATCH the app (SupabaseSchemaTests checks them):
--   ids 1–100 chars, day 'yyyy-MM-dd', counters 0–100000, badges = Badge.

-- ── Tables ───────────────────────────────────────────────────────────────

create table public.quiz_answers (
    owner_id          uuid not null default auth.uid() references auth.users (id) on delete cascade,
    question_id       text not null check (char_length(question_id) between 1 and 100),
    topic_id          text not null check (char_length(topic_id) between 1 and 100),
    correct           boolean not null,
    -- CLIENT clock; with question_id it identifies the answer.
    answered_at       timestamptz not null,
    server_updated_at timestamptz not null default now(),
    primary key (owner_id, question_id, answered_at)
);

create table public.daily_activity (
    owner_id          uuid not null default auth.uid() references auth.users (id) on delete cascade,
    device_id         text not null check (char_length(device_id) between 1 and 100),
    day               text not null check (day ~ '^\d{4}-\d{2}-\d{2}$'),
    cards_rated       integer not null default 0 check (cards_rated between 0 and 100000),
    quiz_answers      integer not null default 0 check (quiz_answers between 0 and 100000),
    server_updated_at timestamptz not null default now(),
    primary key (owner_id, device_id, day)
);

create table public.badge_awards (
    owner_id          uuid not null default auth.uid() references auth.users (id) on delete cascade,
    badge             text not null check (badge in ('firstDeck', 'sevenDayStreak', 'xp1000', 'weeklyChallenge')),
    earned_at         timestamptz not null,
    server_updated_at timestamptz not null default now(),
    primary key (owner_id, badge)
);

alter table public.profiles
    add column solved_exercise_ids text[] not null default '{}'
        check (cardinality(solved_exercise_ids) <= 500);

comment on table public.quiz_answers is 'FR-61 graded quiz answers per user (accuracy, weekly challenge). Append-only.';
comment on table public.daily_activity is 'FR-61 daily goal counters per user, device and local day. Larger counter wins; days sum over devices.';
comment on table public.badge_awards is 'FR-61 earned badges per user. Earliest earned date kept.';

create index quiz_answers_owner_cursor on public.quiz_answers (owner_id, server_updated_at);
create index daily_activity_owner_cursor on public.daily_activity (owner_id, server_updated_at);
create index badge_awards_owner_cursor on public.badge_awards (owner_id, server_updated_at);

-- ── Merge triggers ───────────────────────────────────────────────────────
-- quiz_answers needs none: the client upserts with ignoreDuplicates.

create function private.daily_activity_merge()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.cards_rated := greatest(old.cards_rated, new.cards_rated);
    new.quiz_answers := greatest(old.quiz_answers, new.quiz_answers);
    if new.cards_rated = old.cards_rated and new.quiz_answers = old.quiz_answers then
        return null;
    end if;
    return new;
end;
$$;

create function private.badge_awards_merge()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.earned_at >= old.earned_at then
        return null;
    end if;
    return new;
end;
$$;

revoke execute on function private.daily_activity_merge(), private.badge_awards_merge()
    from public, anon, authenticated;

create trigger daily_activity_a_merge before update on public.daily_activity
    for each row execute function private.daily_activity_merge();
create trigger badge_awards_a_merge before update on public.badge_awards
    for each row execute function private.badge_awards_merge();

create trigger quiz_answers_set_server_updated_at before insert or update on public.quiz_answers
    for each row execute function public.set_server_updated_at();
create trigger daily_activity_set_server_updated_at before insert or update on public.daily_activity
    for each row execute function public.set_server_updated_at();
create trigger badge_awards_set_server_updated_at before insert or update on public.badge_awards
    for each row execute function public.set_server_updated_at();

-- ── RLS: owner only, no delete (account deletion cascades) ───────────────

alter table public.quiz_answers   enable row level security;
alter table public.daily_activity enable row level security;
alter table public.badge_awards   enable row level security;

create policy "quiz_answers: read own" on public.quiz_answers
    for select to authenticated using (owner_id = (select auth.uid()));
create policy "quiz_answers: insert own" on public.quiz_answers
    for insert to authenticated with check (owner_id = (select auth.uid()));

create policy "daily_activity: read own" on public.daily_activity
    for select to authenticated using (owner_id = (select auth.uid()));
create policy "daily_activity: insert own" on public.daily_activity
    for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "daily_activity: update own" on public.daily_activity
    for update to authenticated
    using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

create policy "badge_awards: read own" on public.badge_awards
    for select to authenticated using (owner_id = (select auth.uid()));
create policy "badge_awards: insert own" on public.badge_awards
    for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "badge_awards: update own" on public.badge_awards
    for update to authenticated
    using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
