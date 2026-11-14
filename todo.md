# Codey — Sprint 4 PRD and Task List (Software Testing)

**Sprint:** Nov 4 – Dec 1, 2026 · **Doc due / Expo:** Tue Dec 1 (Sprint 4 Expo, Week 15)
**Team:** Raaj Banga (RB, PM/docs) · Arnav Bawankule (AB, backend/systems) · Elnad Salcinovic (ES, UI/UX & QA)
**Sources of truth:** `docs/course/s4rubric.pdf` (what the doc must contain), `docs/course/ProjectDetails.docx` (client mandates), `docs/source/Sprint3_Documentation.tex` (baseline doc)

Tick tasks `[x]` as they finish. When every task is ticked, delete this file (git history keeps it).

---

## 0. Focus (audit of Nov 14)

Only three things decide the Sprint 4 grade. Everything else is updating text that already exists.

1. **FR-39–41 coding challenges.** Not started (no code, JSON or tests). Last unbuilt client mandate. → §5.1, due Sun Nov 15.
2. **Rubric §18 Software Testing (18a–f) and §19 Conclusion.** New sections; nothing written yet. The tests themselves mostly exist (≈375 unit tests, 3 UI suites, 75 pgTAP), so this is mainly writing up and running what we have. → §5.4.
3. **The Sprint 4 document.** Not created. Build it from the Sprint 3 file, debloat it (§5.2a), close every "Sprint 4 / Planned" promise (49 in the Sprint 3 file). → §5.2, §5.5.

### Rubric grade at audit (Sprint 3 doc + current code, graded as if submitted for Sprint 4)

| § | Item | At audit | Grade | To reach A |
|---|---|---|---|---|
| — | Format, labels, axis labels | Met | A | Re-check after rebuild |
| — | Length (≈ 6,000 words is a **minimum**) | ≈ 31,000 words (reading copy) | B | Debloat repetition, not explanations (§5.2a) |
| — | Cover page | Says Sprint 3 | B | Sprint 4 + date |
| 1 | Overview and scope | "Sprint 4 planned" | B | Update status; drop Sprint 1/2 history |
| 2 | Requirements (66 FR / 32 NFR) | 4 FRs planned | B | Close FR-39–41, FR-61; retire NFR-32 |
| 3 | Hardware | Device checks pending | B+ | iPhone numbers |
| 4 | Process | Through Sprint 3 | B | Sprint 4 row, S30–S38 |
| 5 | Gantt charts | Sprints 1–3 | C | Sprint 4 chart |
| 6 | Risks | R1, R17, R18 open | B | Close; BUG-01/02 lessons |
| 7 | Use case | No exercise use case | B | Add it |
| 8 | Traceability | 4 planned rows | B− | TC-39–41, TC-61 |
| 9 | Sequence | Done | A− | Progress-sync step |
| 10 | State | Done | A | Relabel |
| 11 | Class diagrams + patterns + map | Done | A | Regenerate after freeze |
| 12 | Component | No exercise parts | B | Loader/validator |
| 13 | Deployment | No progress tables | B | Add them |
| 14 | Version control | Through Sprint 3 | B | History rewrite, merges, CI on dev |
| 15 | File table | Stale | B | Regenerate |
| 16 | Security, DFD, test cases | TC-S09/S10 open | B+ | Proxyman, device check |
| 17 | Performance | No device numbers | B | Device + Sprint 4 column |
| 18a–f | Software testing | Missing | D/F | §5.4 |
| 19 | Conclusion / future work | Missing | F | §5.5 |
| 20 | Appendix A | Sprint 3 | B+ | Exercises + test commands |
| 21 | Appendix B | Generated | A− | Regenerate after freeze |
| — | Product: client mandates | All but FR-39–41 | C | §5.1 |
| | **Overall** | | **≈ C−** | **≈ A−** when §5.1, §5.4, §5.5 are done |

---

## 1. Carried over from Sprint 3

