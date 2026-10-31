-- Sprint 3, S3-C.
-- FR-04: profiles.avatar_id is limited to the app's avatar set
-- (ProfileAvatar.symbols; SupabaseSchemaTests keeps the lists equal).
-- FR-49: feedback_reports, an insert-only inbox for UI/UX issue reports.

alter table public.profiles drop constraint if exists profiles_avatar_id_check;
alter table public.profiles add constraint profiles_avatar_id_check
    check (avatar_id is null or avatar_id in ('person.fill', 'star.fill', 'bolt.fill', 'leaf.fill', 'flame.fill', 'moon.fill', 'sun.max.fill', 'cloud.fill', 'hare.fill', 'tortoise.fill', 'brain.head.profile', 'terminal.fill'));

create table public.feedback_reports (
    id          uuid primary key default gen_random_uuid(),
    owner_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
    description text not null
                check (char_length(btrim(description, E' \t\r\n')) between 1 and 1000),
    app_version text check (app_version is null or char_length(app_version) <= 32),
    os_version  text check (os_version is null or char_length(os_version) <= 32),
    created_at  timestamptz not null default now()
);

comment on table public.feedback_reports is
    'FR-49 UI/UX issue reports. Users insert their own; nobody reads them through the API (read in the dashboard).';

create index feedback_reports_owner_id_idx on public.feedback_reports (owner_id);

-- RLS (NFR-07): insert own rows only. No select/update/delete policies, so
-- a user can't read reports back, even their own.
alter table public.feedback_reports enable row level security;

create policy "feedback_reports: insert own" on public.feedback_reports
    for insert to authenticated
    with check (owner_id = (select auth.uid()));
