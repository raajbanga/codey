# Codey — Final Documentation and Release Task List

**Code freeze:** Sun Nov 22 · **Doc due / Expo:** Tue Dec 1
**Team:** Raaj Banga (RB, PM/docs) · Arnav Bawankule (AB, backend/systems) · Elnad Salcinovic (ES, UI/UX & QA)
**Sources of truth:** `docs/course/s4rubric.pdf`, `docs/course/ProjectDetails.docx`, `docs/source/Final_Documentation.tex` (Ignore the rubric's word count (6000) that's a minimum.)

Tick tasks `[x]` as they finish. When every task is ticked, delete this file (git history keeps it).

**Rules:** this is the Final Documentation, not a Sprint 4 update. Anything still pending at finalization is **dismissed** (a limitation or Future Work, never "planned" or `\tbd`). After the freeze: doc work and bug fixes only. Keep 66 + 2 FRs / 32 NFRs (no renumbering).

## Freeze and release (freeze Sun Nov 22; submit Tue Dec 1)
- [ ] [AB] On the final commit: `CSV=docs/source/tests/unit.csv COVERAGE=1 scripts/test.sh` and the UI suites (`scripts/test.sh -only-testing:codeyUITests`); update the counts if they changed (457 unit, 89.4%).
- [ ] [AB] All repository checks pass (incl. `check-release-build.sh`); CI green on the final commit.
- [ ] [RB] Squash-merge `dev` → `main`, merge `main` back into `dev`, tag `final`; `git shortlog -sn` → version-control table; Appendix B "from commit …" → final hash (the last `\tbd`).
- [ ] [RB] Update the commit hashes cited in the report. The history was rewritten again on Nov 17 (author emails switched to the GitHub noreply address, `__pycache__` and the Cursor co-author trailers removed), so every hash changed. Same commits, same dates; only the IDs differ. In `docs/source/Final_Documentation.tex` replace: `0b4deae` → `55b8658` (merge activity8_1 into dev), `6bf7ac2` → `676b361` (merge main into dev), `535911e` → `81ec09e` (coding exercises, Sprint 4 doc progress; 4 places), `e12c8b6` → `f306adb` (perf: memory growth, launch fixture), `d549198` → `c0caa4a` (fix bugs, Swift 6, CI), `1949cfe` → `c0149e4` (Google sign-in and progress sync; 2 places), `5176c19` → `96a8342` (Supabase schema and RLS), `cf86281` → `6e5e8c6` (BUG-04 card-flip crash). `docs/source/generated/appendix_b.tex` and `pattern_lines.tex` say "generated on 5a2a20e" (a commit dropped in the Nov 16 cleanup): rerun `scripts/gen-appendix-b.sh` and `scripts/gen-pattern-map.sh`. Then rebuild the PDFs in `docs/` (they still show the old hashes). Check with `git cat-file -e <hash>` that every hash cited in the report exists.
- [ ] [RB] Gantt: set each bar's progress at submission (no 0% bars).
- [ ] [RB] Build both PDFs with `tectonic`; check TOC, labels, figures; copy to `docs/`; README links them.
- [ ] [AB] Supabase project active for the Expo (keep-alive green); OpenRouter key valid and under its 50 free requests/day on demo day.
- [ ] [ES] Rehearse the Expo demo: offline path, signed-in path, one Ask AI chat (if the free model is down, show the stubbed UI test run).
- [ ] [RB] Submit the PDF by Tue Dec 1.
- [ ] [RB] Rework the commit-history evidence in the report (Version Control → Evidence, `tab:shortlog` and the paragraph after it) so it doesn't read as one person's work. Most commits were made from RB's machine during pair-programming sessions and carry `Co-authored-by` trailers for AB and ES, but the table counts `git shortlog -sn` authors only (RB 95 vs 2 / 2). Lead with **commits each member authored or co-authored** (`git log dev --format='%an%n%B'`, matching the name in the author or a trailer), with authored-only as a secondary column. Counts on `dev` right now: 97 commits; AB 60, ES 64 authored or co-authored. Recount on the final commit. The history was rewritten on Nov 16 (coursework, todo/PRD files and the Claude co-author trailers removed), so the old numbers (106 total, Claude 7 + 47 co-authored, "ElnadSosa") are stale: update the table and notes, and say the counts are after the cleanup. Keep the line that the Gantt owner column records who did each task.
- [ ] **FINAL TASK, do last:** delete this file (`git rm todo.md`), commit and push. Planning docs don't belong in the public repo, so `main` and the `final` tag must not contain it: if `dev` is merged to `main` before every task here is ticked, delete it on `dev` first and keep tracking the remaining tasks outside the repo.

