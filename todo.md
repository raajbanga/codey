# Codey — Sprint 4 PRD and Task List (Software Testing)

**Sprint:** Nov 4 – Dec 1, 2026 · **Doc due / Expo:** Tue Dec 1 (Sprint 4 Expo, Week 15)
**Team:** Raaj Banga (RB, PM/docs) · Arnav Bawankule (AB, backend/systems) · Elnad Salcinovic (ES, UI/UX & QA)
**Sources of truth:** `docs/course/s4rubric.pdf` (what the doc must contain), `docs/course/ProjectDetails.docx` (client mandates), `docs/source/Sprint3_Documentation.tex` (baseline doc)

Tick tasks `[x]` as they finish. When every task is ticked, delete this file (git history keeps it).

---

## 1. Carried over from Sprint 3 (decide/finish first)

Everything still open in the old `todo.txt` (as of `main`, Nov 5), with its Sprint 4 decision.

| Item | Decision | Where |
|---|---|---|
| FR-39–41 coding challenges (client mandate) | **Build, minimal** | §5.1 |
| FR-61 sync of study results (client mandate) | **Build** once Google sign-in works (BUG-01) | §5.0a, §5.1b |
| NFR-01 launch, NFR-28 memory on iPhone | **Keep**. LoadingView minimum and repeat seeding are already gone (3.82 s p95 on the Simulator) | §5.3 |
| TC-S10 file protection on device (NFR-04) | **Keep** | §5.3 |
| TC-S09 Proxyman capture (NFR-24) | **Keep** | §5.3 |
| Scroll fps on the deck library | **Keep** | §5.3 |
| Supabase test users → live NFR-02 test, TC-P09 leaderboard timing | **Dropped** (NFR-02 stays verified against the mock; NFR-32 retired) | §5.2 |
| Peer usability test → task success rate, tier tuning | **Dropped** (acceptance tests are team-run, §5.4) | §5.2 |
| R13 server-computed weekly XP ledger | **Dropped**: the Nov 2 pace limit (600 XP/min) stays the mitigation; R13 accepted → Future Work | §5.2 |
| CodeyCard audit, component restyles, Icon Composer `.icon` | **Dropped** (cosmetic) | — |
| RB content review of starter decks | **Could**: only if time allows | §5.5 |

Already done on `main` after the Sprint 3 doc, so **not** open: pgTAP database tests (`supabase test db`, 51 tests), CI test workflow (`.github/workflows/test.yml`), launch fixes (`BundledContentStamp`, no LoadingView minimum), weekly-XP rate limit migration.

---

## 2. Goal

Sprint 4 is about **testing and finishing what exists**, not adding features. The app already covers almost every client mandate. This sprint we:

1. Close the two open client mandates with the **smallest** versions that satisfy them: coding challenges (FR-39–41) and study-results sync (FR-61), after fixing the Google sign-in crash (BUG-01).
2. **Cut** planned work we will not finish and make the doc say so honestly.
3. **Plan, run and document** unit, integration, system, and V&V/acceptance tests (rubric §18).
4. Re-collect every metric and security check for the sprint-to-sprint comparison (NFR-17–19).
5. Produce the Sprint 4 document from the Sprint 3 one.

**Success =** every requirement in the doc is either *Implemented and tested* or explicitly *Dropped* with a reason; all tests pass; the doc covers rubric sections 1–21.

## 3. Non-goals (do not start these)

- New features beyond FR-39–41 and FR-61, new screens, or redesigns.
- Supabase schema changes beyond the FR-61 progress tables.
- Open-ended (run-the-code) coding problems, code execution on device.
- XP, badges, or progress tracking for coding exercises.
- Live Supabase test accounts, peer usability study, weekly-XP ledger, icon or styling passes.

## 4. Decisions (Sprint 4)

Still in force from Sprint 3: S1 (LaTeX → PDF via tectonic, 12 pt, double-spaced), S2/S24 (long doc is fine), S4 (dev → main squash merge at sprint end, then merge main back into dev), S11 (perf method: 10 runs, drop the 1st, mean + p95, state the environment), S13 (Appendix B after the freeze), S15 (process claims describe what actually happened), S16 (full PDF + reading PDF), S20 (no Linear; tasks tracked here), S22 (hardware), S27 (AI-assisted code, every change reviewed by a member), S29 (history rewrite of Nov 5; old clones reset to origin).

