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
- [ ] [RB] Gantt: set each bar's progress at submission (no 0% bars).
- [ ] [RB] Build both PDFs with `tectonic`; check TOC, labels, figures; copy to `docs/`; README links them.
- [ ] [AB] Supabase project active for the Expo (keep-alive green); OpenRouter key valid and under its 50 free requests/day on demo day.
- [ ] [ES] Rehearse the Expo demo: offline path, signed-in path, one Ask AI chat (if the free model is down, show the stubbed UI test run).
- [ ] [RB] Submit the PDF by Tue Dec 1.

## iPad support (land before the freeze, Sun Nov 22; owner TBD)
Goal: the Expo demo runs on iPad in landscape. Mockups: https://claude.ai/artifact/TUCtDUx6BSjEyMaRk4Bxhw

**What we found.** The app has no size-class or device checks. Every list on Play and Decks goes through `BentoGrid` (already 2 columns, 1 at accessibility sizes). Every font is a Dynamic Type style, and icons scale with `relativeTo:`. So iPad is a few changes in shared code, not a redesign. Spacing tokens are static `let`s (`CodeySpacing`), so they need an environment-driven scale where it shows. iPadOS 26 draws `TabView` as a floating bar at the top centre (between Play's streak pill and its trophy and profile buttons). That is the native iPad layout, so we keep it.

**Decisions.** Switch on `horizontalSizeClass == .regular`, never on device model, so split view and Stage Manager fall back to the iPhone layout. Portrait: one page, 2-column grid, scaled up (tiles about 370 pt). Landscape: two phone-width columns side by side, each with the iPhone's 2-up tiles (about 255 pt), not one stretched page. Trigger the landscape split on the page's own width (about 1000 pt or more), not on orientation, so Stage Manager windows behave. Sessions are capped in width rather than put in a grid.

**Simulator.** iPad (A16) on iOS 26 (820 × 1180 pt). It is the base iPad and the lightest iPad simulator, and it is the iPad most classrooms have. It needs a Mac with Xcode. Claude Code's cloud sessions run on Linux and can't run any iOS simulator.

- [ ] `Project.swift`: app + test targets `destinations: [.iPhone, .iPad]`; confirm `UISupportedInterfaceOrientations~ipad` lists all four (needed for iPad multitasking); `tuist generate`, build for iPad (A16).
- [ ] `codeyLayout` environment value (compact / regular) set once in `RootView` from `horizontalSizeClass`; check it reaches the full-screen covers, sheets, floating panels and the overlay host.
- [ ] Text floor: on regular width, `.dynamicTypeSize(.xxLarge...)` at the root (body 17 → 21 pt). A floor, not a fixed size, so a user's larger setting still wins. Keep the top of the range below accessibility sizes so `BentoGrid` doesn't drop to 1 column without the user asking for it.
- [ ] Spacing: on regular, page margin 16 → 32 pt (`CodeyPage`), grid gap 12 → 18 (`BentoGrid`), tile and hero padding 16 → 24 (`GameTile`, `HeroCard`). Keep the change to those components and don't touch `CodeySpacing` globally (`check-design-tokens.sh` must stay green).
- [ ] Width cap of about 720 pt, centred, for Study, Quiz, Exercise (code editor), Ask AI chat, Quiz setup panel, and the study/quiz summaries.
- [ ] Landscape split: `CodeyPage` gets an optional `trailing` section that sits beside `content` in a second phone-width column when the page is at least about 1000 pt wide (measured with `onGeometryChange`), and goes below `content` otherwise. Both columns are in one `ScrollView`. Play: hero + Today's quests on the left, This week on the right. Deck detail: hero + Study on the left, Cards on the right. Profile: decide per section.
- [ ] Single-grid pages (Decks, Library) in landscape: hero full width, `BentoGrid` at 4 columns, which looks like two phone grids side by side. Add a `columns` override to `BentoGrid` (default 2).
- [ ] Check on iPad: top tab bar vs the page's button row and the top `ScreenEdgeFade`; `.tabBarMinimizeBehavior` (iPhone-only, should be a no-op); swipe-back; `CodeyMenu` anchoring after rotation; sheets (Profile, deck builder) as form sheets; `CardPagerView`'s `containerRelativeFrame` paging; keyboard + code editor; Google sign-in presentation.
- [ ] Screenshots, iPad (A16), both orientations: Play, Decks, Deck detail, Library, Study, Quiz, Exercise, Ask AI, Profile. Also re-shoot iPhone 17 Play and Decks to confirm the iPhone layout hasn't changed.
- [ ] Tests: unit + UI suites still pass on iPhone 17 (CI unchanged); one run of the UI suite on `DESTINATION='platform=iOS Simulator,name=iPad (A16)' scripts/test.sh -only-testing:codeyUITests`. Fix or list any failures caused by the tab bar moving to the top; don't skip tests.
- [ ] Docs: say "iPhone and iPad" where the platform is named, and add one iPad screenshot. No new FR/NFR numbers (rule above). Anything not done by the freeze goes under Limitations / Future Work.
- [ ] Expo: rehearse the demo on iPad in landscape (add this to ES's rehearsal task above).

## 4. Schedule

| Week | Dates | Focus |
|---|---|---|
| 13 | Nov 15 – 22 | Billing, live RLS check, system and acceptance tests (Nov 17–19); **code freeze Sun Nov 22** |
| 14 | Nov 23 – 29 | Final test run, results into the report, PDFs (Thanksgiving Wed–Fri) |
| 15 | Nov 30 – Dec 1 | Merge to main, tag, shortlog, final PDFs, submit, Expo |
