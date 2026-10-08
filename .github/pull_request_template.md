## Summary

<!-- What changed and why. Link the todo.txt stage / FR IDs. -->

## Checklist

- [ ] `tuist generate` is clean and tests pass
- [ ] No secrets in source: `git diff --cached | grep -nE 'SUPABASE_ANON_KEY|service_role|apps\.googleusercontent\.com|eyJ[A-Za-z0-9_-]{10,}'` finds nothing, and `Config/Secrets.xcconfig` is not staged
- [ ] No tokens, emails, or user IDs logged at `.public` privacy (R10)
- [ ] Validation limits changed? `ModelValidator`, `flashcard.schema.json`, and the SQL CHECKs still match
- [ ] SwiftData model changed? Added a new `CodeySchemaV*` + migration stage (never edit a shipped schema)