- **S30** Sprint 4 scope = finish and test. Only new code: FR-39–41 (minimal), FR-61, and the BUG-01 fix.
- **S31** FR-39–41 are code-completion exercises loaded from a bundled `exercises.json`. Not stored in SwiftData (no new schema version), not synced, no XP. Each blank is one "test case": the answer passes if it matches an accepted solution after whitespace normalization.
- **S32** (revised Nov 9) FR-61 is built after all: the schema addition is small once sign-in works. It reuses the deck sync design (tables with RLS, changes queued in `SyncQueue`, merge keeps the higher mastery score and the later retirement). It replaces D10 ("progress stays local") for mastery and quiz progress only.
- **S33** No live Supabase test accounts. NFR-02 stays verified against the mock backend (TC-P07, 0.41 s). NFR-32 (leaderboard ≤ 1.5 s live) is retired because it cannot be verified in scope.
- **S34** No peer usability test. The "task success rate" metric and tier tuning are removed. Acceptance tests are scripted walkthroughs of each client mandate, run by a member who did not build that feature (ES for most), and repeated as the Expo demo.
- **S35** Code freeze: **Sun Nov 22**. After the freeze only doc work and bug fixes; regenerate Appendix B, the pattern map and the file table after the freeze.
- **S36** Control-flow-graph test design (rubric 18c) uses `StudyQueue.record(_:)` from Activity 12.1 (`docs/course/Activity12_1.pdf`) plus one new method, `ExerciseValidator`'s check. Graphs are drawn in Mermaid (`.mmd` source kept with the figures).

## 5. Task list

Owners in brackets. Dates are targets.

### 5.0 Housekeeping (this week)

- [x] [RB] Merge `main` into `dev` (dev had stopped at the Sprint 3 squash; Nov 2–5 work was only on `main`).
- [ ] [RB] Ask the client (instructor) to approve retiring NFR-32 and the live test-account checks, and record the answer here and in the doc (Scope says any scope change needs client approval).

### 5.0a Bug tracking: Google sign-in crash (BUG-01, now)

Symptom: tapping the Google sign-in button crashes the app, so the signed-in flow (sync, groups, leaderboard) has never been tested by hand. Config looks right on paper: `GIDClientID`, `GIDServerClientID` and the reversed-client-ID URL scheme are in `Project.swift`, filled from `Config/Secrets.xcconfig`.

- [ ] [AB] Reproduce in the Simulator (Profile sheet and Onboarding buttons) and capture the crash log / exception message.
- [ ] [AB] Check the built `Info.plist` has the real values (not empty `$(...)` placeholders) for `GIDClientID` and `CFBundleURLSchemes`; GoogleSignIn throws an exception when the URL scheme is missing.
- [ ] [AB] Check the presenter: `UIApplication.topViewController` when the button sits inside the Profile *sheet*, and that sign-in runs on the main actor.
- [ ] [AB] Fix the root cause; add a regression test where possible (e.g. a test that the Info.plist scheme matches the reversed client ID).
- [ ] [ES] Verify by hand: sign in, sync a deck, create/join a group, open the leaderboard, sign out (keep and remove decks). Record the result as a system test (§5.4).
- [ ] [RB] Log BUG-01 in the doc's defect table (found by, cause, fix commit).

### 5.1b FR-61 Study-results sync (after BUG-01)

- [ ] [AB] Design: which local models sync (card mastery + retirement, `QuestionProgress`, tier unlocks), table shapes, merge rules (higher mastery, later retirement, sticky unlocks). Write it here before coding.
- [ ] [AB] Migration: progress tables with RLS (owner only), CHECK limits, `server_updated_at` trigger; pgTAP tests in `supabase/tests/`; apply via MCP; re-run the live RLS check and Security Advisor.
- [ ] [AB] Client: queue progress changes in `SyncQueue`, push/pull in `SyncEngine`, merge on pull; `SupabaseDataClient` calls behind the existing protocols.
- [ ] [AB] Unit tests: merge rules, queueing, offline then reconnect (mock backend); `SupabaseSchemaTests` for the new limits.
- [ ] [ES] Manual two-device check (two Simulators, same account): mastery and quiz progress converge.
- [ ] [RB] Doc: FR-61 → Implemented; FR-45 parenthetical removed; traceability + TC-61; R18 closed; D10 note updated; Supabase README tables list.
- [ ] [AB] Add `dev` to the CI `push` branches in `.github/workflows/test.yml`, so Sprint 4 work is tested before the merge to `main`.
- [ ] [AB] `scripts/perf-report.sh`: take the output name as an argument (default `sprint4.csv`) so the Sprint 3 results in `docs/source/perf/sprint3.csv` are kept.

### 5.1 FR-39–41 Coding challenges: minimal build (by Sun Nov 15)

