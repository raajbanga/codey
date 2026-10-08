-- Row Level Security on EVERY table (NFR-07; metric: 100% of tables).
-- Signed-in users see and change only their own rows. Policies target the
-- `authenticated` role, so `anon` gets nothing. `(select auth.uid())` is
-- evaluated once per statement instead of once per row.

alter table public.profiles   enable row level security;
alter table public.decks      enable row level security;
alter table public.flashcards enable row level security;
alter table public.sync_log   enable row level security;

-- profiles: rows are created by the sign-up trigger and deleted by the
-- auth.users cascade, so clients only read and update their own.
create policy "profiles: read own" on public.profiles
    for select to authenticated
    using (id = (select auth.uid()));

create policy "profiles: update own" on public.profiles
    for update to authenticated
    using (id = (select auth.uid()))
    with check (id = (select auth.uid()));

-- decks
create policy "decks: read own" on public.decks
    for select to authenticated
    using (owner_id = (select auth.uid()));

create policy "decks: insert own" on public.decks
    for insert to authenticated
    with check (owner_id = (select auth.uid()));

create policy "decks: update own" on public.decks
    for update to authenticated
    using (owner_id = (select auth.uid()))
    with check (owner_id = (select auth.uid()));

create policy "decks: delete own" on public.decks
    for delete to authenticated
    using (owner_id = (select auth.uid()));

-- flashcards: own rows, and only inside a deck you own.
create policy "flashcards: read own" on public.flashcards
    for select to authenticated
    using (owner_id = (select auth.uid()));

create policy "flashcards: insert own" on public.flashcards
    for insert to authenticated
    with check (
        owner_id = (select auth.uid())
        and exists (select 1 from public.decks d where d.id = deck_id and d.owner_id = (select auth.uid()))
    );

create policy "flashcards: update own" on public.flashcards
    for update to authenticated
    using (owner_id = (select auth.uid()))
    with check (
        owner_id = (select auth.uid())
        and exists (select 1 from public.decks d where d.id = deck_id and d.owner_id = (select auth.uid()))
    );

create policy "flashcards: delete own" on public.flashcards
    for delete to authenticated
    using (owner_id = (select auth.uid()));

-- sync_log: insert + read own; no update/delete policies (append-only).
create policy "sync_log: read own" on public.sync_log
    for select to authenticated
    using (owner_id = (select auth.uid()));

create policy "sync_log: insert own" on public.sync_log
    for insert to authenticated
    with check (owner_id = (select auth.uid()));
