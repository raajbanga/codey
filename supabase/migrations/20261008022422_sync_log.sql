-- Append-only audit ledger of pushes (R2). Owners can insert and read their
-- own rows; there are no update/delete policies, so rows can't be changed.

create table public.sync_log (
    id        bigint generated always as identity primary key,
    owner_id  uuid not null default auth.uid() references auth.users (id) on delete cascade,
    entity    text not null check (entity in ('deck', 'card', 'profile')),
    entity_id uuid not null,
    op        text not null check (op in ('upsert', 'delete')),
    client_ts timestamptz not null,
    server_ts timestamptz not null default now(),
    device_id text check (device_id is null or char_length(device_id) between 1 and 100)
);

create index sync_log_owner_time on public.sync_log (owner_id, server_ts);