- [ ] [AB] `codey/Resources/exercises.json`: 10–15 exercises across existing topics (Swift Basics, Python Basics, Algorithms, Data Structures first). Fields: id, topic, title, language, code with `___` blanks, `blanks[].accepted[]`, explanation.
- [ ] [AB] `ExerciseLoader` (decode + validate the JSON, like `QuestionBankLoader`) and a pure `ExerciseValidator` (normalize whitespace, compare each blank with its accepted answers, return pass/fail per blank).
- [ ] [ES] `ExerciseListView` + `ExerciseView`: entry point on the Quiz tab, code shown with the existing syntax highlighting, one monospaced text field per blank, Submit shows pass/fail per blank (FR-41) and the explanation. Design tokens only (`check-design-tokens.sh`).
- [ ] [AB] Unit tests: `ExerciseLoaderTests` (bundled file decodes, every blank has ≥ 1 accepted answer), `ExerciseValidatorTests` (one test per CFG basis path, see §5.4).
- [ ] [ES] Check the exercise screens on iPhone 17e / 17 / 18 Pro Max, Light and Dark (NFR-10/11); add them to `AccessibilityAuditUITests`.
- [ ] [RB] Doc: FR-39–41 → Implemented; scope + MoSCoW tables; R1 and R17 closed; traceability rows and the test-case map (TC-39–41).

### 5.2 Cut and tighten the doc to what we have (by Wed Nov 18)

- [ ] [RB] NFR-02 status "Met against the mock backend (0.41 s); not measured live"; remove "live test Sprint 4" and the Network Link Conditioner / test-account wording in Performance Test Cases.
- [ ] [RB] Retire NFR-32 / TC-P09 (S33): NFR table, performance requirements, performance test cases, traceability, metrics; note it in Changes Since Sprint 3.
- [ ] [RB] Remove the peer-usability metric row and "tier tuning after a peer test" (S34).
- [ ] [RB] R13 → "Accepted" with the 600 XP/min pace limit as mitigation; DFD threat P6 says the pace limit exists instead of "Sprint 4 hardening".
- [ ] [RB] Remove every other "Sprint 4" promise that is dropped; open-ended problems and the XP ledger → Future Work.
- [ ] [RB] Re-count FRs/NFRs and fix every count in the text (FR total, NFR total, security/performance counts, test count now 359+).
- [ ] [AB] `grep -n "Sprint 4\|Planned" docs/source/Sprint4_Documentation.tex` returns only things actually done in Sprint 4.

### 5.3 Measurements and re-runs (new measurements by Fri Nov 20; re-runs after the freeze)

New measurements:
- [ ] [AB] NFR-01: launch time on the iPhone 16 Pro Max, 10 runs, drop the 1st, mean + p95 (Xcode console `home-ready` log or `perf-launch.sh` adapted for device).
- [ ] [AB] NFR-28: peak memory of the 100-card study session on the device (TC-P03). Report the number as-is, met or not.
- [ ] [AB] TC-S10 / NFR-04: read the store files' protection attribute on the device (expect *complete unless open*).
- [ ] [ES] TC-S09 / NFR-24: Proxyman capture during sign-in, sync and a leaderboard load: only Supabase + Google hosts, TLS 1.3.
- [ ] [ES] Scroll fps on the deck library with Instruments (Animation Hitches); target ≥ 60 fps.

Re-runs for the Sprint 4 column (every sprint, NFR-17–19; after the freeze):
- [ ] [AB] `CODEY_PERF=1 scripts/perf-report.sh` → `sprint4.csv`; `scripts/perf-launch.sh` on the Simulator.
- [ ] [AB] Security: TC-S01 live RLS check (not re-run since the Nov 2 rate-limit migration), TC-S02 Security Advisor, TC-S03 `check-secrets.sh --history`, TC-S04 `xcodebuild analyze`, TC-S05 `check-release-build.sh`, TC-S11 `check-imports.sh`; `supabase test db` (51 pgTAP tests, needs Docker).
- [ ] [ES] UI: layout pass on 3 sizes × Light/Dark including the new exercise screens; `ContrastTests`; `AccessibilityAuditUITests`.
- [ ] [AB] Supabase Usage page vs Free-plan limits (TC-N20) and a `scripts/backup.sh` dump before the Expo.
- [ ] [RB] Every result goes in the metrics table (new Sprint 4 column), the security test table and the performance sections, with the environment stated (S11). Rewrite the "Simulator versus device" bottleneck paragraph with the device numbers.

### 5.4 Software Testing section: rubric §18 (plans by Nov 18, executed by the freeze Nov 22)