| Item | Decision | Where |
|---|---|---|
| FR-39–41 coding challenges (client mandate) | **Build, minimal** | §5.1 |
| FR-61 sync of study results (client mandate) | **Done** Nov 10, after BUG-01/02 | §5.0a, §5.0b |
| NFR-01 launch, NFR-28 memory on iPhone | **Keep** | §5.3 |
| TC-S10 file protection on device (NFR-04) | **Keep** | §5.3 |
| TC-S09 Proxyman capture (NFR-24) | **Keep** | §5.3 |
| Scroll fps on the deck library | **Could** (doc says "not measured" if skipped) | §5.3 |
| Live Supabase test accounts → live NFR-02 test, TC-P09 / NFR-32 | **Dropped**. NFR-02 verified against the mock; NFR-32 retired without client sign-off (team decision, Nov 14). Live-account test code deleted Nov 14 | §5.2 |
| Peer usability test → task success rate, tier tuning | **Dropped** (acceptance tests are team-run, §5.4) | §5.2 |
| R13 server-computed weekly XP ledger | **Dropped**: 600 XP/min pace limit stays; R13 accepted → Future Work | §5.2 |
| Move Google OAuth clients to a Codey project | **Dropped** (Nov 14): consent screen keeps saying "Munnin"; mention it in the demo script | — |
| CodeyCard audit, component restyles, Icon Composer `.icon` | **Dropped** (cosmetic) | — |
| RB content review of starter decks | **Could** | §5.5 |

Already done on `main` after the Sprint 3 doc: pgTAP tests (75 with FR-61), CI workflow, launch fixes (`BundledContentStamp`, no LoadingView minimum), weekly-XP rate limit migration.

---

## 2. Goal

Sprint 4 is about **testing and finishing what exists**, not adding features.

1. Close FR-39–41 with the **smallest** version that satisfies the client (FR-61 is done).
2. **Cut** what we will not finish and make the doc say so honestly.
3. **Plan, run and document** unit, integration, system, and V&V/acceptance tests (rubric §18).
4. Re-collect every metric and security check for the sprint-to-sprint comparison (NFR-17–19).
5. Produce a **debloated** Sprint 4 document from the Sprint 3 one.

**Success =** every requirement is either *Implemented and tested* or explicitly *Dropped* with a reason; all tests pass; the doc covers rubric sections 1–21.

## 3. Non-goals (do not start these)

- New features beyond FR-39–41, new screens, or redesigns.
- Supabase schema changes.
- Open-ended (run-the-code) coding problems, code execution on device.
- XP, badges, or progress tracking for coding exercises.
- Live Supabase test accounts, peer usability study, weekly-XP ledger, OAuth project move, icon or styling passes.
- Consolidating requirements toward 40 FR / 15 NFR (Nov 14: keep 66/32; renumbering ripples through every table and diagram).

## 4. Decisions (Sprint 4)

Still in force from Sprint 3: S1 (LaTeX → PDF via tectonic, 12 pt, double-spaced), S2/S24 (long doc is fine), S4 (dev → main squash merge at sprint end, then merge main back into dev), S11 (perf method: 10 runs, drop the 1st, mean + p95, state the environment), S13 (Appendix B after the freeze), S15 (process claims describe what actually happened), S16 (full PDF + reading PDF), S20 (no Linear; tasks tracked here), S22 (hardware), S27 (AI-assisted code, every change reviewed by a member), S29 (history rewrite of Nov 5; old clones reset to origin).

