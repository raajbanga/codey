-- FR-61: study results sync (card mastery, quiz progress, tier unlocks).
-- Replaces D10 ("progress stays local") for these three; quiz history,
-- daily activity, badges and resumable sessions stay on the device.
--
-- Keys: card ids are the same on every device (starter cards use StableID,
-- user cards share the server id); question/topic ids are bundle strings.
-- Rows are per owner, so two accounts can hold progress for the same card.
--
-- Merge (same rule as the client's pull):
--   card_progress, question_progress  latest review wins, by the CLIENT
--       timestamp. An incoming row that isn't newer is skipped (the BEFORE
--       UPDATE trigger returns null), so a slow device can't undo a newer
--       rating and an echo of the same row doesn't bump the cursor.
--   topic_progress  unlocks are sticky (FR-26): keep the earliest non-null
--       date per tier. least() ignores nulls.
--
-- LIMITS MUST MATCH the app (SupabaseSchemaTests checks them):
--   mastery 0–5 (Flashcard.maxMastery), counters 0–100000, ids 1–100 chars.

-- ── Tables ───────────────────────────────────────────────────────────────

create table public.card_progress (
    owner_id          uuid not null default auth.uid() references auth.users (id) on delete cascade,
    card_id           uuid not null,
    mastery_score     integer not null check (mastery_score between 0 and 5),
    -- CLIENT clock; the merge compares these.
    last_reviewed_at  timestamptz not null,
    retired_at        timestamptz,
    server_updated_at timestamptz not null default now(),
    primary key (owner_id, card_id)
);

create table public.question_progress (
    owner_id            uuid not null default auth.uid() references auth.users (id) on delete cascade,
    question_id         text not null check (char_length(question_id) between 1 and 100),
    topic_id            text not null check (char_length(topic_id) between 1 and 100),
    difficulty          text not null check (difficulty in ('easy', 'medium', 'hard')),
    consecutive_correct integer not null check (consecutive_correct between 0 and 100000),
    total_attempts      integer not null check (total_attempts between 0 and 100000),
    total_correct       integer not null check (total_correct between 0 and 100000),
    retired_at          timestamptz,
    is_review           boolean not null default false,
    -- CLIENT clock; the merge compares these.
    last_answered_at    timestamptz not null,
    server_updated_at   timestamptz not null default now(),
    primary key (owner_id, question_id),
    constraint question_progress_correct_le_attempts check (total_correct <= total_attempts),
    constraint question_progress_streak_le_correct check (consecutive_correct <= total_correct)
);

create table public.topic_progress (
    owner_id           uuid not null default auth.uid() references auth.users (id) on delete cascade,
    topic_id           text not null check (char_length(topic_id) between 1 and 100),
    medium_unlocked_at timestamptz,
    hard_unlocked_at   timestamptz,
    server_updated_at  timestamptz not null default now(),
    primary key (owner_id, topic_id)
);

comment on table public.card_progress is 'FR-61 flashcard mastery per user. Latest review wins.';
comment on table public.question_progress is 'FR-61 quiz progress per user and question. Latest answer wins.';
comment on table public.topic_progress is 'FR-61 quiz tier unlocks per user and topic. Sticky: earliest unlock kept.';

-- Pull cursor scans (owner, server_updated_at), like decks/flashcards.
create index card_progress_owner_cursor on public.card_progress (owner_id, server_updated_at);
create index question_progress_owner_cursor on public.question_progress (owner_id, server_updated_at);
create index topic_progress_owner_cursor on public.topic_progress (owner_id, server_updated_at);

-- ── Merge triggers ───────────────────────────────────────────────────────
-- Named so they fire before the *_set_server_updated_at triggers (name order).

create function private.card_progress_merge()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.last_reviewed_at <= old.last_reviewed_at then
        return null;
    end if;
    return new;
end;
$$;

create function private.question_progress_merge()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.last_answered_at <= old.last_answered_at then
        return null;
    end if;
    return new;
end;
$$;

create function private.topic_progress_merge()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.medium_unlocked_at := least(old.medium_unlocked_at, new.medium_unlocked_at);
    new.hard_unlocked_at := least(old.hard_unlocked_at, new.hard_unlocked_at);
    if new.medium_unlocked_at is not distinct from old.medium_unlocked_at
       and new.hard_unlocked_at is not distinct from old.hard_unlocked_at then
        return null;
    end if;
    return new;
end;
$$;

revoke execute on function private.card_progress_merge(), private.question_progress_merge(),
    private.topic_progress_merge() from public, anon, authenticated;

create trigger card_progress_a_merge before update on public.card_progress
    for each row execute function private.card_progress_merge();
create trigger question_progress_a_merge before update on public.question_progress
    for each row execute function private.question_progress_merge();
create trigger topic_progress_a_merge before update on public.topic_progress
    for each row execute function private.topic_progress_merge();

create trigger card_progress_set_server_updated_at before insert or update on public.card_progress
    for each row execute function public.set_server_updated_at();
create trigger question_progress_set_server_updated_at before insert or update on public.question_progress
    for each row execute function public.set_server_updated_at();
create trigger topic_progress_set_server_updated_at before insert or update on public.topic_progress
    for each row execute function public.set_server_updated_at();

-- ── RLS: owner only, no delete (account deletion cascades) ───────────────

alter table public.card_progress     enable row level security;
alter table public.question_progress enable row level security;
alter table public.topic_progress    enable row level security;

create policy "card_progress: read own" on public.card_progress
    for select to authenticated using (owner_id = (select auth.uid()));
create policy "card_progress: insert own" on public.card_progress
    for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "card_progress: update own" on public.card_progress
    for update to authenticated
    using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

create policy "question_progress: read own" on public.question_progress
    for select to authenticated using (owner_id = (select auth.uid()));
create policy "question_progress: insert own" on public.question_progress
    for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "question_progress: update own" on public.question_progress
    for update to authenticated
    using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

create policy "topic_progress: read own" on public.topic_progress
    for select to authenticated using (owner_id = (select auth.uid()));
create policy "topic_progress: insert own" on public.topic_progress
    for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "topic_progress: update own" on public.topic_progress
    for update to authenticated
    using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
