"""H.17: the program/configuration files table for the Sprint 3 doc.

Lists every tracked source, test, resource, configuration, SQL, script and CI
file (git ls-files), grouped by folder, with a hand-written description per
group. Writes docs/source/generated/file_table.tex (a longtable). A tracked file
that matches no group stops the script, so the table can't silently miss a
file. Run with gen-appendix-b.sh after the code freeze:

    python3 scripts/gen-file-table.py [out]
"""
import fnmatch
import os
import subprocess
import sys

# (glob, type, description). First match wins; order matters.
GROUPS = [
    ("codey/Sources/CodeyApp.swift", "Source", "App entry point: appearance and navigation-title setup, then LoadingView."),
    ("codey/Sources/ContentView.swift", "Source", "Root after boot: tab UI, onboarding cover, sync nudge when the app becomes active."),
    ("codey/Sources/App/*", "Source", "Boot sequence (store, seeding, badge catch-up), configuration from Info.plist, appearance preference, launch arguments, loggers, launch timer (NFR-01)."),
    ("codey/Sources/Models/Schema/*", "Source", "Versioned SwiftData schemas V1--V9 and the migration plan; shipped versions are never edited."),
    ("codey/Sources/Models/Decks/*", "Source", "Deck and card models (FR-05--FR-08), code snippets, languages, ratings, deck origin."),
    ("codey/Sources/Models/Progress/*", "Source", "Local progress models: question and topic progress, quiz answers, daily activity, study snapshots, badge awards (V7)."),
    ("codey/Sources/Models/Sync/*", "Source", "Persisted sync-state kind and queued sync operations."),
    ("codey/Sources/Models/*", "Source", "Topics, questions and difficulty, user profile, avatar set (FR-04, FR-60)."),
    ("codey/Sources/ViewModels/*", "Source", "Observable view models for the deck builder, study sessions and quizzes, and the builder's draft types."),
    ("codey/Sources/Services/Practice/*", "Source", "Adaptive practice: quiz builder, tier gates, gating thresholds, progress store, seeded RNG, weekly plan, leaderboard ranking; coding-exercise loader and validator (FR-39--FR-41)."),
    ("codey/Sources/Services/Gamification/*", "Source", "XP for answers, study, exercises and quest bonuses, levels, streaks and daily goal, badges, weekly challenge and weekly XP (FR-30--FR-35, FR-42, FR-43)."),
    ("codey/Sources/Services/Study/*", "Source", "Study queue and study pool for flashcard sessions (FR-16--FR-18)."),
    ("codey/Sources/Services/Decks/*", "Source", "FlashcardFactory (Factory pattern), payloads, validator, starter-deck loader, stable IDs."),
    ("codey/Sources/Services/Sync/*", "Source", "Sync engine, queue, cursors, conflict resolver, progress sync (FR-61), and the deck State pattern."),
    ("codey/Sources/Services/AskAI/*", "Source", "Ask AI tutor: the only OpenRouter client, the system prompt, the chat session, and the answer-leak guard (FR-67, FR-68)."),
    ("codey/Sources/Services/Backend/Supabase/*", "Source", "The only folder that imports Supabase and GoogleSignIn: auth provider, data client, Keychain session storage, sign-in nonce, DEBUG stubbed-network test client."),
    ("codey/Sources/Services/Backend/*", "Source", "BackendFacade (Facade pattern) and its extensions, backend protocols, local store service, auth state, network monitor, group cache."),
    ("codey/Sources/Services/*", "Source", "Model container factory, question-bank loader, data seeder, local data reset."),
    ("codey/Sources/DesignSystem/Tokens/*", "Source", "Design tokens: colors, type, spacing, radius, motion, tier styles, syntax roles."),
    ("codey/Sources/DesignSystem/Components/*", "Source", "Shared UI components built only from tokens."),
    ("codey/Sources/DesignSystem/Markdown/*", "Source", "Card Markdown rendering (the only Textual import) and the Markdown editor."),
    ("codey/Sources/DesignSystem/CodeEditor/*", "Source", "Runestone code editor and its theme (the only Runestone imports)."),
    ("codey/Sources/DesignSystem/Gallery/*", "Source", "Component gallery previews (light, dark, large text)."),
    ("codey/Sources/Features/Home/*", "Source", "Play tab (the home dashboard): level, streak, quests, topic tiles with accuracy, and its pure logic (FR-36--FR-38, FR-53)."),
    ("codey/Sources/Features/Decks/Builder/*", "Source", "Deck builder: header, card pager, card editor, thumbnail strip (UC-01, UC-02)."),
    ("codey/Sources/Features/Decks/*", "Source", "Deck library, deck detail, tiles, sync status chip (FR-48)."),
    ("codey/Sources/Features/Study/*", "Source", "Study session screens: launcher, card, swipe rating, summary."),
    ("codey/Sources/Features/Quiz/*", "Source", "Quiz setup panel, quiz run, summary, topic stats; coding-exercise tiles and exercise screen (FR-39--FR-41)."),
    ("codey/Sources/Features/AskAI/*", "Source", "Ask AI chat panel and its button (FR-67)."),
    ("codey/Sources/Features/Profile/*", "Source", "Profile sheet, profile editor, badges row, defect report form."),
    ("codey/Sources/Features/Groups/*", "Source", "Groups list, create and join sheets, weekly leaderboard (FR-42, FR-50--FR-52)."),
    ("codey/Sources/Features/Onboarding/*", "Source", "Three-step first-launch onboarding."),
    ("codey/Sources/Navigation/*", "Source", "Tab root and the router that owns tabs, sheets and covers."),
    ("codey/Sources/Support/*", "Source", "Small generic helpers shared across features."),
    ("codey/Tests/Performance/*", "Test", "Performance suite TC-P01--TC-P07, the TC-P08 launch-store fixture, and the harness (opt-in, CODEY_PERF=1)."),
    ("codey/Tests/*", "Test", "Unit tests (Swift Testing) and shared fixtures and mocks."),
    ("codey/UITests/*", "Test", "XCTest UI tests: deck builder, study session, coding exercise, Ask AI (stubbed model), screen tour, accessibility audit."),
    ("codey/Resources/Schemas/*", "Resource", "JSON Schema for a flashcard (FR-09); its limits match ModelValidator and SQL."),
    ("codey/Resources/*.json", "Resource", "Bundled question bank (8 topics, 176 questions), starter decks (12 decks, 144 cards), and coding exercises (12)."),
    ("Config/*", "Config", "Shared build settings and the secrets template; the real Secrets.xcconfig is gitignored."),
    ("Project.swift", "Config", "Tuist project: targets, Info.plist keys, dependencies."),
    ("Tuist.swift", "Config", "Tuist workspace configuration."),
    ("Tuist/*", "Config", "Swift package dependencies (pinned exact) and their resolved versions."),
    (".gitignore", "Config", "Files kept out of Git (secrets, build output, backups)."),
    (".mcp.json", "Config", "Supabase MCP server for the project (used to run the live checks)."),
    ("supabase/migrations/*", "SQL", "Database schema as ordered migrations: tables, CHECKs, RLS policies, groups, RPC."),
    ("supabase/tests/*", "SQL", "pgTAP RLS and constraint tests (supabase test db)."),
    ("supabase/checks/*", "SQL", "The same checks for the live project (57 items, rolled back)."),
    ("supabase/config.toml", "Config", "Supabase CLI settings for the local stack used by the pgTAP tests (seeding off)."),
    ("supabase/.gitignore", "Config", "Keeps the Supabase CLI's local files out of Git."),
    ("scripts/palette/*", "Script", "Color palette, contrast checker, and asset-catalog generator (NFR-12)."),
    ("scripts/*", "Script", "Repository checks, test runner and readable report, backups, icon rendering, performance runs, and the document generators."),
    (".github/workflows/*", "CI", "GitHub Actions: tests and repository checks on every push (app, database, checks jobs); Supabase keep-alive every 3 days."),
    # Documentation the project uses: listed here, not reproduced in Appendix B.
    ("README.md", "Doc", "Repository overview, build summary, and the repository checks."),
    ("codey/DESIGN_SYSTEM.md", "Doc", "Design-system rules: tokens, components, and what check-design-tokens.sh enforces."),
    ("supabase/README.md", "Doc", "Supabase setup, migrations, RLS tests, operations, and the project's current state."),
    (".github/pull_request_template.md", "Doc", "Merge checklist with the security items (Activity 10.1, SSC item 1)."),
]
DOC_FILES = {g[0] for g in GROUPS if g[1] == "Doc"}
SKIP = ("docs/*", "todo.md", "*.md", "*.png", "*Assets.xcassets/*")