- **S30** Sprint 4 scope = finish and test. Only new code: FR-39–41 (minimal), FR-61, and the BUG-01 fix.
- **S31** FR-39–41 are code-completion exercises loaded from a bundled `exercises.json`. Not stored in SwiftData, not synced, no XP. Each blank is one "test case": passes if it matches an accepted solution after whitespace normalization.
- **S32** (revised Nov 9) FR-61 built: tables with RLS, a per-cycle progress step instead of `SyncQueue` entries, "latest review wins" (mastery can go down). Replaces D10 for mastery and quiz progress only.
- **S33** No live Supabase test accounts. NFR-02 verified against the mock backend (TC-P07, 0.41 s). NFR-32 (leaderboard ≤ 1.5 s live) retired: cannot be verified in scope. Team decision, no client sign-off sought (Nov 14). `SupabaseIntegrationTests` deleted; the stubbed-network helper is now `SupabaseTestClient`.
- **S34** No peer usability test. Acceptance tests are scripted walkthroughs of each client mandate, run by a non-author (ES for most), repeated as the Expo demo.
- **S35** Code freeze: **Sun Nov 22**. After the freeze only doc work and bug fixes; regenerate Appendix B, the pattern map and the file table after the freeze.
- **S36** Flow-graph test design (18c) uses `StudyQueue.record(_:)` (Activity 12.1) plus `ExerciseValidator`'s check. Graphs in Mermaid (`.mmd` kept with the figures).
- **S37** Integration test design (18d) uses Activity 12.2: SyncEngine → SupabaseDataClient progress sync (FR-61), **sandwich** strategy. Stubs: `MockRemoteStore`, `MockAuth`. Drivers: `SyncHarness` + `ProgressSyncTests`, `supabase/tests/progress.sql`, `rls_live_check.sql`. Interface fault: nil `retiredAt` dropped from the JSON (mitigated by explicit nulls); BUG-02 as the real example. Gap: no `SupabaseDataClientTests` case yet asserts `retired_at: null` for progress rows. CI: GitHub Actions for Swift tests (main + dev); pgTAP and live check by hand.
- **S38** (Nov 14) Debloat, don't shrink. 6,000 words is a floor, and the rubric rewards justification, so every rubric section keeps its explanations. Cut what is **not** asked for or **repeats** something said elsewhere (§5.2a). Perf scripts write per-sprint files (`PERF_TAG`, default `sprint4`) so Sprint 3 results stay.

## 5. Task list

Owners in brackets. Dates are targets.

### 5.0 Housekeeping

- [x] [RB] Merge `main` into `dev`.
- [x] [RB] ~~Ask the client to approve retiring NFR-32~~ → retired by team decision (S33); doc states the reason.
- [x] [AB] CI runs on pushes to `dev` (`.github/workflows/test.yml`).
- [x] [AB] `perf-report.sh` / `perf-launch.sh` take `PERF_TAG` (default `sprint4`) → `sprint4.csv`, `sprint4-environment.txt`, `sprint4-launch.csv`; Sprint 3 files untouched.
- [x] [AB] Supabase keep-alive (`.github/workflows/supabase-keepalive.yml`, every 3 days, green since Nov 7).
- [x] [AB] Delete live-account tests (`SupabaseIntegrationTests.swift`); `SupabaseTestAccounts` → `SupabaseTestClient` (stub-only); `check-release-build.sh` needle updated.
- [x] [AB] Readable test output: `scripts/test.sh` + `scripts/test-report.py` (✓/✗ per test by suite, failures, totals, coverage by folder, per-suite CSV for §18b, GitHub job summary + annotations). Nov 14 baseline: 364 passed, 0 failed, 8 skipped (opt-in perf); line coverage 74.9 %.
- [x] [AB] CI split into `checks` (imports, tokens, secrets --history), `database` (75 pgTAP on a local Supabase in Docker; `supabase/config.toml` now committed) and `app` (tests + coverage + `check-release-build.sh`).
- [ ] [AB] Could: "Codey's server isn't reachable" instead of "check your connection" for host-not-found sign-in errors.

### 5.0a Done: sign-in fixes and FR-61 (Nov 9–10, commit `1949cfe`)

Kept as the source for the doc (§5.0b).

- **BUG-01** "Sign in with Google" crashed (`unrecognized selector` on `OIDAuthorizationService`). Static linking dropped AppAuth's ObjC category. Fix: `-ObjC` in OTHER_LDFLAGS (`Project.swift`). Test: `GoogleSignInLinkTests`.
- **BUG-02** Signed in on Google's side but not in Codey. Cause 1: free Supabase project paused (host not found). Cause 2: GoogleSignIn 10 nonce not sent to Supabase. Fix: `SignInNonce`. Test: `SignInNonceTests`.
- **FR-61** Card mastery, `QuestionProgress`, `TopicProgress` sync per account (not: quiz history, daily activity, badges, paused sessions). Migration `20261110034534_study_progress.sql` (owner-only RLS, CHECKs mirror the app, merge triggers). Latest review wins; tier unlocks sticky. Progress step per sync cycle + sync on background. Known limits: Reset Progress not propagated; device clocks decide "latest". Tests: `ProgressSyncTests` (13), pgTAP `progress.sql` (24), live RLS 0/57 failed.

