#!/usr/bin/env bash
# Dumps the remote Supabase database to backups/codey-<UTC timestamp>.sql (R11).
#
#   SUPABASE_DB_URL='postgresql://postgres.<ref>:<password>@<host>:5432/postgres' scripts/backup.sh
#
# Get the URL from Supabase → Project Settings → Database → Connection string
# (session pooler). Keep it in your password manager, never in the repo.
# Needs pg_dump 15+ (brew install libpq && brew link --force libpq).
set -euo pipefail
cd "$(dirname "$0")/.." || exit 2

: "${SUPABASE_DB_URL:?Set SUPABASE_DB_URL (see the comment at the top of this script)}"
command -v pg_dump >/dev/null || { echo "pg_dump not found (brew install libpq)"; exit 2; }

mkdir -p backups
out="backups/codey-$(date -u +%Y%m%dT%H%M%SZ).sql"
# Our schema + data only; auth and storage are Supabase-managed.
pg_dump "$SUPABASE_DB_URL" --schema=public --no-owner --no-privileges --file="$out"
echo "Wrote $out ($(wc -c <"$out" | tr -d ' ') bytes)"
