# Codey — Final Documentation and Release Task List

**Code freeze:** Sun Nov 22 · **Doc due / Expo:** Tue Dec 1
**Team:** Raaj Banga (RB, PM/docs) · Arnav Bawankule (AB, backend/systems) · Elnad Salcinovic (ES, UI/UX & QA)
**Sources of truth:** `docs/course/s4rubric.pdf`, `docs/course/ProjectDetails.docx`, `docs/source/Final_Documentation.tex`

Tick tasks `[x]` as they finish. When every task is ticked, delete this file (git history keeps it).

**Rules:** this is the Final Documentation, not a Sprint 4 update. Anything still pending at finalization is **dismissed** (a limitation or Future Work, never "planned" or `\tbd`). After the freeze: doc work and bug fixes only. Keep 66 + 2 FRs / 32 NFRs (no renumbering).

---

## Done (Nov 14–15)
Doc updates for the game layer (§1), retitle and sweep of the document, the whole last UI pass (§3b: deck builder, shared components, own overlays and pages, tiles, blur, quiz panel, UI audit, hidden-card sync), exercise win/fail screens and the Ask AI output fix. Details are in git history (`git log --oneline dev`).

**UI is finished (Nov 15).** Last changes: Library tab, one HeroCard layout, Groups XP pill and rank tags, swipe and card-swap fixes. A palette change was tried (Material Color Utilities) and reverted; the palette stays as committed. From here: bug fixes only.

**Content moved to Supabase (Nov 15, `dcb92ba`).** `content_*` tables (public read, no client writes) are the source; the app downloads them at launch and on foreground (at most every 10 min), caches the last good copy, re-seeds by id, and falls back to the bundled JSON (offline first launch, demo mode, no keys, UI tests). New content needs no app update: add rows in Supabase. Supabase now has 192 questions, 25 exercises, 15 starter decks (174 cards); the bundle keeps 176 / 12 / 12.

## 2. Final tests (ES, Nov 17–19)
- [ ] System tests: ST-04 (offline then sync) and the ST-07 re-run (two Google accounts: sign-in → sync → group → leaderboard → sign-out) → §18e table + checklist item 7. (ST-03 partial run Nov 14.)
- [ ] Acceptance tests AT-01–07 by a non-author on a fresh install, including one Ask AI chat → §18f table + checklist item 8.
- [ ] Log any defect found in the defect table (ID, found by, fix commit, regression test).

## 3. Finalize the document (RB, by Nov 25)
- [ ] **Zero `\tbd{}`** (13 left: ES results from §2, plus the shortlog and final hash from §4). `grep -c '\\tbd{' docs/source/Final_Documentation.tex` must be 0.
- [ ] Status table "Software testing" → real state after §2; Gantt progress at submission.
- [ ] Document the content pipeline: the `content_*` tables in the database schema section (migration `20261116000000_content.sql`), Supabase as content source with the bundled fallback in the architecture/data sections, and the new content counts wherever the report says 176 questions / 12 exercises / 12 decks.
- [ ] **Retake screenshots** (wait for RB's OK): README (`docs/screenshots/`), report figure (`docs/source/figures/final-*.png`), and anywhere else they appear.

## 3c. Coding challenges (RB)
- [x] **More exercises**: 25 on Supabase (Swift 4, Python 3, OOP 4, Databases 4, Networking 3, OS Basics 3, Algorithms 2, Data Structures 2). Algorithms and Data Structures can get a third by adding rows to `content_exercises`.
- [x] **"Complete the code" quiz questions**: 16 on Supabase (2 per topic, medium and hard), with the snippet as a highlighted code block in the prompt. Options are plain text (no `format: code` flag); dismissed as a limitation.
- [x] **New starter decks**: HTTP & the Web, Design Patterns, Python Idioms (10 cards each), on Supabase.

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
