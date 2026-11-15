# Codey — Final Documentation and Release Task List

**Code freeze:** Sun Nov 22 · **Doc due / Expo:** Tue Dec 1
**Team:** Raaj Banga (RB, PM/docs) · Arnav Bawankule (AB, backend/systems) · Elnad Salcinovic (ES, UI/UX & QA)
**Sources of truth:** `docs/course/s4rubric.pdf`, `docs/course/ProjectDetails.docx`, `docs/source/Final_Documentation.tex`

Tick tasks `[x]` as they finish. When every task is ticked, delete this file (git history keeps it).

**Rules:** this is the Final Documentation, not a Sprint 4 update. Anything still pending at finalization is **dismissed** (a limitation or Future Work, never "planned" or `\tbd`). After the freeze: doc work and bug fixes only. Keep 66 + 2 FRs / 32 NFRs (no renumbering).

---

## 1. Doc updates for the game layer (RB): done Nov 14 (S40–S42; S42 decision, FR-60 avatar colors, test counts 426 unit / 77 pgTAP; S43 history sync Nov 15: 439 unit / 95 pgTAP)
- [x] **S41 game layer**: add the S41 decision (Play/Decks game tiles, quests, XP tags, Radix palette, shared `GameTile` / `CodeyChip` / `SessionTopBar` / `SessionSummary`); update FR-30 and O2; drop "no XP for exercises" from the non-goals and UC "no XP is awarded (S31)" (exercises now pay XP); schema V9 in the data model.
- [x] **Screenshots** (`fig:screens`): the figure points at `final-*.png`, which don't exist yet. Capture them from `ScreenTourUITests` on the S41 UI (Play, Decks, quiz setup, quiz question, Ask AI, exercises, exercise, study) into `docs/source/figures/`; recheck the caption against the new screens.
- [x] **Test results** (§18): re-run with `COVERAGE=1 CSV=docs/source/tests/unit.csv scripts/test.sh`; the doc says 416 / 57 suites, now 426 / 59 (adds `XPRewardsTests`). Update `tab:unitresults`, the coverage paragraph, checklist item 3, the summary sentence and the metrics row (~line 618).
- [x] **Screen counts**: now 18 screens / 108 layout checks. Not re-run (UI tests are run manually): confirm "18 screens" and "108 of 108" in the final CI run.

## 2. Final tests (ES, Nov 17–19)
- [x] System tests: ST-03 partial done Nov 14 (RB, iPhone 17 Sim, fresh store: onboarding, quiz, XP, quiz-streak bonus; daily streak/badge/Medium unlock not reached). Still to run by hand: ST-04 (offline then sync) and ST-07 re-run (two Google accounts: sign-in → sync → group → leaderboard → sign-out) → §18e table + checklist item 7.
- [x] Acceptance tests AT-01–07 by a non-author on a fresh install, including one Ask AI chat → §18f table + checklist item 8.
- [x] Log any defect found in the defect table (ID, found by, fix commit, regression test).

## 3. Finalize the document (RB, by Nov 25)
- [x] Retitle to "Final Documentation"; remove every "(Updated for Sprint 4)"; rewrite sprint-relative wording into present tense (keep sprint history only for process, Gantt, risks, version control).
- [ ] **Zero `\tbd{}`** (14 left, all ES results from §2 plus the shortlog and final hash from §4); dismissed items, device rows and the on-device status row are done. `grep -c '\\tbd{' docs/source/Final_Documentation.tex` must be 0.
- [ ] Status table "Software testing" → real state after §2. (Gantt done Nov 14; update its progress again at submission.)
- [x] Sweep: hedges, repeated "as described in Section X", backstory in captions.
- [x] Appendix A opening line; renamed to `Final_Documentation.tex` / `_reading.tex`; README links updated.

