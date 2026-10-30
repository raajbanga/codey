-- Sprint 3, S3-D: leaderboard groups + weekly XP (FR-42, FR-50–52).
--
-- groups         a named group with a server-made 6-char invite code.
-- group_members  who is in which group. Rows come from the create trigger
--                and join_group(); users can only delete their own (leave).
-- weekly_xp      XP earned per user per UTC week (Monday). Max-merged on
--                update, like profiles.total_xp.
-- group_leaderboard  view: this week's XP for every member of your groups.
--
-- Helpers live in the `private` schema, which PostgREST doesn't expose, so
-- join_group() is the only new /rpc endpoint.

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- ── Tables ───────────────────────────────────────────────────────────────

create table public.groups (
    id          uuid primary key default gen_random_uuid(),
    name        text not null
                check (char_length(btrim(name, E' \t\r\n')) between 1 and 40),
    invite_code text not null unique check (invite_code ~ '^[A-Z0-9]{6}$'),
    created_by  uuid not null default auth.uid() references auth.users (id) on delete cascade,
    created_at  timestamptz not null default now()
);

create table public.group_members (
    group_id  uuid not null references public.groups (id) on delete cascade,
    user_id   uuid not null default auth.uid() references auth.users (id) on delete cascade,
    joined_at timestamptz not null default now(),
    primary key (group_id, user_id)
);

create index group_members_user_id_idx on public.group_members (user_id);

create table public.weekly_xp (
    owner_id   uuid not null default auth.uid() references auth.users (id) on delete cascade,
    week_start date not null check (extract(isodow from week_start) = 1),
    xp         integer not null check (xp between 0 and 22500),
    updated_at timestamptz not null default now(),
    primary key (owner_id, week_start)
);

comment on table public.groups is 'FR-50 leaderboard groups. Visible to members only.';
comment on table public.weekly_xp is 'FR-42 XP per user per UTC week (week_start is a Monday). Visible to you and your group mates.';

-- ── Membership helpers (SECURITY DEFINER so policies don't recurse) ──────

create function private.is_member(target_group uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
    select exists (
        select 1 from public.group_members
        where group_id = target_group and user_id = (select auth.uid())
    );
$$;

create function private.shares_group(other_user uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.group_members mine
        join public.group_members theirs on theirs.group_id = mine.group_id
        where mine.user_id = (select auth.uid()) and theirs.user_id = other_user
    );
$$;

revoke execute on function private.is_member(uuid), private.shares_group(uuid) from public, anon;
grant execute on function private.is_member(uuid), private.shares_group(uuid) to authenticated;

-- ── Invite codes: always made on the server ──────────────────────────────

-- 6 characters from a 32-letter alphabet (no 0/O, 1/I), random bytes from
-- gen_random_uuid(). 32^6 ≈ 1.07 billion codes.
create function private.new_invite_code()
returns text
language plpgsql volatile security definer
set search_path = ''
as $$
declare
    alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    bytes bytea;
    code text;
begin
    loop
        bytes := uuid_send(gen_random_uuid());
        code := '';
        for i in 0..5 loop
            code := code || substr(alphabet, 1 + get_byte(bytes, i) % 32, 1);
        end loop;
        exit when not exists (select 1 from public.groups where invite_code = code);
    end loop;
    return code;
end;
$$;

-- Ignores any client-sent code and creator; adds the creator as a member.
-- SECURITY DEFINER so the code check sees every group, not just yours.
create function private.groups_before_insert()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
    new.invite_code := private.new_invite_code();
    new.created_by := (select auth.uid());
    new.name := btrim(new.name, E' \t\r\n');
    return new;
end;
$$;

create function private.groups_after_insert()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
    insert into public.group_members (group_id, user_id) values (new.id, new.created_by);
    return null;
end;
$$;

create trigger groups_before_insert before insert on public.groups
    for each row execute function private.groups_before_insert();
create trigger groups_after_insert after insert on public.groups
    for each row execute function private.groups_after_insert();

-- ── weekly_xp: max-merge + updated_at ────────────────────────────────────

create function private.weekly_xp_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.xp := greatest(old.xp, new.xp);
    new.updated_at := now();
    return new;
end;
$$;

create trigger weekly_xp_before_update before update on public.weekly_xp
    for each row execute function private.weekly_xp_before_update();

revoke execute on function private.new_invite_code(), private.groups_before_insert(),
    private.groups_after_insert(), private.weekly_xp_before_update() from public, anon, authenticated;

-- ── join_group: the one RPC ──────────────────────────────────────────────
-- Why an RPC: joining needs to find a group by code before you're a member,
-- and RLS hides groups from non-members. This function does only that
-- lookup + one membership insert for the caller. Codes are 6 characters
-- from 32 letters; a wrong code gets a generic error (no hints).

create function public.join_group(code text)
returns public.groups
language plpgsql security definer
set search_path = ''
as $$
declare
    target public.groups;
    normalized text := upper(btrim(code));
begin
    if (select auth.uid()) is null then
        raise exception 'sign in required' using errcode = '42501';
    end if;
    if normalized !~ '^[A-Z0-9]{6}$' then
        raise exception 'invalid invite code' using errcode = 'P0002';
    end if;
    select * into target from public.groups where invite_code = normalized;
    if target.id is null then
        raise exception 'invalid invite code' using errcode = 'P0002';
    end if;
    insert into public.group_members (group_id, user_id)
    values (target.id, (select auth.uid()))
    on conflict do nothing;
    return target;
end;
$$;

revoke execute on function public.join_group(text) from public, anon;
grant execute on function public.join_group(text) to authenticated;

-- ── RLS (NFR-07: every table) ────────────────────────────────────────────

alter table public.groups        enable row level security;
alter table public.group_members enable row level security;
alter table public.weekly_xp     enable row level security;

create policy "groups: read if member" on public.groups
    for select to authenticated
    using (private.is_member(id));

-- The trigger overwrites created_by, so this only blocks anon/forged rows.
create policy "groups: insert own" on public.groups
    for insert to authenticated
    with check (created_by = (select auth.uid()));

create policy "group_members: read your groups" on public.group_members
    for select to authenticated
    using (private.is_member(group_id));

create policy "group_members: leave" on public.group_members
    for delete to authenticated
    using (user_id = (select auth.uid()));

create policy "weekly_xp: read own and group mates" on public.weekly_xp
    for select to authenticated
    using (owner_id = (select auth.uid()) or private.shares_group(owner_id));

create policy "weekly_xp: insert own" on public.weekly_xp
    for insert to authenticated
    with check (owner_id = (select auth.uid()));

create policy "weekly_xp: update own" on public.weekly_xp
    for update to authenticated
    using (owner_id = (select auth.uid()))
    with check (owner_id = (select auth.uid()));

-- Group mates can see each other's name, avatar, and XP on the board.
create policy "profiles: read group mates" on public.profiles
    for select to authenticated
    using (private.shares_group(id));

-- ── Leaderboard view ─────────────────────────────────────────────────────
-- security_invoker: the caller's RLS applies, so you only get rows for
-- groups you're in. Week = Monday 00:00 UTC.

create view public.group_leaderboard
with (security_invoker = true) as
select
    gm.group_id,
    gm.user_id,
    p.display_name,
    p.avatar_id,
    coalesce(w.xp, 0) as xp
from public.group_members gm
join public.profiles p on p.id = gm.user_id
left join public.weekly_xp w
    on w.owner_id = gm.user_id
   and w.week_start = date_trunc('week', now() at time zone 'utc')::date;

revoke all on public.group_leaderboard from anon;
