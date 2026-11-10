-- Bound how fast weekly XP can grow (FR-42; best effort).
--
-- Quiz answers are graded on the device and never synced (D10: progress
-- stays local), so the server can't recompute anyone's weekly XP. What it
-- can check is pace. One correct answer earns at most 45 XP (XPPolicy:
-- Hard 20 + streak 25), and nobody answers faster than one question every
-- 4.5 s, so XP can't grow faster than 600 per minute of server time.
--
-- Writes over that pace are clamped, not rejected, so the client's sync
-- never fails. The client pushes its full weekly total each time it
-- changes, so a clamped value catches up as later pushes bring more
-- elapsed time.
--
-- Budget:
--   update       600 XP per minute since the row's last accepted write.
--   first write  600 XP per minute since Monday 00:00 UTC, but at most 30
--                minutes' worth: there's no earlier server time to measure
--                from, so a fresh row can't claim the whole week at once.
--
-- Runs after weekly_xp_before_update (triggers fire in name order), so on
-- an update NEW is already max-merged.

create function private.weekly_xp_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    xp_per_minute constant numeric := 600;
    first_write_minutes constant numeric := 30;
    accepted integer := 0;
    minutes numeric;
begin
    if tg_op = 'UPDATE' then
        accepted := old.xp;
        minutes := extract(epoch from now() - old.updated_at) / 60;
    else
        -- An upsert onto an existing row runs this INSERT trigger first; the
        -- UPDATE pass measures from that row instead.
        if exists (
            select 1 from public.weekly_xp
            where owner_id = new.owner_id and week_start = new.week_start
        ) then
            return new;
        end if;
        minutes := least(
            extract(epoch from now() - (new.week_start::timestamp at time zone 'UTC')) / 60,
            first_write_minutes
        );
    end if;
    new.xp := least(new.xp::numeric, accepted + greatest(floor(minutes * xp_per_minute), 0))::integer;
    return new;
end;
$$;

create trigger weekly_xp_limit before insert or update on public.weekly_xp
    for each row execute function private.weekly_xp_limit();

revoke execute on function private.weekly_xp_limit() from public, anon, authenticated;
