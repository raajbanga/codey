# Codey

A gamified computer-science study app for iOS (CS 360, WKU): flashcard decks with
code snippets, adaptive quizzes with Easy/Medium/Hard tiers, XP, streaks, badges,
weekly challenges, and group leaderboards. SwiftUI + SwiftData on the device,
Supabase (PostgreSQL with Row Level Security) in the cloud.

## Build

Requires an Apple Silicon Mac with Xcode 27.2 and [Tuist](https://tuist.io).

```sh
tuist install
tuist generate
```

Without backend keys the app runs fully in local-only mode. To enable sign-in and
sync, copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` (never
commit it) and follow `supabase/README.md`. The full step-by-step guide is
Appendix A of `docs/Sprint3_Documentation.tex`.

## Checks

```sh
scripts/check-imports.sh        # Supabase/Google imports stay in one folder
scripts/check-design-tokens.sh  # screens use design tokens only
scripts/check-secrets.sh        # no keys in the repo (--history before merging to main)
```

## Team

Raaj Banga (PM), Arnav Bawankule (backend), Elnad Salcinovic (UI/UX, QA).
