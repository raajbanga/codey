# Codey backend setup (Supabase + Google sign-in)

The database schema lives **in this folder** and is the source of truth.
Everything here is free-tier. Follow the steps in order;
a teammate should be able to reproduce the whole backend from this page.

> The app works fully **without** any of this (local-only mode, R11). Sign-in
> and sync turn on only when every key in `Config/Secrets.xcconfig` is set.

## What's in this folder

| Path | What it is |
| --- | --- |
| `migrations/20261008022407_profiles.sql` | `profiles` + trigger that creates one per new auth user |
| `migrations/20261008022417_decks_flashcards.sql` | `decks`, `flashcards`, CHECKs that mirror `ModelValidator`, the `server_updated_at` pull cursor |
| `migrations/20261008022422_sync_log.sql` | append-only push ledger (R2) |
| `migrations/20261008022429_rls.sql` | Row Level Security on every table + owner-only policies (NFR-07) |
| `migrations/20261008022702_lock_down_signup_trigger.sql` | revokes API access to the sign-up trigger function (Supabase security lint) |
| `migrations/20261030200232_avatar_set_feedback_reports.sql` | FR-04 avatar CHECK to the 12-symbol set; FR-49 insert-only `feedback_reports` |
| `migrations/20261030200303_groups_leaderboard.sql` | `groups`, `group_members`, `weekly_xp` (max-merged), `join_group(code)` (the only RPC), `group_leaderboard` view; group mates can read each other's profile |
| `migrations/20261030200802_s3_advisor_fixes.sql` | Advisor fixes: revoke API access to `rls_auto_enable()`, index `groups.created_by`, one profiles SELECT policy |
| `migrations/20261102182604_weekly_xp_rate_limit.sql` | Clamps `weekly_xp` growth to 600 XP per minute of server time (30 minutes' worth on a week's first write); clamped, never rejected |
| `tests/rls.sql` | pgTAP tests (`supabase test db`): user B sees/changes **0** of user A's rows; constraints match the app |
| `checks/rls_live_check.sql` | 48 of the same checks for the **live** project (Supabase MCP `execute_sql` or SQL editor). Always ends in an error holding the results, so everything rolls back |

Rules: never edit a migration that has been pushed, add a new file instead.
File versions must equal the remote migration versions (`list_migrations` in
the Supabase MCP, or `supabase migration list`).
If you change a limit, change `ModelValidator`, `flashcard.schema.json`, and a
new migration together (`SupabaseSchemaTests` and `FlashcardSchemaFileTests`
fail otherwise).

## 1. Supabase project (manual, once)

1. Sign in at <https://supabase.com/dashboard> and create a project on the
   **Free** plan, in the region closest to the class (e.g. `us-east-1`).
   Save the database password in the team password manager.
2. Project Settings → **API**: copy the **Project URL** and the **anon public**
   key into the password manager.
   **Never** copy the `service_role` key anywhere near the app or this repo.

## 2. Google Cloud OAuth (manual, once)

1. <https://console.cloud.google.com> → new project "Codey".
2. **OAuth consent screen**: External, publishing status **Testing**. Add the
   3 developers and the client as **test users** (Testing allows up to 100).
3. **Credentials → Create OAuth client ID → iOS**:
   bundle ID `edu.wku.cs360.codey` (from `Project.swift`).
   Note the **client ID** and the **reversed client ID** (iOS URL scheme).
4. **Credentials → Create OAuth client ID → Web application**: no redirect URIs
   are needed for native ID-token sign-in. Note its **client ID** and
   **client secret**; Supabase uses them to verify Google ID tokens.

## 3. Turn on Google in Supabase Auth

Authentication → Sign In / Providers → **Google**:

- Enable it. Paste the **Web** client ID and secret.
- Add the **iOS** client ID under *Authorized Client IDs* (Supabase accepts
  ID tokens issued to any listed client).
- *Skip nonce check*: the native flow (GoogleSignIn-iOS →
  `supabase.auth.signInWithIdToken`) historically needed this **on**. Check the
  current Supabase "Login with Google → iOS" docs when you do this and follow
  them. The current project has it **on**.