def tex(text):
    for a, b in (("\\", r"\textbackslash{}"), ("_", r"\_"), ("&", r"\&"), ("%", r"\%"), ("#", r"\#"), ("$", r"\$")):
        text = text.replace(a, b)
    return text


def main():
    root = os.path.join(os.path.dirname(__file__), "..")
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "docs/source/generated/file_table.tex")
    files = subprocess.run(["git", "-C", root, "ls-files"], capture_output=True, text=True, check=True).stdout.split("\n")
    rows = {g[0]: [] for g in GROUPS}
    for f in filter(None, files):
        if f not in DOC_FILES and any(fnmatch.fnmatch(f, s) for s in SKIP):
            continue
        group = next((g for g in GROUPS if fnmatch.fnmatch(f, g[0])), None)
        if group is None:
            sys.exit(f"gen-file-table: no group for {f}; add one to GROUPS")
        rows[group[0]].append(f)
    count = sum(len(v) for v in rows.values())
    docs = sum(len(rows[g]) for g in DOC_FILES)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w") as fh:
        fh.write("% Generated by scripts/gen-file-table.py. Do not edit.\n")
        fh.write("\\begin{longtable}{@{}p{0.4\\linewidth}p{0.08\\linewidth}p{0.46\\linewidth}@{}}\n")
        fh.write(f"\\caption{{Program, configuration, and documentation files ({count} files; all but the {docs} Doc files are listed in Appendix~B)}}\\label{{tab:files}}\\\\\n")
        head = "\\toprule \\textbf{Files} & \\textbf{Type} & \\textbf{Description} \\\\ \\midrule\n"
        fh.write(head + "\\endfirsthead\n" + head + "\\endhead\n")
        for glob, kind, desc in GROUPS:
            names = rows[glob]
            if not names:
                continue
            folder = os.path.dirname(names[0]) if "*" in glob else ""
            listed = ", ".join(os.path.basename(n) if folder and os.path.dirname(n) == folder else n for n in names)
            label = f"\\texttt{{{tex(folder)}/}}: " if folder else ""
            fh.write(f"{label}\\texttt{{{tex(listed)}}} & {kind} & {tex(desc)} \\\\\n")
        fh.write("\\bottomrule\n\\end{longtable}\n")
    print(f"gen-file-table: {count} files -> {out}")


if __name__ == "__main__":
    main()
