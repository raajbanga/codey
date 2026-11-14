# Codey — Final Documentation and Release Task List

**Sprint:** Nov 4 – Dec 1, 2026 · **Code freeze:** Sun Nov 22 · **Doc due / Expo:** Tue Dec 1
**Team:** Raaj Banga (RB, PM/docs) · Arnav Bawankule (AB, backend/systems) · Elnad Salcinovic (ES, UI/UX & QA)
**Sources of truth:** `docs/course/s4rubric.pdf`, `docs/course/ProjectDetails.docx`, `docs/source/Sprint4_Documentation.tex`

Tick tasks `[x]` as they finish. When every task is ticked, delete this file (git history keeps it).

---

## 0. Where we are (Nov 14)

**This is the Final Documentation, not a Sprint 4 update.** All 68 FRs are implemented (66 + Ask AI's FR-67/68). Full suite: **427 passed, 0 failed, 8 skipped** (unit + UI, iPhone 17 Simulator). CI is green. Anything still pending at finalization is **dismissed** (a limitation or Future Work, never "planned" or `\tbd`).

**Code done:** Ask AI (S39) and the UI refresh (S40). Both are pushed except the bento pass (below), which is waiting for an on-screen check.
- Ask AI: `Services/AskAI/`, `AskAISession`, `AskAIChatView`, answer-leak guard, 27 unit tests, 3 UI tests, chat in the a11y audit.
- S40 pass 1 (`e483aa4`): stronger dot grid, centered `FloatingPanel` (quiz setup, Ask AI), one pop motion for everything that floats, exercises folded into the Quiz tab (21 → 20 screens), play button on deck tiles (study 2 → 1 taps), study cards sized to their text.
- S40 pass 2 (uncommitted): bento grid (`BentoTile`/`BentoGrid`) on Home, Decks, Quiz and exercises; higher contrast (tile/paper 1.18:1, hairline 1.45:1, secondary text ≥ 7.2:1); 46 hand-drawn line icons (`scripts/icons/icons.py`); in-page titles (`PageHeader`) instead of large collapsing ones; Decks search as a toolbar button. Features 4,917 → 4,860 LOC.

**Measured:** NFR-01 on the iPhone 16 Pro Max: 178.0 ms mean, 193.7 ms p95 (met; `perf/sprint4-device-launch.csv`).

**Dismissed (Nov 14):** iPhone memory and file protection (NFR-28, TC-S10), Proxyman capture (TC-S09), scroll-fps metric, live RLS re-run (keep Nov 9: 0/57), Free-plan usage check (TC-N20), content proofreading, sign-in error wording, fresh-clone dry-run of Appendix A.

## 1. Non-goals

No new features, no Supabase schema changes, no code execution on device, no XP for exercises, no live test accounts or peer usability study. Ask AI stays basic: no history, streaming, accounts, or AI outside quizzes and exercises. Keep 66 + 2 FRs / 32 NFRs (no renumbering).

## 2. Decisions in force

S1 (tectonic, 12 pt, double-spaced) · S4 (dev → main squash at the end, then main back into dev) · S11 (perf: 10 runs, drop the 1st, mean + p95) · S13 (Appendix B after the freeze) · S15 (process claims describe what happened) · S16 (full + reading PDF) · S27 (AI-assisted code, every change reviewed) · S30–S34, S36–S38 as written in the doc.
- **S35** Code freeze **Sun Nov 22**. After it: doc work and bug fixes only.
- **S39** Ask AI: free OpenRouter model, explains and never answers, chat kept only for the problem on screen. Key ships in the app with a $0 credit limit (accepted risk; server proxy = Future Work).
- **S40** UI refresh: notebook paper, centered floating panels, bento tiles, own line icons, shared components, fewer taps.

## 3. Open tasks

### 3.0 Code (before the freeze)
- [ ] [RB] Check the bento pass on screen (Home, Decks, Quiz, exercises; Light and Dark), then commit + push it.
- [ ] [ES] UI tests on 3 sizes (iPhone 17e, 17, 17 Pro Max) with the refreshed screens; fix any layout issue found.

### 3.1 Doc updates for Ask AI and the UI refresh (RB, by Nov 25)
Already in the doc: FR-67/68, NFR-24 (3 hosts), UC-25, DFD + STRIDE rows, component and deployment diagrams, OpenRouter service row, risk R21, traceability rows, Future Work, the S40 UI paragraph (contrast, panels, bento, icons, LOC) and the "Changes" bullets.
- [ ] **Screenshots** (`fig:screens`): copy the `ScreenTourUITests` captures to `docs/source/screens/after/` and `docs/source/figures/`; rebuild the figure with Home (bento), Decks, the quiz-setup panel, a quiz question, the Ask AI chat, the Quizzes | Exercises switch, an exercise, and a study card; rewrite the caption.
- [ ] **Test results** (§18): re-run with `COVERAGE=1 CSV=docs/source/tests/unit.csv scripts/test.sh`; update `tab:unitresults` (388 → new count, suite counts, an "Ask AI" row), the coverage paragraph and the "compared with Sprint 3" sentence, and the metrics "Unit tests passing" row (line ~618).
- [ ] **Class diagram**: add the Ask AI types (`AskAIClient`, `OpenRouterClient`, `AskAISession`, `AskAIContext`, `AnswerLeakGuard`) to the "Sprint 4 additions" diagram, or add a small one.
- [ ] **Exercises flow wording**: the exercise list is no longer its own screen. Fix the coding-exercise use case main flow ("opens *Coding Exercises*" → the Exercises switch on the Quiz tab, ~line 1296) and ST-05 (~line 3497).
- [ ] **Screen counts**: "19 screens" in TC-N10, checklist item 6 and ST-06 → the real count after the 3-size pass (the audit now also walks the Ask AI chat).
- [ ] **Appendix A**: add `OPENROUTER_API_KEY` and `OPENROUTER_MODEL` to A.5 Secrets (key with a $0 credit limit; pick a model from the live `/models` list) and a troubleshooting line "Ask AI button missing → key empty".
- [ ] **Metrics UI rows** (~lines 619–621): layout-pass and audit counts after the 3-size pass.

### 3.2 Final tests (ES, Nov 17–19)
- [ ] System tests ST-03 (quiz → XP/streak/badge, Medium unlock), ST-04 (offline then sync), re-run ST-07 (sign-in → sync → group → leaderboard → sign-out) → §18e table + checklist item 7.
- [ ] Acceptance tests AT-01–07 by a non-author on a fresh install, including one Ask AI chat → §18f table + checklist item 8.
- [ ] Log any defect found in the defect table (ID, found by, fix commit, regression test).

### 3.3 Finalize the document (RB, by Nov 25)
- [ ] Retitle to "Final Documentation"; remove every "(Updated for Sprint 4)"; rewrite sprint-relative wording into present tense (keep sprint history only for process, Gantt, risks, version control).
- [ ] **Zero `\tbd{}`** (29 left): dismissed items → "Not verified" + one Future Work line; device rows → "Simulator only"; status row "On-device checks" → Dismissed. `grep -c '\\tbd{' docs/source/Sprint4_Documentation.tex` must be 0.
- [ ] Status table "Software testing" → real state after 3.2; Gantt (`fig:gantt4`): shade finished bars, mark the on-device bar dismissed.
- [ ] Sweep: hedges, repeated "as described in Section X", backstory in captions.
- [ ] Appendix A opening line (CI clean checkout, no manual dry-run); consider renaming to `Final_Documentation.tex` / `_reading.tex` (update README links).

### 3.4 Freeze and release (freeze Sun Nov 22; submit Tue Dec 1)
- [ ] [AB] After the freeze: `scripts/gen-file-table.py`, `scripts/gen-pattern-map.sh`, `scripts/gen-appendix-b.sh` (picks up the new Bento, Icon, FloatingPanel and Ask AI files).
- [ ] [AB] All tests green in CI on the final commit; all repository checks pass (incl. `check-release-build.sh`).
- [ ] [RB] Squash-merge `dev` → `main`, then merge `main` back into `dev`; `git shortlog -sn` → version-control table; Appendix B "from commit …" → final hash.
- [ ] [RB] Build both PDFs; check TOC, labels, axis labels; copy to `docs/`; README links the final report and Appendix A.
- [ ] [AB] Supabase project active for the Expo (keep-alive green); OpenRouter key still valid and under its 50 free requests/day on demo day.
- [ ] [ES] Rehearse the Expo demo: offline path, signed-in path, one Ask AI chat (fallback if the free model is down: show the stubbed UI test run).
- [ ] [RB] Submit the PDF by Tue Dec 1.

## 4. Schedule

| Week | Dates | Focus |
|---|---|---|
| 13 | Nov 15 – 22 | Bento check + commit, 3-size pass, system and acceptance tests (Nov 17–19); **code freeze Sun Nov 22** |
| 14 | Nov 23 – 29 | Doc updates (§3.1) and finalization (§3.3), generators, PDFs (Thanksgiving Wed–Fri) |
| 15 | Nov 30 – Dec 1 | Merge to main, shortlog, final PDFs, submit, Expo |
