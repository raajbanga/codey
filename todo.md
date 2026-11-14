# Codey — Sprint 4 PRD and Task List (Software Testing)

**Sprint:** Nov 4 – Dec 1, 2026 · **Doc due / Expo:** Tue Dec 1 (Sprint 4 Expo, Week 15)
**Team:** Raaj Banga (RB, PM/docs) · Arnav Bawankule (AB, backend/systems) · Elnad Salcinovic (ES, UI/UX & QA)
**Sources of truth:** `docs/course/s4rubric.pdf` (what the doc must contain), `docs/course/ProjectDetails.docx` (client mandates), `docs/source/Sprint3_Documentation.tex` (baseline doc)

Tick tasks `[x]` as they finish. When every task is ticked, delete this file (git history keeps it).

---

## 0. Where we are (Nov 14)

**This is the Final Documentation, not a Sprint 4 update.** The app is feature-complete for the requirements: all 66 FRs implemented, 394 tests pass, CI green. Anything still pending at finalization is **dismissed** (stated as a limitation / Future Work, never left as "planned" or `\tbd`). What remains: two late additions (Ask AI, UI refresh; §3.0, before the Nov 22 freeze), the final test walkthroughs, then finalizing the document and the release.

**Device observation (RB, Nov 14):** on the iPhone 16 Pro Max (128 GB) every loading step looks under 1 s. Not instrumented, so the doc may cite it only as an informal observation next to the Simulator numbers. Optional 10-minute measurement if wanted: run the app on the phone from Xcode (Release scheme), open Console.app on the Mac → select the iPhone → search `home-ready`; force-quit and relaunch 10 times and read the `home-ready ms=` lines (NFR-01). For NFR-28, watch Xcode's Debug navigator → Memory gauge while studying a 100-card deck and note the peak.

**Measured Nov 14:** NFR-01 on the iPhone 16 Pro Max: 178.0 ms mean, 193.7 ms p95 (met; in the doc, `perf/sprint4-device-launch.csv`).

