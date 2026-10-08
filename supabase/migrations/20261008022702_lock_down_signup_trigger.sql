-- handle_new_user() is SECURITY DEFINER and only meant to run as the
-- auth.users trigger. Don't expose it through /rest/v1/rpc (Supabase lint
-- 0028/0029). Triggers don't need EXECUTE, so sign-up keeps working.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