- [ ] [RB] **18a Testing checklist / test plan**: scope, levels (unit, integration, system, acceptance), environment (S22), entry/exit criteria (all pass, ≥ 70 % coverage NFR-16), roles, schedule, CI. Follow the IEEE 1008 phases from the Week 12 reading.
- [ ] [AB] **18b Unit tests**: run `xcodebuild test` with coverage; table of suites by layer → count, pass/fail, coverage for Model/ViewModel/Service. Reuse the test-case map (traceability section).
- [ ] [ES] **18c Flow-graph coverage**: Activity 12.1 (`StudyQueue.record`, V(G) = 4, 4 basis-path tests, all in `StudyQueueTests`) + `ExerciseValidator` CFG → basis paths → tests. Mermaid figures + node/edge/V(G) table.
- [ ] [AB] **18d Integration tests**: plan + results table for components tested together: SyncEngine + SyncQueue + ConflictResolver + mock backend; SwiftData store + `MigrationTests`; `DataSeeder` / `StarterDeckLoader` / `BundledContentStamp` + store; `SupabaseDataClient` with stubbed responses; database via pgTAP (`supabase test db`) and the live RLS check; schema limits (`SupabaseSchemaTests`). Activity 12.2 (Thu Nov 12) feeds this.
- [ ] [ES] **18e System tests**: end-to-end scripted cases on the Simulator (new user → onboarding → build deck → study → quiz → XP/streak/badge; offline create/study/quiz with Wi-Fi off; sign in → sync; groups/leaderboard; coding exercise). Include the 3 XCUITest suites. Record pass/fail per case. Activity 13.1 (Tue Nov 17) feeds this.
- [ ] [ES] **18f V&V and acceptance**: verification = traceability check (every remaining FR/NFR → test → result); validation/acceptance = one scripted acceptance test per client mandate (ProjectDetails list), run by a non-author (S34), results table. Activity 13.2 (Thu Nov 19) feeds this.
- [ ] [AB] Fix any defect found by these runs; log each defect (ID, found by which test, fix commit) in the doc.

### 5.5 Sprint 4 document (Nov 22 – Nov 30)

- [ ] [RB] Create `docs/source/Sprint4_Documentation.tex` (+ reading copy) from the Sprint 3 file; cover page "Sprint 4", date; every "(Updated for Sprint 3)" heading → Sprint 4.
- [ ] [RB] Changes Since Sprint 3 (what was built, cut, measured; the Nov 2–5 fixes: Swift 6, CI, rate limit, content stamp).
- [ ] [RB] Process section: Sprint 4 timeline row and task status; decision log S30–S36; `todo.md` replaces `todo.txt` wherever the doc names the project plan; CI in the workflow description.
- [ ] [RB] Sprint 4 Gantt chart (rubric 5d) from this task list's dates.
- [ ] [RB] Risks: close R1, R17, R18; R13 accepted; add BUG-01 lessons; add any new testing risks; update monitoring.
- [ ] [RB] UML updates only where the code changed: exercise use case + traceability; component diagram gets the exercise loader/validator; deployment/class diagrams get the FR-61 progress tables and sync path.
- [ ] [AB] Version control section: Sprint 4 commits/merges, the Nov 5 history rewrite (S29), the main → dev merge.
- [ ] [AB] After the freeze: `scripts/gen-file-table.py`, `scripts/gen-pattern-map.sh`, `scripts/gen-appendix-b.sh` (update their "Sprint 3 doc" headers); new files have header comments.
- [ ] [RB] New §19 Concluding Remarks / Future Work: what was delivered, lessons learned, Future Work = open-ended coding problems, server-side XP ledger (R13), peer usability study.
- [ ] [RB] Appendix A: add the exercises (nothing to configure) and the CI/pgTAP test commands.
- [ ] [RB] Build both PDFs (tectonic), check TOC page refs, figure/table labels, graph axis labels; copy to `docs/`.
- [ ] [RB] README "Docs" section: link the Sprint 4 report; "Full build guide → Appendix A of the Sprint 4 report".
- [ ] [RB] Could: proofread starter decks and question bank for wording errors.

### 5.6 Release (by Mon Nov 30)

- [ ] [AB] All tests green in CI and on a clean checkout; `check-imports.sh`, `check-design-tokens.sh`, `check-secrets.sh --history`, `check-release-build.sh` pass.
- [ ] [AB] Supabase project active before the Expo (keep-alive runs green; Security Advisor clean).
- [ ] [RB] Squash-merge `dev` → `main`, then merge `main` back into `dev` (S4).
- [ ] [ES] Rehearse the Expo demo on the Simulator: offline path and signed-in path (sign-in works only for the Google OAuth test users).
- [ ] [RB] Submit the Sprint 4 PDF by Tue Dec 1.

## 6. Schedule at a glance

| Week | Dates | Focus |
|---|---|---|
| 12 | Nov 9 – 15 | Housekeeping; BUG-01 sign-in crash; FR-61 design + migration; FR-39–41 build; Activity 12.1 (unit) ✔, 12.2 (integration) |
| 13 | Nov 16 – 22 | Doc cuts; device/Proxyman/fps measurements; test plans + runs; Activities 13.1, 13.2; **code freeze Sun Nov 22** |
| 14 | Nov 23 – 29 | Re-runs for the Sprint 4 column; doc writing, generators, Gantt, conclusion (Thanksgiving Wed–Fri) |
| 15 | Nov 30 – Dec 1 | Final checks, merge to main, submit, Expo |
