# Codey — Final Documentation and Release Task List

**Code freeze:** Sun Nov 22 · **Doc due / Expo:** Tue Dec 1
**Team:** Raaj Banga (RB, PM/docs) · Arnav Bawankule (AB, backend/systems) · Elnad Salcinovic (ES, UI/UX & QA)
**Sources of truth:** `docs/course/s4rubric.pdf`, `docs/course/ProjectDetails.docx`, `docs/source/Sprint4_Documentation.tex`

Tick tasks `[x]` as they finish. When every task is ticked, delete this file (git history keeps it).

**Rules:** this is the Final Documentation, not a Sprint 4 update. Anything still pending at finalization is **dismissed** (a limitation or Future Work, never "planned" or `\tbd`). After the freeze: doc work and bug fixes only. Keep 66 + 2 FRs / 32 NFRs (no renumbering).

---

## 1. Doc updates for the game layer (RB, by Nov 25)
Already in the doc (uncommitted until the S41 commit): Ask AI class diagram, exercises flow wording (UC + ST-05), Appendix A OpenRouter secrets and troubleshooting, 21-screen counts, the new `fig:screens` layout and caption.
- [ ] **S41 game layer**: add the S41 decision (Play/Decks game tiles, quests, XP tags, Radix palette, shared `GameTile` / `CodeyChip` / `SessionTopBar` / `SessionSummary`); update FR-30 and O2; drop "no XP for exercises" from the non-goals and UC "no XP is awarded (S31)" (exercises now pay XP); schema V9 in the data model.
- [ ] **Screenshots** (`fig:screens`): the figure points at `final-*.png`, which don't exist yet. Capture them from `ScreenTourUITests` on the S41 UI (Play, Decks, quiz setup, quiz question, Ask AI, exercises, exercise, study) into `docs/source/figures/`; recheck the caption against the new screens.
- [ ] **Test results** (§18): re-run with `COVERAGE=1 CSV=docs/source/tests/unit.csv scripts/test.sh`; the doc says 416 / 57 suites, now 426 / 59 (adds `XPRewardsTests`). Update `tab:unitresults`, the coverage paragraph, checklist item 3, the summary sentence and the metrics row (~line 618).
- [ ] **Screen counts**: recheck "21 screens" (TC-N10, ST-06, checklist 6, metrics rows ~619–621) against the S41 screens.

## 2. Final tests (ES, Nov 17–19)
- [ ] System tests ST-03 (quiz → XP/streak/badge, Medium unlock), ST-04 (offline then sync), re-run ST-07 (sign-in → sync → group → leaderboard → sign-out) → §18e table + checklist item 7.
- [ ] Acceptance tests AT-01–07 by a non-author on a fresh install, including one Ask AI chat → §18f table + checklist item 8.
- [ ] Log any defect found in the defect table (ID, found by, fix commit, regression test).

## 3. Finalize the document (RB, by Nov 25)
- [ ] Retitle to "Final Documentation"; remove every "(Updated for Sprint 4)"; rewrite sprint-relative wording into present tense (keep sprint history only for process, Gantt, risks, version control).
- [ ] **Zero `\tbd{}`** (28 left): dismissed items → "Not verified" + one Future Work line; device rows → "Simulator only"; status row "On-device checks" → Dismissed. `grep -c '\\tbd{' docs/source/Sprint4_Documentation.tex` must be 0.
- [ ] Status table "Software testing" → real state after §2; Gantt (`fig:gantt4`): shade finished bars, mark the on-device bar dismissed.
- [ ] Sweep: hedges, repeated "as described in Section X", backstory in captions.
- [ ] Appendix A opening line (CI clean checkout, no manual dry-run); consider renaming to `Final_Documentation.tex` / `_reading.tex` (update README links).

## 4. Freeze and release (freeze Sun Nov 22; submit Tue Dec 1)
- [ ] [AB] After the freeze: `scripts/gen-file-table.py`, `scripts/gen-pattern-map.sh`, `scripts/gen-appendix-b.sh` (picks up the new Bento, GameTiles, Session, FloatingPanel and Ask AI files).
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