**Dismissed at finalization (Nov 14):** iPhone memory and file protection (NFR-28, TC-S10), Proxyman capture (TC-S09), scroll-fps metric, live RLS re-run (keep Nov 9: 0/57), Free-plan usage check (TC-N20), content proofreading, sign-in error wording, fresh-clone dry-run of Appendix A (CI's clean checkout stands in).

## 1. Non-goals (do not start these)

- New features beyond FR-39–41 and the two late additions in §3.0 (Ask AI, UI refresh).
- Supabase schema changes.
- Open-ended (run-the-code) coding problems, code execution on device.
- XP, badges, or progress tracking for coding exercises.
- Live Supabase test accounts, peer usability study, weekly-XP ledger, OAuth project move, app icon. Ask AI: no chat history, no streaming, no accounts/billing, no AI outside quizzes and exercises.
- Consolidating requirements toward 40 FR / 15 NFR (Nov 14: keep 66/32; renumbering ripples through every table and diagram).

## 2. Decisions (Sprint 4)

Still in force from Sprint 3: S1 (LaTeX → PDF via tectonic, 12 pt, double-spaced), S2/S24 (long doc is fine), S4 (dev → main squash merge at sprint end, then merge main back into dev), S11 (perf method: 10 runs, drop the 1st, mean + p95, state the environment), S13 (Appendix B after the freeze), S15 (process claims describe what actually happened), S16 (full PDF + reading PDF), S20 (no Linear; tasks tracked here), S22 (hardware), S27 (AI-assisted code, every change reviewed by a member), S29 (history rewrite of Nov 5; old clones reset to origin).

- **S30** Sprint 4 scope = finish and test. Only new code: FR-39–41 (minimal), FR-61, and the BUG-01 fix.
- **S31** FR-39–41 are code-completion exercises loaded from a bundled `exercises.json`. Not stored in SwiftData, not synced, no XP. Each blank is one "test case": passes if it matches an accepted solution after whitespace normalization.
- **S32** (revised Nov 9) FR-61 built: tables with RLS, a per-cycle progress step instead of `SyncQueue` entries, "latest review wins" (mastery can go down). Replaces D10 for mastery and quiz progress only.
- **S33** No live Supabase test accounts. NFR-02 verified against the mock backend (TC-P07, 0.41 s). NFR-32 (leaderboard ≤ 1.5 s live) retired: cannot be verified in scope. Team decision, no client sign-off sought (Nov 14). `SupabaseIntegrationTests` deleted; the stubbed-network helper is now `SupabaseTestClient`.
- **S34** No peer usability test. Acceptance tests are scripted walkthroughs of each client mandate, run by a non-author (ES for most), repeated as the Expo demo.
- **S39** (Nov 14) **Ask AI** (late addition). A button only on a quiz question and a coding exercise opens a chat with a free OpenRouter model that *explains, never answers*. Ephemeral: one conversation per question/exercise, kept while it is on screen, reset on the next one; nothing stored or synced. Model ID is configuration (`OPENROUTER_MODEL`), not code: the free catalog rotates fast (Nov 3 test: 6 of 14 `:free` IDs answered; Poolside and Recursive Flint already gone), so pick from the live `/models` list at build time. Candidates: Cohere North Mini Code, Qwen3 Coder `:free`, NVIDIA Nemotron 3.5; fallback `openrouter/free` (random free model). Key: `OPENROUTER_API_KEY` in the gitignored `Secrets.xcconfig` (provided by RB), key created with a $0 credit limit so a leaked key can only use free models. Accepted risk: the key ships in the app binary (fine for a class demo; a Supabase Edge Function proxy is the production answer → Future Work). NFR-24 changes from 2 hosts to 3 (Supabase, Google, openrouter.ai).
- **S40** (Nov 14) **UI refresh** (late addition). More visible dotted paper; fewer screens/steps to reach study and quiz; quiz setup as a floating, swipe-to-dismiss card instead of a bottom sheet; more shared components so screens are thinner (target: fewer Features LOC than today's 4,917). Tokens and `check-design-tokens.sh` rules stay; use the `frontend-design` skill for direction. References: Apple's WWDC25 Liquid Glass sessions, the MIT SwiftKitUI components and the GlassKit starter (patterns only, no new dependencies).
- **S35** Code freeze: **Sun Nov 22** (§3.0 must land by then; if not, it is cut, not the freeze moved). After the freeze only doc work and bug fixes; regenerate Appendix B, the pattern map and the file table after the freeze.
- **S36** Flow-graph test design (18c) uses `StudyQueue.record(_:)` (Activity 12.1) plus `ExerciseValidator`'s check. Graphs drawn in TikZ in the doc (Fig. `fig:cfg`); the Mermaid version is in Activity 12.1.
- **S37** Integration test design (18d) uses Activity 12.2: SyncEngine → SupabaseDataClient progress sync (FR-61), **sandwich** strategy. Stubs: `MockRemoteStore`, `MockAuth`. Drivers: `SyncHarness` + `ProgressSyncTests`, `supabase/tests/progress.sql`, `rls_live_check.sql`. Interface fault: nil `retiredAt` dropped from the JSON (mitigated by explicit nulls); BUG-02 as the real example. The `retired_at: null` gap is closed (`progressRowsSendRetiredAtAsExplicitNull`, TD-01). CI: GitHub Actions for Swift tests (main + dev); pgTAP and live check by hand.
- **S38** (Nov 14) Debloat, don't shrink. 6,000 words is a floor, and the rubric rewards justification, so every rubric section keeps its explanations. Cut what is **not** asked for or **repeats** something said elsewhere (§5.2a). Perf scripts write per-sprint files (`PERF_TAG`, default `sprint4`) so Sprint 3 results stay.

## 3. Open tasks

### 3.0 Late additions (build Nov 15–21, before the freeze)

**Ask AI (S39)** — target ≈ 300 LOC + tests
_Built Nov 14: `Services/AskAI/` (client, prompt, `AnswerLeakGuard`: a reply naming the correct option or a hidden blank token gets one rewrite, then a fixed refusal), `ViewModels/AskAISession.swift`, `Features/AskAI/AskAIChatView.swift`, `AskAIButton`. Tests: `AskAITests` (27), `AskAIUITests` (3), chat added to the a11y audit. Live check on `cohere/north-mini-code:free`: greeting 1.3 s, "just tell me" refused; a rule "stop one step before the conclusion" was added after an explanation derived the answer. Full suite 417 passed._
- [x] [AB] `OpenRouterClient` (Services): one `POST https://openrouter.ai/api/v1/chat/completions`, non-streaming, URLSession, timeout + error mapping (offline, 401, 429 rate limit, model gone → friendly message). Key + model from Info.plist via `AppConfig` like the Supabase keys; button hidden when the key is empty (local-only builds and CI stay green). Add to `check-imports.sh`/`check-secrets.sh` patterns (`sk-or-`).
- [x] [AB] System prompt (a bundled `ask-ai-prompt.md` or a constant): tutor for a CS student; **never give the answer or the missing token**; explain the concept briefly in plain language; prefer bullets and sub-bullets, small ASCII/Markdown diagrams and short code fragments that aren't the solution; ask a guiding question; stay on the current problem. First user turn = the current question (prompt + options, or exercise prompt + code with blanks, language, topic), sent hidden; the model's first reply is a short "What do you need help with?".
- [x] [ES] `AskAIButton` (floating, design tokens) on `QuizQuestionView` and `ExerciseView` only; tapping opens `AskAIChatView` (sheet or the new floating panel from S40): message list rendered with `CardMarkdownView`, text field + send, typing indicator, error row with Retry. Matches existing UI; VoiceOver labels.
- [x] [AB] `AskAISession` (ViewModel): messages in memory, keyed to the question/exercise ID; new question or exercise → new session; leaving the quiz/exercise discards it. Never persisted, never synced.
- [x] [AB] Tests: request body (system prompt first, question context, model ID), session resets on a new question, error mapping, button hidden without a key (unit, stubbed `URLProtocol`); a11y audit of the chat screen; UI test with a stubbed client (`-UITestAskAIStub`).
- [ ] [RB] Doc: FR-67 Ask AI (Should, Team) + FR-68 ephemeral session; NFR-24 → 3 hosts; data-flow diagram + threat row (question text leaves the device; no personal data sent; prompt injection only affects the explanation); component + deployment diagrams (OpenRouter node); use case UC-25; traceability; §19 Future Work (Edge Function proxy, streaming).

**UI refresh (S40)** — use `frontend-design`; screenshot before/after
- [ ] [ES] Dotted paper: raise dot contrast/size in `PaperBackground` (Light + Dark), keep text contrast ≥ 4.5:1 (`ContrastTests`).
- [ ] [ES] Floating card panel component (`FloatingPanel`: rounded card over a dimmed background, spring in, drag/swipe to dismiss, VoiceOver escape) → use for quiz setup (replace the bottom sheet) and reuse for Ask AI and other small sheets.
- [ ] [ES] Simplify navigation: audit every screen and tap path (Home, Decks, Quiz, Profile, Groups); merge or remove screens that only route to another; fewer steps to start study/quiz/exercise. Write the before/after screen count.
- [ ] [ES/AB] Shared components: extract repeated row/header/card/section patterns (e.g. the icon + title + subtitle + chevron row used in Quiz topics, exercises, decks, groups) into DesignSystem; screens use them. Record Features LOC before (4,917) and after.
- [ ] [ES] Re-run: `AccessibilityAuditUITests` (Light/Dark), all UI tests on 3 sizes, `check-design-tokens.sh`; update UI tests whose identifiers or flows change.
- [ ] [RB] Doc: replace the screenshot figure (`fig:screens`) with new captures; update the UI paragraph, navigation mentions, use cases if a flow changed.

### 3.1 Final tests (ES, Nov 17–19)
- [ ] System tests: ST-03 (quiz → XP/streak/badge, Medium unlock), ST-04 (offline then sync), re-run ST-07 (sign-in → sync → group → leaderboard → sign-out) → §18e table + checklist item 7.
- [ ] Acceptance tests AT-01–07 by a non-author on a fresh install → §18f table + checklist item 8.
- [ ] Layout pass: 3 sizes × Light/Dark incl. the exercise screens, the Ask AI chat and the refreshed screens → metrics row.
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
| 12 | Nov 15 | Ask AI + UI refresh start (§3.0) |
| 13 | Nov 16 – 22 | Finish §3.0 by Nov 21; system tests (Nov 17, re-run Ask AI/UI parts after they land); acceptance tests (Nov 19); **code freeze Sun Nov 22** |
| 14 | Nov 23 – 29 | Doc finalization, generators, PDFs (Thanksgiving Wed–Fri) |
| 15 | Nov 30 – Dec 1 | Merge to main, shortlog, final PDFs, submit, Expo |
