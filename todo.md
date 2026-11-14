# Codey — Sprint 4 PRD and Task List (Software Testing)

**Sprint:** Nov 4 – Dec 1, 2026 · **Doc due / Expo:** Tue Dec 1 (Sprint 4 Expo, Week 15)
**Team:** Raaj Banga (RB, PM/docs) · Arnav Bawankule (AB, backend/systems) · Elnad Salcinovic (ES, UI/UX & QA)
**Sources of truth:** `docs/course/s4rubric.pdf` (what the doc must contain), `docs/course/ProjectDetails.docx` (client mandates), `docs/source/Sprint3_Documentation.tex` (baseline doc)

Tick tasks `[x]` as they finish. When every task is ticked, delete this file (git history keeps it).

---

## 0. Where we are (Nov 14)

**This is the Final Documentation, not a Sprint 4 update.** The app is feature-complete: all 66 FRs implemented, 394 tests pass, CI green. Anything still pending at finalization is **dismissed** (stated as a limitation / Future Work, never left as "planned" or `\tbd`). What remains: the final test walkthroughs, then finalizing the document and the release.

**Device observation (RB, Nov 14):** on the iPhone 16 Pro Max (128 GB) every loading step looks under 1 s. Not instrumented, so the doc may cite it only as an informal observation next to the Simulator numbers. Optional 10-minute measurement if wanted: run the app on the phone from Xcode (Release scheme), open Console.app on the Mac → select the iPhone → search `home-ready`; force-quit and relaunch 10 times and read the `home-ready ms=` lines (NFR-01). For NFR-28, watch Xcode's Debug navigator → Memory gauge while studying a 100-card deck and note the peak.

**Measured Nov 14:** NFR-01 on the iPhone 16 Pro Max: 178.0 ms mean, 193.7 ms p95 (met; in the doc, `perf/sprint4-device-launch.csv`).