### 5.0b Document what's done (RB, by Wed Nov 18)

- [x] [RB] Defect table: BUG-01 and BUG-02 (found by, cause, fix, commit `1949cfe`, regression test). Risk lesson: free-tier projects pause after ~7 days idle.
- [x] [RB] FR-61 → Implemented; FR-45 parenthetical removed; traceability + TC-61; R18 closed; D10 note.
- [x] [RB] Decision log: S32 as built, S33, S38.
- [x] [RB] Database/deployment sections and diagrams: three progress tables, RLS, merge triggers; sync path gains the progress step.
- [x] [RB] Nov 10 hand checks as system tests in §18e (sign-in → sync → groups → leaderboard → sign-out; two Simulators converge).
- [x] [RB] FR-61 known limits in requirements notes or Future Work.

### 5.1 FR-39–41 Coding challenges: minimal build (by Sun Nov 15) — **top priority**

- [x] [AB] `codey/Resources/exercises.json`: 10–15 exercises (Swift Basics, Python Basics, Algorithms, Data Structures). Fields: id, topic, title, language, code with `___` blanks, `blanks[].accepted[]`, explanation.
- [x] [AB] `ExerciseLoader` (decode + validate, like `QuestionBankLoader`) and pure `ExerciseValidator` (normalize whitespace, compare each blank, pass/fail per blank).
- [x] [ES] `ExerciseListView` + `ExerciseView` on the Quiz tab: syntax-highlighted code, one monospaced field per blank, Submit shows pass/fail per blank + explanation. Design tokens only.
- [x] [AB] `ExerciseLoaderTests`, `ExerciseValidatorTests` (one test per CFG basis path, §5.4).
- [x] [ES] Exercise screens on iPhone 17e / 17 / 18 Pro Max, Light and Dark; add to `AccessibilityAuditUITests`.
- [x] [RB] Doc: FR-39–41 → Implemented; scope + MoSCoW; R1, R17 closed; traceability + TC-39–41.

### 5.2 Close promises in the doc (by Wed Nov 18)

- [x] [RB] NFR-02: "Met against the mock backend (0.41 s); not measured live". Remove Network Link Conditioner / test-account wording.
- [x] [RB] Retire NFR-32 / TC-P09 everywhere (NFR table, perf reqs, perf test cases, traceability, metrics); note in Changes Since Sprint 3.
- [x] [RB] Remove the peer-usability metric row and "tier tuning" (S34).
- [x] [RB] R13 → Accepted (600 XP/min pace limit); DFD threat P6 says the limit exists.
- [x] [RB] Every other dropped "Sprint 4" promise → removed or Future Work.
- [x] [RB] Re-count FRs/NFRs and every count in the text (tests now ≈ 375 unit + UI + 75 pgTAP).
- [x] [AB] `grep -n "Sprint 4\|Planned" docs/source/Sprint4_Documentation.tex` returns only things actually done in Sprint 4.

### 5.2a Debloat the doc (RB, while creating the Sprint 4 file; by Nov 25)

Rule (S38): keep every rubric section's explanations and justification; cut what the rubric doesn't ask for or what repeats another section. Expect the reading copy to land around 20–24k words, well over the 6,000 minimum. Rough savings in brackets.

**Cut**
- [x] UI/UX Design section (not in the Sprint 4 rubric) [≈ 2,000]. Keep 1 paragraph + the screenshot figure in §1 Overview; the design-token check moves to §18 (UI tests).
- [x] "Changes Since Sprint 1" and "Changes Since Sprint 2" [≈ 670]. Replace with one "Changes Since Sprint 3"; earlier history lives in the earlier docs.
- [x] §4 "Estimation", "Sprint Readiness and Demonstration" [≈ 220]. One sentence each folded into the process text.

**Condense (keep the point, drop the restatement)**
- [x] §4 "Sprint N Status of Critical Tasks", "Technical Debt", "Input Validation" → one status table + short paragraphs [≈ 300].
- [x] "Adaptive Practice Rationale" → one paragraph under Requirements [≈ 150].
- [x] Use case section (≈ 1,800 words): one-line description per use case in a table; keep full narrative only for the 2–3 core flows [≈ 600].
- [x] Traceability + requirements tables: remove "how" detail duplicated from the component/sequence sections; keep ID → design → test → result [≈ 500].  
  _Nov 14:_ checked; the matrix is already ID → use case → design → test → status (≈ 650 words for 66 rows). Nothing to cut.
