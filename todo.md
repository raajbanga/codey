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

## 4. Schedule

| Week | Dates | Focus |
|---|---|---|
| 13 | Nov 15 – 22 | Billing, live RLS check, system and acceptance tests (Nov 17–19); **code freeze Sun Nov 22** |
| 14 | Nov 23 – 29 | Final test run, results into the report, PDFs (Thanksgiving Wed–Fri) |
| 15 | Nov 30 – Dec 1 | Merge to main, tag, shortlog, final PDFs, submit, Expo |