**Dismissed at finalization (Nov 14):** iPhone memory and file protection (NFR-28, TC-S10), Proxyman capture (TC-S09), scroll-fps metric, live RLS re-run (keep Nov 9: 0/57), Free-plan usage check (TC-N20), content proofreading, sign-in error wording, fresh-clone dry-run of Appendix A (CI's clean checkout stands in).

## 1. Non-goals (do not start these)

- New features beyond FR-39–41, new screens, or redesigns.
- Supabase schema changes.
- Open-ended (run-the-code) coding problems, code execution on device.
- XP, badges, or progress tracking for coding exercises.
- Live Supabase test accounts, peer usability study, weekly-XP ledger, OAuth project move, icon or styling passes.
- Consolidating requirements toward 40 FR / 15 NFR (Nov 14: keep 66/32; renumbering ripples through every table and diagram).

## 2. Decisions (Sprint 4)

Still in force from Sprint 3: S1 (LaTeX → PDF via tectonic, 12 pt, double-spaced), S2/S24 (long doc is fine), S4 (dev → main squash merge at sprint end, then merge main back into dev), S11 (perf method: 10 runs, drop the 1st, mean + p95, state the environment), S13 (Appendix B after the freeze), S15 (process claims describe what actually happened), S16 (full PDF + reading PDF), S20 (no Linear; tasks tracked here), S22 (hardware), S27 (AI-assisted code, every change reviewed by a member), S29 (history rewrite of Nov 5; old clones reset to origin).

- **S30** Sprint 4 scope = finish and test. Only new code: FR-39–41 (minimal), FR-61, and the BUG-01 fix.
- **S31** FR-39–41 are code-completion exercises loaded from a bundled `exercises.json`. Not stored in SwiftData, not synced, no XP. Each blank is one "test case": passes if it matches an accepted solution after whitespace normalization.
- **S32** (revised Nov 9) FR-61 built: tables with RLS, a per-cycle progress step instead of `SyncQueue` entries, "latest review wins" (mastery can go down). Replaces D10 for mastery and quiz progress only.
- **S33** No live Supabase test accounts. NFR-02 verified against the mock backend (TC-P07, 0.41 s). NFR-32 (leaderboard ≤ 1.5 s live) retired: cannot be verified in scope. Team decision, no client sign-off sought (Nov 14). `SupabaseIntegrationTests` deleted; the stubbed-network helper is now `SupabaseTestClient`.
- **S34** No peer usability test. Acceptance tests are scripted walkthroughs of each client mandate, run by a non-author (ES for most), repeated as the Expo demo.
- **S35** Code freeze: **Sun Nov 22**. After the freeze only doc work and bug fixes; regenerate Appendix B, the pattern map and the file table after the freeze.
- **S36** Flow-graph test design (18c) uses `StudyQueue.record(_:)` (Activity 12.1) plus `ExerciseValidator`'s check. Graphs drawn in TikZ in the doc (Fig. `fig:cfg`); the Mermaid version is in Activity 12.1.
- **S37** Integration test design (18d) uses Activity 12.2: SyncEngine → SupabaseDataClient progress sync (FR-61), **sandwich** strategy. Stubs: `MockRemoteStore`, `MockAuth`. Drivers: `SyncHarness` + `ProgressSyncTests`, `supabase/tests/progress.sql`, `rls_live_check.sql`. Interface fault: nil `retiredAt` dropped from the JSON (mitigated by explicit nulls); BUG-02 as the real example. The `retired_at: null` gap is closed (`progressRowsSendRetiredAtAsExplicitNull`, TD-01). CI: GitHub Actions for Swift tests (main + dev); pgTAP and live check by hand.
- **S38** (Nov 14) Debloat, don't shrink. 6,000 words is a floor, and the rubric rewards justification, so every rubric section keeps its explanations. Cut what is **not** asked for or **repeats** something said elsewhere (§5.2a). Perf scripts write per-sprint files (`PERF_TAG`, default `sprint4`) so Sprint 3 results stay.

## 3. Open tasks

### 3.1 Final tests (ES, Nov 17–19)
- [ ] System tests: ST-03 (quiz → XP/streak/badge, Medium unlock), ST-04 (offline then sync), re-run ST-07 (sign-in → sync → group → leaderboard → sign-out) → §18e table + checklist item 7.
- [ ] Acceptance tests AT-01–07 by a non-author on a fresh install → §18f table + checklist item 8.
- [ ] Layout pass: 3 sizes × Light/Dark incl. the 3 exercise screens → metrics row.
- [ ] Log any defect found in the defect table (ID, found by, fix commit, regression test).

### 3.2 Finalize the document (RB, by Nov 25)
- [ ] **Final, industry-standard document.** Retitle the cover "Final Documentation"; remove every "(Updated for Sprint 4)" / "updated for Sprint 4" from headings and captions; rewrite sprint-relative wording ("in Sprint 4", "new in Sprint 4", "Changes Since Sprint 3", "the Sprint 3 doc") into a neutral, present-tense description of the delivered system. Keep sprint history only where the rubric asks for it (process, Gantt charts, risks monitoring, version control).
- [ ] **Zero `\tbd{}`.** Dismissed items → "Not verified" + one line in §19 Future Work (device NFR-01/NFR-28/TC-S10, TC-S09, scroll fps); metrics "Sprint 4" values for device rows → "Simulator only"; status-table row "On-device checks" → Dismissed; checklist item 9 → Simulator only. `grep -c '\\tbd{' docs/source/Sprint4_Documentation.tex` must be 0.
- [ ] Status table: "Software testing" → real state after 3.1.
- [ ] Gantt (`fig:gantt4`): shade finished bars; mark the on-device bar as dismissed.
- [ ] Sweep: hedges, "as described in Section X" repeats, backstory in captions.
- [ ] Small patches: Appendix A opening line (CI clean checkout, no manual dry-run); Appendix B "from commit …" → final commit hash; consider renaming the files to `Final_Documentation.tex` / `_reading.tex` (update README links).

### 3.3 Freeze and release (freeze Sun Nov 22; submit Tue Dec 1)
- [ ] [AB] After the freeze: `python3 scripts/gen-file-table.py`, `scripts/gen-pattern-map.sh`, `scripts/gen-appendix-b.sh`.
- [ ] [AB] All tests green in CI on the final commit; all repository checks pass.
- [ ] [RB] Squash-merge `dev` → `main`, then merge `main` back into `dev` (S4).
- [ ] [RB] `git shortlog -sn` on main → version-control table (replaces its `\tbd`).
- [ ] [RB] Build both PDFs (tectonic); check TOC, labels, axis labels; copy PDFs to `docs/`; README "Docs" links the final report and Appendix A.
- [ ] [AB] Supabase project active for the Expo (keep-alive green).
- [ ] [ES] Rehearse the Expo demo: offline path and signed-in path (Google OAuth test users only; consent screen says "Munnin").
- [ ] [RB] Submit the PDF by Tue Dec 1.

## 4. Schedule

| Week | Dates | Focus |
|---|---|---|
| 13 | Nov 16 – 22 | System tests (Nov 17); acceptance tests (Nov 19); doc finalization starts; **code freeze Sun Nov 22** |
| 14 | Nov 23 – 29 | Doc finalization, generators, PDFs (Thanksgiving Wed–Fri) |
| 15 | Nov 30 – Dec 1 | Merge to main, shortlog, final PDFs, submit, Expo |
