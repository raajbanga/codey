-- Profiles (D10: display name, avatar, total XP sync; everything else stays
-- on the device). One row per auth user, created by a trigger on sign-up.

create table public.profiles (
    id           uuid primary key references auth.users (id) on delete cascade,
    display_name text not null default 'Codey Learner'
                 check (char_length(btrim(display_name)) between 1 and 30),
    avatar_id    text check (avatar_id is null or char_length(avatar_id) between 1 and 64),
    total_xp     integer not null default 0 check (total_xp >= 0),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

comment on table public.profiles is
    'One per auth user. total_xp merges as max(local, remote) on the client, except an explicit reset.';

-- Keeps profiles.updated_at current on every update.
create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

create trigger profiles_touch_updated_at
    before update on public.profiles
    for each row execute function public.touch_updated_at();

-- New auth user → profile row. Uses the Google display name when present,
-- trimmed to the 30-character limit.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    google_name text := nullif(btrim(coalesce(
        new.raw_user_meta_data ->> 'full_name',
        new.raw_user_meta_data ->> 'name',
        ''
    )), '');
begin
    insert into public.profiles (id, display_name)
    values (new.id, left(coalesce(google_name, 'Codey Learner'), 30));
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();