## 3b. Last UI pass (RB, before the freeze Sun Nov 22)
- [ ] **Deck builder facelift**: it never got the S41/S42 treatment (bento notes, `CodeyChip` tags, `SessionTopBar`-style header, avatar hue). Bring it in line, then check every other page for any that were missed.
- [ ] **One shared component per element**: go through all pages and make every similar element (cards/notes, tags, buttons, section titles, rows, headers, empty states, progress bars) use the same shared component. Delete the one-off variants: fewer inconsistencies, simpler code, lower LOC. Compile and run the design-token check after.
- [ ] **Play tab icon**: the "Play" tab in the tab bar (next to Decks) uses the SF Symbol `gamecontroller` (`RootView.swift:21`, `Tab("Play", systemImage:)`), while Decks uses our own line icon (`image: "icon-cards"`), so it's the one icon that doesn't match the set. Draw a line icon for it in `scripts/icons/icons.py`, regenerate, and use `Tab(..., image:)`. Also decide whether to rename the tab "Play" → "Study" (it holds quizzes, quests, exercises; Decks holds flashcard study, so "Study" may confuse; maybe "Learn"/"Practice"). The play triangle on buttons is fine; leave it.
- [ ] **Light/dark switching gets stuck** (Profile → Appearance): reproduce first (Light → Dark → System, from inside the profile sheet). Likely causes, in order: (1) `CodeyApp.swift:17` drives it with `.preferredColorScheme(appearance.colorScheme)`, and `nil` (System) after an explicit value is a known SwiftUI bug: the window stays on the last explicit scheme; the change is also made from inside a sheet, which updates out of step with the views under it. Fix: set the window scene's `overrideUserInterfaceStyle` (.unspecified/.light/.dark) on change instead. (2) Subtrees forced to `.environment(\.colorScheme, .light)` (GameTile pastel tiles, Profile header/editor, onboarding, exercise) can look stuck mid-switch; check they follow. (3) `CodeyNavigationTitles` sets `UINavigationBar.appearance()` once at launch; proxies don't touch existing bars, so check nav titles after a switch.
- [ ] **Flashcard swipe feels jarring** (`StudySessionView.commit(_:fromSwipe:)`, ~line 230): on release past the threshold it first animates `drag = .zero` (card snaps back to center, haptic fires), holds 650–900 ms to show the mastery dots change, *then* flies the card off in the swipe direction. Meanwhile the colored outline overlay (`cardArea`, the `strokeBorder` tied to the drag `candidate`) is removed with its own fade at the swiped position, so outline and card split apart. Fix: keep the card moving the way it was swiped (fly off from where the finger let go, outline and card as one), show the score change without the snap-back (e.g. on the next card or in the toast), haptic on release only.
- [ ] **Study progress bar → match the quiz bar**: study uses the plain 4 pt `ProgressBar` in `SessionTopBar`; quiz uses `SegmentedQuizProgress` (6 pt segments, colored per result, in `QuizModeView.swift`). Pull one shared session progress component into `Session.swift` (segmented/continuous, same height and track) and use it in both. Example of the shared-component item above.
- [ ] **Retake screenshots** after the two items above (wait for RB's OK): README (`docs/screenshots/`), report figure (`docs/source/figures/final-*.png`), and any other place they appear.

## 3c. Coding challenges (RB, after §3b; asked Nov 15)
- [ ] **Win screen for an exercise**: today a pass shows the result and explanation inline with a "Try Again" button (`ExerciseView.swift:64`), so it never feels finished and the XP isn't called out. On a pass, show a summary like quiz and study (`QuizSummaryView` / `StudySummaryView`, shared pieces in `Session.swift`): solved, +XP earned (0 if it was already paid), the explanation, then "Done" (back to the list) and "Next challenge". Reuse the shared summary component rather than a third one.
- [ ] **On a fail**: keep the per-blank result and explanation, with "Try again" plus "Try another" (next unsolved exercise in the topic, or any). Ask AI stays available.
- [ ] **More exercises**: only 12 today (Swift 4, Python 3, Algorithms 2, Data Structures 2, OOP 1). Aim for at least 3 per topic and every difficulty tier; run `ExerciseLoaderTests` and the content checks after.
- [ ] **"Complete the code" quiz questions**: multiple-choice questions that show a snippet with one blank and code options (rendered with the code font/highlighting, not plain text). Check the question bank schema and `AnswerOptionRow` for code formatting before adding a new question type; prefer an option `format: code` flag over a new type.

## 4. Freeze and release (freeze Sun Nov 22; submit Tue Dec 1)
- [ ] [AB] After the freeze, re-run (last run Nov 14, after S42): `scripts/gen-file-table.py`, `scripts/gen-pattern-map.sh`, `scripts/gen-appendix-b.sh` (picks up the new Bento, GameTiles, Session, FloatingPanel and Ask AI files).
- [ ] [AB] All tests green in CI on the final commit; all repository checks pass (incl. `check-release-build.sh`).
- [ ] [RB] Squash-merge `dev` → `main`, then merge `main` back into `dev`; `git shortlog -sn` → version-control table; Appendix B "from commit …" → final hash.
- [ ] [RB] Build both PDFs; check TOC, labels, axis labels; copy to `docs/`; README links the final report and Appendix A.
- [ ] [AB] Supabase project active for the Expo (keep-alive green); OpenRouter key still valid and under its 50 free requests/day on demo day.
- [ ] [ES] Rehearse the Expo demo: offline path, signed-in path, one Ask AI chat (fallback if the free model is down: show the stubbed UI test run).
- [ ] [RB] Submit the PDF by Tue Dec 1.

## 5. Schedule

| Week | Dates | Focus |
|---|---|---|
| 13 | Nov 15 – 22 | Doc updates (§1), system and acceptance tests (Nov 17–19); **code freeze Sun Nov 22** |
| 14 | Nov 23 – 29 | Finalization (§3), generators, PDFs (Thanksgiving Wed–Fri) |
| 15 | Nov 30 – Dec 1 | Merge to main, shortlog, final PDFs, submit, Expo |
