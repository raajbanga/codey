#!/usr/bin/env python3
"""Readable test report from an .xcresult bundle (rubric 18b evidence).

Prints every test case with its status and time, grouped by suite, then the
failures with their messages and a per-suite total. In GitHub Actions it also
writes the same report as Markdown to the job summary ($GITHUB_STEP_SUMMARY)
and emits ::error annotations for failures. With --csv it writes one row per
suite (bundle, suite, passed, failed, skipped, seconds) for the doc tables.

    scripts/test-report.py build/test.xcresult [--csv docs/source/tests/unit.csv]
                                               [--coverage]

Uses only `xcrun xcresulttool` / `xcrun xccov` (Xcode 16+), no extra tools.
"""
import argparse
import csv
import json
import os
import subprocess
import sys

MARK = {"Passed": "✓", "Failed": "✗", "Skipped": "–", "Expected Failure": "✓"}


def xcrun(*args):
    return json.loads(subprocess.run(["xcrun", *args], check=True, capture_output=True, text=True).stdout)


def walk(node, bundle=None, suite=None, out=None):
    """Collect (bundle, suite, case, result, seconds, failure messages)."""
    kind = node["nodeType"]
    if kind == "Unit test bundle" or kind == "UI test bundle":
        bundle = node["name"]
    elif kind == "Test Suite":
        suite = node["name"] if suite is None else f"{suite}/{node['name']}"
    elif kind == "Test Case":
        messages = [c["name"] for c in node.get("children", []) if c["nodeType"] == "Failure Message"]
        out.append((bundle, suite or "-", node["name"], node.get("result", "?"),
                    node.get("durationInSeconds", 0.0), messages))
        return out
    for child in node.get("children", []):
        walk(child, bundle, suite, out)
    return out


def coverage(path):
    """Line coverage of the app target, overall and by top-level Sources folder."""
    report = xcrun("xccov", "view", "--report", "--json", path)
    app = next((t for t in report["targets"] if t["name"] == "codey.app"), None)
    if app is None:
        return None, {}
    layers = {}
    for f in app["files"]:
        parts = f["path"].split("/codey/Sources/")
        layer = parts[1].split("/")[0] if len(parts) == 2 and "/" in parts[1] else "App"
        covered, total = layers.get(layer, (0, 0))
        layers[layer] = (covered + f["coveredLines"], total + f["executableLines"])
    return app["lineCoverage"], layers


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("xcresult")
    ap.add_argument("--csv")
    ap.add_argument("--coverage", action="store_true")
    args = ap.parse_args()

    data = xcrun("xcresulttool", "get", "test-results", "tests", "--path", args.xcresult)
    cases = []
    for node in data["testNodes"]:
        walk(node, out=cases)

    suites = {}
    for bundle, suite, _, result, secs, _ in cases:
        s = suites.setdefault((bundle, suite), {"Passed": 0, "Failed": 0, "Skipped": 0, "secs": 0.0})
        key = "Passed" if result in ("Passed", "Expected Failure") else result if result in s else "Failed"
        s[key] += 1
        s["secs"] += secs

    current = None
    for bundle, suite, name, result, secs, _ in cases:
        if (bundle, suite) != current:
            current = (bundle, suite)
            print(f"\n{bundle} › {suite}")
        print(f"  {MARK.get(result, '?')} {name}  ({secs:.2f}s)")

    failed = [c for c in cases if c[3] == "Failed"]
    passed = sum(1 for c in cases if c[3] in ("Passed", "Expected Failure"))
    skipped = sum(1 for c in cases if c[3] == "Skipped")
    print(f"\n{'=' * 60}\n{passed} passed, {len(failed)} failed, {skipped} skipped "
          f"({len(cases)} test cases in {len(suites)} suites)")
    for bundle, suite, name, _, _, messages in failed:
        print(f"\n✗ {suite}/{name}")
        for m in messages:
            print(f"    {m}")
        if os.environ.get("GITHUB_ACTIONS"):
            print(f"::error title={suite}/{name}::{' | '.join(messages) or 'failed'}")

    md = []
    md.append(f"### Tests: {passed} passed, {len(failed)} failed, {skipped} skipped\n")
    if failed:
        md.append("| Failed test | Message |\n|---|---|")
        md += [f"| `{s}/{n}` | {' '.join(m).replace('|', '/')} |" for _, s, n, _, _, m in failed]
        md.append("")
    md.append("| Bundle | Suite | Passed | Failed | Skipped | Time (s) |\n|---|---|---:|---:|---:|---:|")
    md += [f"| {b} | {s} | {v['Passed']} | {v['Failed']} | {v['Skipped']} | {v['secs']:.2f} |"
           for (b, s), v in sorted(suites.items())]

    if args.coverage:
        total, layers = coverage(args.xcresult)
        if total is not None:
            print(f"\nLine coverage (codey.app): {total * 100:.1f}%")
            md.append(f"\n**Line coverage (codey.app): {total * 100:.1f}%**\n\n| Sources folder | Coverage |\n|---|---:|")
            for layer, (cov, tot) in sorted(layers.items()):
                pct = 100 * cov / tot if tot else 0
                print(f"  {layer:<14} {pct:5.1f}%  ({cov}/{tot} lines)")
                md.append(f"| {layer} | {pct:.1f}% |")

    if args.csv:
        os.makedirs(os.path.dirname(args.csv) or ".", exist_ok=True)
        with open(args.csv, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["bundle", "suite", "passed", "failed", "skipped", "seconds"])
            for (b, s), v in sorted(suites.items()):
                w.writerow([b, s, v["Passed"], v["Failed"], v["Skipped"], f"{v['secs']:.2f}"])

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write("\n".join(md) + "\n")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