- [x] Metrics plan narrative: the table says it; keep 2–3 sentences [≈ 300].
- [ ] Sweep: hedges, "as described in Section X" repeats, sprint-by-sprint backstory in captions.

**Do not cut:** performance justification (§17), security threat model and test cases (§16), pattern documentation (§11), Appendix A steps, any testing content (§18).

### 5.3 Measurements and re-runs (new by Fri Nov 20; re-runs after the freeze)

New measurements:
- [ ] [AB] NFR-01: launch time on the iPhone 16 Pro Max, 10 runs, drop the 1st, mean + p95.
- [ ] [AB] NFR-28: peak memory of the 100-card study session on the device (TC-P03). Report as-is.
- [ ] [AB] TC-S10 / NFR-04: store files' protection attribute on the device.
- [ ] [ES] TC-S09 / NFR-24: Proxyman capture during sign-in, sync and a leaderboard load.
- [ ] [ES] Could: scroll fps on the deck library (Instruments, Animation Hitches); else "not measured".

Re-runs for the Sprint 4 column (after the freeze):
- [x] [AB] `CODEY_PERF=1 scripts/perf-report.sh` → `sprint4.csv`; `scripts/perf-launch.sh` → `sprint4-launch.csv`.
- [ ] [AB] Security: TC-S01 live RLS check, TC-S02 Security Advisor, TC-S03 `check-secrets.sh --history`, TC-S04 `xcodebuild analyze`, TC-S05 `check-release-build.sh`, TC-S11 `check-imports.sh`; `supabase test db` (75 pgTAP, needs Docker/OrbStack).  
  _Nov 14:_ S03, S04 (0 in Codey's sources), S05, S11 and pgTAP 75/75 re-run (CI). Left: S01 live + S02 Advisor (need the live project; doc shows `\tbd`).
- [ ] [ES] UI: 3 sizes × Light/Dark incl. exercise screens; `ContrastTests`; `AccessibilityAuditUITests`.
- [ ] [AB] Supabase Usage vs Free-plan limits (TC-N20) and a `scripts/backup.sh` dump before the Expo.
- [ ] [RB] Results into the metrics table (Sprint 4 column), security table and performance sections, with environment (S11). Rewrite "Simulator versus device" bottleneck paragraph with device numbers.  
  _Nov 14:_ Simulator values in (perf sprint4.csv: launch 4.23 s p95 = 3.56 s pre-main + 0.62 s app; save 38.7 ms). Device values are `\tbd` in the doc.

### 5.4 Software Testing section: rubric §18 (plans by Nov 18, executed by the freeze Nov 22)

- [x] [RB] **18a Test plan / checklist**: scope, levels, environment (S22), entry/exit criteria (all pass, ≥ 70 % coverage NFR-16), roles, schedule, CI (main + dev). IEEE 1008 phases.
- [x] [AB] **18b Unit tests**: `xcodebuild test` with coverage; suites by layer → count, pass/fail, coverage for Model/ViewModel/Service.
- [x] [ES] **18c Flow-graph coverage**: `StudyQueue.record` (V(G) = 4, 4 basis-path tests in `StudyQueueTests`) + `ExerciseValidator` CFG → basis paths → tests. Mermaid figures + node/edge/V(G) table.
- [x] [AB] **18d Integration tests**: SyncEngine + SyncQueue + ConflictResolver + mock backend; SwiftData + `MigrationTests`; seeding/`BundledContentStamp` + store; `SupabaseDataClient` with stubbed responses; pgTAP + live RLS check; `SupabaseSchemaTests`. Bring in Activity 12.2 (S37). Add the missing `retired_at: null` assertion for progress rows.
- [ ] [ES] **18e System tests**: scripted end-to-end cases on the Simulator (onboarding → deck → study → quiz → XP/streak/badge; offline; sign in → sync; groups/leaderboard; coding exercise) + the 3 XCUITest suites. Pass/fail per case. Activity 13.1 feeds this.  
  _Nov 14:_ Written (§18e, ST-01–07). ST-01/02/05/06 automated and passing; ST-03, ST-04 and ST-07 re-run are `\tbd` for the Nov 17 walkthrough.
- [ ] [ES] **18f V&V and acceptance**: verification = traceability check; acceptance = one scripted test per client mandate, run by a non-author (S34). Activity 13.2 feeds this.  
  _Nov 14:_ Written (§18f, AT-01–07, one per mandate). Results `\tbd` for the Nov 19 run by a non-author.
- [x] [AB] Fix any defect found; log each (ID, found by, fix commit) in the doc.

### 5.5 Sprint 4 document (Nov 22 – Nov 30)

- [x] [RB] Create `docs/source/Sprint4_Documentation.tex` (+ reading copy) from Sprint 3; cover page "Sprint 4", date; every "(Updated for Sprint 3)" → Sprint 4. Apply §5.2a while doing this.
- [x] [RB] Changes Since Sprint 3 (built, cut, measured; Nov 2–5 fixes: Swift 6, CI, rate limit, content stamp).
- [x] [RB] Process section: Sprint 4 timeline row and status; decision log S30–S38; `todo.md` as the project plan; CI.
- [x] [RB] Sprint 4 Gantt chart (rubric 5d) from this list's dates.
- [x] [RB] Risks: close R1, R17, R18; R13 accepted; BUG-01/02 lessons; new testing risks; monitoring.
- [x] [RB] UML updates only where code changed: exercise use case; component diagram (exercise loader/validator); deployment/class diagrams (FR-61 tables, sync path).
- [x] [AB] Version control: Sprint 4 commits/merges, Nov 5 history rewrite (S29), main → dev merge, CI on dev.
- [ ] [AB] After the freeze: `gen-file-table.py`, `gen-pattern-map.sh`, `gen-appendix-b.sh` (update "Sprint 3 doc" headers); new files have header comments.  
  _Nov 14:_ Pre-freeze run done Nov 14 (doc compiles); re-run after the freeze.
- [x] [RB] New §19 Concluding Remarks / Future Work: delivered, lessons learned; Future Work = open-ended coding problems, server-side XP ledger (R13), peer usability study, live performance tests (NFR-32).
- [x] [RB] Appendix A: exercises (nothing to configure), CI/pgTAP test commands, `PERF_TAG`.
- [ ] [RB] Build both PDFs (tectonic); check TOC page refs, labels, axis labels; word count ≥ 6,000 (body); copy to `docs/`.
- [ ] [RB] README "Docs": link the Sprint 4 report; build guide → Appendix A of Sprint 4.
- [ ] [RB] Could: proofread starter decks and question bank.

### 5.6 Release (by Mon Nov 30)

- [ ] [AB] All tests green in CI and on a clean checkout; `check-imports.sh`, `check-design-tokens.sh`, `check-secrets.sh --history`, `check-release-build.sh` pass.
- [ ] [AB] Supabase project active before the Expo (keep-alive green; Security Advisor clean).
- [ ] [RB] Squash-merge `dev` → `main`, then merge `main` back into `dev` (S4).
- [ ] [ES] Rehearse the Expo demo: offline path and signed-in path (Google OAuth test users only; consent screen says "Munnin").
- [ ] [RB] Submit the Sprint 4 PDF by Tue Dec 1.

## 6. Schedule at a glance

| Week | Dates | Focus |
|---|---|---|
| 12 | Nov 9 – 15 | BUG-01/02 ✔; FR-61 ✔; housekeeping ✔ (Nov 14); **FR-39–41 build**; Activities 12.1 ✔, 12.2 ✔ |
| 13 | Nov 16 – 22 | Document FR-61; close promises; device/Proxyman measurements; test plans + runs; Activities 13.1, 13.2; **code freeze Sun Nov 22** |
| 14 | Nov 23 – 29 | Re-runs; Sprint 4 doc + debloat; generators, Gantt, conclusion (Thanksgiving Wed–Fri) |
| 15 | Nov 30 – Dec 1 | Final checks, merge to main, submit, Expo |
