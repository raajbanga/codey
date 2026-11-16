#!/usr/bin/env bash
# Runs the tests and prints a readable report: every test with ✓/✗ and its
# time, grouped by suite, then failures and totals (scripts/test-report.py).
# xcodebuild's own output goes to build/test.log; only errors are shown live.
# Used by CI (.github/workflows/test.yml) and locally.
#
#   scripts/test.sh                  # unit tests + accessibility audit
#   scripts/test.sh -only-testing:codeyTests/StudyQueueTests   # any xcodebuild filter
#   COVERAGE=1 scripts/test.sh       # also line coverage by Sources folder
#   CSV=docs/source/tests/unit.csv scripts/test.sh   # per-suite CSV for the doc
#   DESTINATION='platform=iOS Simulator,name=iPhone 17e' scripts/test.sh
#
# Needs a generated workspace (tuist install && tuist generate).
set -uo pipefail
cd "$(dirname "$0")/.."

destination=${DESTINATION:-'platform=iOS Simulator,name=iPhone 17'}
result=build/test.xcresult
log=build/test.log
mkdir -p build
rm -rf "$result"

filters=("$@")
if [[ ${#filters[@]} -eq 0 ]]; then
    filters=(-only-testing:codeyTests -only-testing:codeyUITests/AccessibilityAuditUITests)
fi
coverage_flag=()
[[ "${COVERAGE:-0}" == 1 ]] && coverage_flag=(-enableCodeCoverage YES)

echo "Testing on: $destination"
xcodebuild test \
    -workspace codey.xcworkspace -scheme codey \
    -destination "$destination" \
    -resultBundlePath "$result" \
    ${coverage_flag[@]+"${coverage_flag[@]}"} "${filters[@]}" > "$log" 2>&1
status=$?
grep -E '(error|fatal error):' "$log" | sort -u | head -40

if [[ ! -d "$result" ]]; then
    echo "No result bundle; the build failed (see $log)"; exit 1
fi
report_args=("$result")
[[ "${COVERAGE:-0}" == 1 ]] && report_args+=(--coverage)
[[ -n "${CSV:-}" ]] && report_args+=(--csv "$CSV")
python3 scripts/test-report.py "${report_args[@]}"
report=$?
exit $(( status != 0 ? status : report ))
