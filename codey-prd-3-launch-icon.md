# PRD 3: Codey — Launch Loading Screen & App Icon

Small sprint. Builds on PRD 1 (design tokens, SwiftData container) and PRD 2 (seeding). Same guardrails as before still apply (iOS-only, Swift 5.10, no new dependencies, no network).

## 0. One Technical Correction (agent needs to know this up front)

A native `LaunchScreen` (storyboard or the `UILaunchScreen` Info.plist key) **is static** — it renders before your app code runs and cannot show real progress. "Real progress tied to boot work" means: the system launch screen can stay a plain background/logo (instant, unavoidable), and immediately after that, `ContentView` shows a **SwiftUI loading view** that does the actual tracked work before revealing `MainTabView`. Don't try to animate a real progress bar inside the static launch screen — it's not possible, and an agent that doesn't know this will waste time trying.

## 1. Objective

- A `LoadingView` shown at app start, with a progress bar that reflects real boot steps (SwiftData container setup, seed check, seeding) — not a fake timed animation.
- A simple app icon: terminal window motif, monochrome, matches existing design tokens.

## 2. Loading Screen — Boot Steps & Progress Mapping

Define fixed, ordered steps so progress is deterministic, not vibes-based:

| Step | Progress after completion |
|---|---|
| Initialize `ModelContainer` | 25% |
| Check if `Topic` table is empty | 50% |
| Run `QuestionBankLoader` (decode + parse JSON) | 75% |
| Insert seeded data into SwiftData (skip if already seeded, jump straight to 100%) | 100% |

- `LoadingView` owns this sequence (an `async` function, awaited step by step), updates a `@State` progress value after each step completes, then transitions to `MainTabView` once at 100%.
- Use `CodeyProgress` (from PRD 1's design system) for the bar — don't build a second one-off progress bar component.
- If seeding is skipped (data already exists), still show the four steps' progress motion — don't jump-cut straight to 100% instantly, it should read as "checked and confirmed," not skipped. A brief `Task.sleep` (e.g. 150–250ms) between steps in that fast path is fine and expected, purely for perceptual smoothness — not a fake progress simulation, just pacing real completed work.
- On any failure (e.g. `QuestionBankLoader` throws on malformed JSON), `LoadingView` shows a simple inline error state with the failure message — do not silently proceed into `MainTabView` with an empty/broken database.

## 3. App Icon — Terminal Window Concept

- Motif: a simple terminal/console window — rounded-rect frame, a thin title bar strip at top (optionally with 3 small dots, macOS-terminal style), and a `>` prompt or blinking-cursor `_` glyph inside the body.
- Monochrome, built from existing design tokens (Primary/Accent color from PRD 1's `Colors.swift`) — not a multi-color illustration. Simple enough to read at 60×60pt on a home screen.
- **No text/wordmark in the icon** — glyph only, standard App Store guidance (small sizes make text illegible).
- Deliverable: a single 1024×1024 flat PNG (no alpha channel, no pre-rounded corners — iOS applies the corner mask automatically), placed in `Assets.xcassets/AppIcon.appiconset/`. Use Xcode's single-size App Icon set (iOS 17+ supports one 1024pt source scaled automatically) — don't hand-generate the old multi-size icon set, that's unnecessary busywork for a target this new.

## 4. File Additions

```
Sources/
├── App/
│   └── LoadingView.swift
Assets.xcassets/
└── AppIcon.appiconset/
    └── icon-1024.png
```

`CodeyApp.swift` changes: root view becomes `LoadingView`, which transitions to `MainTabView` (via PRD 1's `ContentView` or directly) once boot steps complete.

## 5. Non-Goals

- No custom animated launch screen using native storyboard tricks — see Section 0.
- No multi-size manually-generated icon set — single 1024pt source only.
- No skipping the visual step sequence even when seeding is skipped (Section 2).

## 6. Acceptance Criteria

- [ ] App launch shows `LoadingView` with a `CodeyProgress` bar that visibly advances through the 4 real steps in Section 2.
- [ ] Fresh install: seeding actually runs, progress reflects it, ends at `MainTabView`.
- [ ] Second launch (already seeded): progress still animates through all 4 steps at a readable pace, doesn't feel like a skipped/broken bar.
- [ ] Malformed/failed seed shows an inline error, never silently opens into a broken app state.
- [ ] App icon is a single 1024×1024 flat PNG, terminal-window motif, monochrome from design tokens, no alpha, no pre-rounded corners, correctly wired into `AppIcon.appiconset`.
