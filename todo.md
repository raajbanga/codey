# Codey — Sprint 4 PRD and Task List (Software Testing)

**Sprint:** Nov 4 – Dec 1, 2026 · **Doc due / Expo:** Tue Dec 1 (Sprint 4 Expo, Week 15)
**Team:** Raaj Banga (RB, PM/docs) · Arnav Bawankule (AB, backend/systems) · Elnad Salcinovic (ES, UI/UX & QA)
**Sources of truth:** `docs/course/s4rubric.pdf` (what the doc must contain), `docs/course/ProjectDetails.docx` (client mandates), `docs/source/Sprint3_Documentation.tex` (baseline doc)

Tick tasks `[x]` as they finish. When every task is ticked, delete this file (git history keeps it).

---

## 0. Where we are (Nov 14)

Built and tested: FR-61, BUG-01/02, FR-39–41 coding exercises, CI (app + pgTAP + checks on every push). 394 tests pass, 79.6 % coverage. The Sprint 4 doc (`docs/source/Sprint4_Documentation.tex`, + reading copy) covers rubric §§1–21, including new §18 Software Testing and §19 Conclusion. What's left is **results only people/hardware can produce**, then the freeze, regeneration, merge and submit. Every red `\tbd{}` in the doc maps to a task below (33 placeholders).

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

### 3.1 Needs the iPhone / Proxyman (by Fri Nov 20)
- [ ] [AB] NFR-01 / TC-P08: cold launch on the iPhone 16 Pro Max, 10 runs, drop the 1st, mean + p95 → metrics row, NFR-01 trace row, §17 launch bullet + bottlenecks paragraph.
- [ ] [AB] NFR-28 / TC-P03: peak footprint of the 100-card study session on the device → metrics row, NFR-28 trace row, §17 memory bullet.
- [ ] [AB] TC-S10 / NFR-04: store files' protection attribute on the device (expect *complete unless open*) → TC-S10 row.
- [ ] [ES] TC-S09 / NFR-24: Proxyman capture during sign-in, sync and a leaderboard load (only Supabase + Google, TLS 1.3) → TC-S09 row, NFR-24 trace row, checklist item 18.
- [ ] [ES] Could: scroll fps on the deck library (Instruments, Animation Hitches); else write "Not measured" in the metrics row.
- [ ] [RB] Then: status table row "On-device checks" and §18a checklist item 9.

### 3.2 Walkthroughs (Activities 13.1, 13.2)
- [ ] [ES] Nov 17, system tests: ST-03 (quiz → XP/streak/badge, Medium unlock), ST-04 (offline then sync), re-run ST-07 (sign-in → sync → group → leaderboard → sign-out) → §18e table + checklist item 7.
- [ ] [ES] Nov 19, acceptance AT-01–07 by a non-author on a fresh install → §18f table + checklist item 8.
- [ ] [ES] Layout pass: 3 sizes × Light/Dark incl. the 3 exercise screens → metrics row "Screens passing the layout pass".
- [ ] [RB] Status table: "Software testing" row says Done; change to the real state once the walkthroughs are in. Log any defect they find in the defect table (ID, found by, fix commit, regression test).

### 3.3 Doc polish (RB, by Nov 25)
- [ ] Sweep: hedges, "as described in Section X" repeats, sprint-by-sprint backstory in captions.
- [ ] Gantt (`fig:gantt4`): shade finished bars (5 are still `progress=0`: 13.1, 13.2, on-device, re-runs, generators).
- [ ] Could: TC-S01 live RLS check re-run (doc keeps Nov 9: 0/57 failed; script rolls back everything).
- [ ] Could: proofread starter decks and question bank.
- [ ] Could [AB]: "Codey's server isn't reachable" instead of "check your connection" for host-not-found sign-in errors.

### 3.4 Freeze and release (freeze Sun Nov 22; submit Tue Dec 1)
- [ ] [AB] Supabase Usage vs Free-plan limits (TC-N20) and a `scripts/backup.sh` dump before the Expo.
- [ ] [AB] After the freeze: `python3 scripts/gen-file-table.py`, `scripts/gen-pattern-map.sh`, `scripts/gen-appendix-b.sh`; fill the Appendix B commit/tag `\tbd`.
- [ ] [AB/ES] Fresh-clone dry-run of Appendix A (who, date) → `\tbd` at the top of Appendix A.
- [ ] [AB] All tests green in CI and on a clean checkout; all repository checks pass.
- [ ] [AB] Supabase project active before the Expo (keep-alive green; Security Advisor: 2 justified warnings only).
- [ ] [RB] Squash-merge `dev` → `main`, then merge `main` back into `dev` (S4); then `git shortlog -sn` on main → version-control table `\tbd`.
- [ ] [RB] Build both PDFs (tectonic); `grep -c '\\tbd{' docs/source/Sprint4_Documentation.tex` must be 0; check TOC, labels, axis labels; copy PDFs to `docs/`.
- [ ] [RB] README "Docs": link the Sprint 4 report; build guide → Appendix A of Sprint 4.
- [ ] [ES] Rehearse the Expo demo: offline path and signed-in path (Google OAuth test users only; consent screen says "Munnin").
- [ ] [RB] Submit the Sprint 4 PDF by Tue Dec 1.

## 4. Schedule

| Week | Dates | Focus |
|---|---|---|
| 13 | Nov 16 – 22 | Device + Proxyman checks; system tests (Nov 17); acceptance tests (Nov 19); **code freeze Sun Nov 22** |
| 14 | Nov 23 – 29 | Doc sweep, Gantt shading, generators, PDFs (Thanksgiving Wed–Fri) |
| 15 | Nov 30 – Dec 1 | Final checks, merge to main, shortlog, submit, Expo |