## iPad support (land before the freeze, Sun Nov 22; owner TBD)
Goal: the Expo demo runs on iPad in landscape. Mockups: https://claude.ai/artifact/TUCtDUx6BSjEyMaRk4Bxhw

**What we found.** The app has no size-class or device checks. Every list on Play and Decks goes through `BentoGrid` (already 2 columns, 1 at accessibility sizes). Every font is a Dynamic Type style, and icons scale with `relativeTo:`. So iPad is a few changes in shared code, not a redesign. Spacing tokens are static `let`s (`CodeySpacing`), so they need an environment-driven scale where it shows. iPadOS 26 draws `TabView` as a floating bar at the top centre (between Play's streak pill and its trophy and profile buttons). That is the native iPad layout, so we keep it.

**Decisions.** Switch on `horizontalSizeClass == .regular`, never on device model, so split view and Stage Manager fall back to the iPhone layout. Portrait: one page, 2-column grid, scaled up (tiles about 370 pt). Landscape: two phone-width columns side by side, each with the iPhone's 2-up tiles (about 255 pt), not one stretched page. Trigger the landscape split on the page's own width (about 1000 pt or more), not on orientation, so Stage Manager windows behave. Sessions are capped in width rather than put in a grid.

**Scope and guardrails.** The mockups and the Play / Deck detail splits below are illustrative only. The mockups are hand-drawn HTML approximations: they don't match the real components exactly (spacing, icons, chip styles, tile contents) and aren't a spec. The work is app-wide: audit every screen (each tab root, pushed page, sheet, full-screen cover and floating panel) in both orientations and decide its regular-width layout. Do all of it through the existing design-system layer:
- Layout goes through the shared components (`CodeyPage`, `HeroCard`, `BentoSection` / `BentoGrid`, `GameTile`, `NoteGroup`, `CodeyCard`) and the tokens (`CodeySpacing`, `CodeyRadius`, type tokens). Extend those components with parameters where needed (e.g. a `trailing` slot on `CodeyPage`, a `columns` override on `BentoGrid`) so every screen gets the same grid, gutters and type scale.
- Read the size class in one place: the `codeyLayout` environment value set in `RootView`. No `@Environment(\.horizontalSizeClass)` reads, `UIDevice`/`userInterfaceIdiom` checks, `GeometryReader` breakpoints or hard-coded widths scattered through feature views, and no per-screen one-off view modifiers that copy what a shared component already does.
- If a screen needs something the shared layer can't express, add it to the design system (with a `ComponentGallery` entry), not inline in the feature.

**Simulator.** iPad (A16) on iOS 26 (820 × 1180 pt). It is the base iPad and the lightest iPad simulator, and it is the iPad most classrooms have. It needs a Mac with Xcode. Claude Code's cloud sessions run on Linux and can't run any iOS simulator.

- [x] `Project.swift`: app + test targets `destinations: [.iPhone, .iPad]`; confirm `UISupportedInterfaceOrientations~ipad` lists all four (needed for iPad multitasking); `tuist generate`, build for iPad (A16).
- [x] `codeyLayout` environment value (compact / regular) set once from `horizontalSizeClass`; check it reaches the full-screen covers, sheets, floating panels and the overlay host. (Set in `ContentView`, one level above `RootView`, so onboarding's cover gets it too: `DesignSystem/Tokens/Layout.swift`.)
- [x] Text floor: on regular width, `.dynamicTypeSize(.xxLarge...)` at the root (body 17 → 21 pt). A floor, not a fixed size, so a user's larger setting still wins. Keep the top of the range below accessibility sizes so `BentoGrid` doesn't drop to 1 column without the user asking for it.
- [x] Spacing: on regular, page margin 16 → 32 pt (`CodeyPage`), grid gap 12 → 18 (`BentoGrid`), tile and hero padding 16 → 24 (`GameTile`, `HeroCard`). Keep the change to those components and don't touch `CodeySpacing` globally (`check-design-tokens.sh` must stay green).
- [x] Width cap of about 720 pt, centred, for Study, Quiz, Exercise (code editor), Ask AI chat, Quiz setup panel, and the study/quiz summaries.
- [x] Landscape split: `CodeyPage` gets an optional `trailing` section that sits beside `content` in a second phone-width column when the page is at least about 1000 pt wide (measured with `onGeometryChange`), and goes below `content` otherwise. Both columns are in one `ScrollView`. Play: hero + Today's quests on the left, This week on the right. Deck detail: hero + Study on the left, Cards on the right. Profile: decide per section. (Profile is a form sheet on iPad, so it stays one column. Library's topic page also splits: hero, Play Quiz and Exercises on the left, Decks on the right.)
- [x] Single-grid pages (Decks, Library) in landscape: hero full width, `BentoGrid` at 4 columns, which looks like two phone grids side by side. Add a `columns` override to `BentoGrid` (default 2). (`BentoColumns.spread`; `ComponentGallery` has an "Bento, iPad" entry.)
- [ ] Check on iPad: top tab bar vs the page's button row and the top `ScreenEdgeFade`; `.tabBarMinimizeBehavior` (iPhone-only, should be a no-op); swipe-back; `CodeyMenu` anchoring after rotation; sheets (Profile, deck builder) as form sheets; `CardPagerView`'s `containerRelativeFrame` paging; keyboard + code editor; Google sign-in presentation.
- [ ] Screenshots, iPad (A16), both orientations: Play, Decks, Deck detail, Library, Study, Quiz, Exercise, Ask AI, Profile. Also re-shoot iPhone 17 Play and Decks to confirm the iPhone layout hasn't changed.
- [ ] Tests: unit + UI suites still pass on iPhone 17 (CI unchanged); one run of the UI suite on `DESTINATION='platform=iOS Simulator,name=iPad (A16)' scripts/test.sh -only-testing:codeyUITests`. Fix or list any failures caused by the tab bar moving to the top; don't skip tests.
- [x] Docs: say "iPhone and iPad" where the platform is named, and add one iPad screenshot. No new FR/NFR numbers (rule above). Anything not done by the freeze goes under Limitations / Future Work.
- [ ] Expo: rehearse the demo on iPad in landscape (add this to ES's rehearsal task above).
- [x] Mac (Mac Catalyst, Nov 16): `.macCatalyst` destination, signed with the team so the keychain entitlement (`codey/codey.entitlements`) is kept; Google sign-in needs that keychain. Sign-in checked; Profile sheet sized to the window (`codeyPageSheet`).
- [x] Retake the screenshots once the iPad/Mac layout is final (README and report: iPhone, iPad, and Mac if it ships), after the text and tile size bump.
- [x] Simplify the commit history on `main` (fewer, clearer squash commits) before tagging `final`.

## 4. Schedule

| Week | Dates | Focus |
|---|---|---|
| 13 | Nov 15 – 22 | Billing, live RLS check, system and acceptance tests (Nov 17–19); **code freeze Sun Nov 22** |
| 14 | Nov 23 – 29 | Final test run, results into the report, PDFs (Thanksgiving Wed–Fri) |
| 15 | Nov 30 – Dec 1 | Merge to main, tag, shortlog, final PDFs, submit, Expo |
