## Summary

<!-- What changed and why. Link the FR/NFR IDs. Commit titles use `type(scope): summary`. -->

## Checklist

- [ ] `tuist generate` is clean and tests pass
- [ ] No secrets in source: `scripts/check-secrets.sh` passes (`--history` before merging to main), and `Config/Secrets.xcconfig` is not staged (R10)
- [ ] No tokens, emails, or user IDs logged at `.public` privacy (R10)
- [ ] `scripts/check-imports.sh` passes: Supabase/GoogleSignIn are imported only under `Services/Backend/Supabase/` (R7)
- [ ] Validation limits changed? `ModelValidator`, `flashcard.schema.json`, and the SQL CHECKs in `supabase/migrations` still match (SupabaseSchemaTests)
- [ ] New table? It has `enable row level security` + owner policies, and `supabase test db` passes (R10)
- [ ] Migrations are new files only (never edit one that has been applied)
- [ ] SwiftData model changed? Added a new `CodeySchemaV*` + migration stage (never edit a shipped schema)