## 4. App secrets

Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig`
(gitignored) and fill in:

| Key | Value |
| --- | --- |
| `SUPABASE_URL` | Project URL, `https://<ref>.supabase.co` (in xcconfig write `https:/$()/<ref>.supabase.co`, since `//` starts a comment) |
| `SUPABASE_ANON_KEY` | anon public key |
| `GOOGLE_IOS_CLIENT_ID` | iOS client ID |
| `GOOGLE_REVERSED_CLIENT_ID` | reversed iOS client ID |
| `GOOGLE_SERVER_CLIENT_ID` | **Web** client ID |

Then `tuist generate`. `AppConfig.isBackendConfigured` becomes true only when
all five are set.

## 5. Supabase CLI: link and push the schema

```sh
brew install supabase/tap/supabase
cd <repo root>
supabase init          # creates supabase/config.toml; keep the existing migrations/ and tests/
supabase login
supabase link --project-ref <ref>      # <ref> is the id in your project URL
supabase db push                       # applies migrations/*.sql in order
```

`supabase/config.toml` isn't committed, so run `supabase init` once per clone
before using the CLI. (`.branches`/`.temp` are gitignored.)

## 6. Run the RLS tests

`supabase test db` runs `tests/*.sql` (pgTAP) against the **local** stack,
which needs Docker (OrbStack or Docker Desktop) running:

```sh
supabase start        # first run downloads the images
supabase db reset     # applies migrations to the local database
supabase test db      # expect: All tests successful, 51 tests
supabase stop
```

The tests create two users and check: sign-up creates profiles; RLS is on for
100% of tables; user B sees 0 of A's decks/cards/log rows and can't insert,
update, or delete them; `anon` sees nothing; sync_log is append-only;
`server_updated_at` is set by the server; and the length/line/language CHECKs
match the app's validator.

## Current state (2026-11-05)

Project `gwnxkcjijuhkyklsvuta`. All nine migrations in `migrations/` are
applied via the Supabase MCP (the file names equal the remote versions),
including the three from 2026-10-30 (avatar set + insert-only
`feedback_reports`, groups + `group_members` + `weekly_xp` + the
`group_leaderboard` view + `join_group()`, and the Security Advisor fixes) and
the weekly-XP rate limit from 2026-11-02.
RLS is on for 8 of 8 tables. Security Advisor: `rls_auto_enable()` revoked;
the one remaining warning is `join_group` (SECURITY DEFINER, justified: it must
find a group the caller cannot see yet). `checks/rls_live_check.sql`, last run
2026-10-30, before the rate limit: **0 failed of 48**, everything rolled back.
(2026-10-08: 0 of 30, before the groups and feedback tables.) Google provider:
enabled with the Web + iOS client IDs, skip nonce checks on.

With the MCP you don't need steps 5–6: apply new migrations with
`apply_migration`, then rename the repo file to the version `list_migrations`
reports, and re-run `checks/rls_live_check.sql`.

## 7. Ops (R11, NFR-20)

- **Backups**: `SUPABASE_DB_URL='<session pooler URI>' scripts/backup.sh` writes
  `backups/codey-<timestamp>.sql` (gitignored). Needs `pg_dump`
  (`brew install libpq && brew link --force libpq`). Do it weekly; keep the
  last few dumps outside the repo, e.g. in the team drive.
- **Keep-alive**: free projects pause after 7 days idle.
  `.github/workflows/supabase-keepalive.yml` pings the API every 3 days once
  the repo secrets `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set (GitHub →
  Settings → Secrets and variables → Actions). It does nothing without them.
  Both are set (2026-10-08), and the scheduled ping runs from `main`. GitHub
  only runs scheduled workflows from the default branch.
- **Usage**: check the Supabase *Usage* page monthly (database size, egress,
  MAU) against the free-tier limits, and note it in the Sprint metrics table.

## Design notes

- Ids are generated on the client and equal the local SwiftData ids, so an
  upsert is idempotent.
- `created_at`/`updated_at` are **client** times (used for last-writer-wins and
  the additive merge, FR-47). `server_updated_at` is set by a trigger on every
  write and is the pull cursor (`where server_updated_at > lastPull`).
- Deletes are tombstones (`deleted_at`) so other devices can pull them.
- `profiles.total_xp` is written by the client (merged as `max(local, remote)`
  except an explicit reset), so a determined user could inflate their own XP.
  The weekly leaderboard reads `weekly_xp`, which is capped by a CHECK
  (22,500 per week), clamped to 600 XP per minute of server time, and can only
  grow. A server-computed ledger is left as future work (risk R13, accepted).
- Starter decks, quiz progress, mastery, and tier unlocks never leave the
  device.
