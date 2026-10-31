-- Sprint 3: Security/Performance Advisor fixes after the S3-C/S3-D migrations.

-- rls_auto_enable() is the dashboard's "enable RLS on new tables" event
-- trigger. Event triggers don't need EXECUTE, so revoking API access keeps it
-- working (Supabase lint 0028/0029; same as lock_down_signup_trigger).
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

-- Covering index for groups.created_by (lint 0001).
create index groups_created_by_idx on public.groups (created_by);

-- One SELECT policy on profiles instead of two permissive ones (lint 0006).
drop policy "profiles: read own" on public.profiles;
drop policy "profiles: read group mates" on public.profiles;
create policy "profiles: read own and group mates" on public.profiles
    for select to authenticated
    using (id = (select auth.uid()) or private.shares_group(id));
