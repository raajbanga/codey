#!/usr/bin/env bash
# S3-F: runs the performance suite (codey/Tests/Performance) on the
# Simulator and writes docs/perf/sprint3.csv (one row per scenario: mean,
# p95, stddev, peak memory, memory growth, threshold) plus docs/perf/environment.txt.
#
#   scripts/perf-report.sh [destination]
#   default destination: 'platform=iOS Simulator,name=iPhone 17'
#
# Release + testability for realistic timings (Debug is several times
# slower in SwiftData/SwiftUI). CODEY_PERF=1 turns the suite on; the PERF
# lines it prints are parsed from the test log.
set -euo pipefail
cd "$(dirname "$0")/.."

destination=${1:-'platform=iOS Simulator,name=iPhone 17'}
outdir=docs/perf
mkdir -p "$outdir"
log=$(mktemp)
trap 'rm -f "$log"' EXIT

{
    echo "date: $(date -u '+%Y-%m-%d %H:%M UTC')"
    echo "commit: $(git rev-parse --short HEAD)"
    echo "mac: $(sysctl -n machdep.cpu.brand_string), $(( $(sysctl -n hw.memsize) / 1073741824 )) GB RAM"
    echo "macOS: $(sw_vers -productVersion)"
    echo "xcode: $(xcodebuild -version | head -1)"
    echo "destination: $destination"
    echo "configuration: Release (ENABLE_TESTABILITY=YES)"
} > "$outdir/environment.txt"

TEST_RUNNER_CODEY_PERF=1 xcodebuild test \
    -workspace codey.xcworkspace -scheme codey -configuration Release \
    ENABLE_TESTABILITY=YES \
    -destination "$destination" \
    -only-testing:codeyTests/PerformanceTests 2>&1 | tee "$log" | grep -E 'PERF |Test .*(passed|failed)|error:' || true

{
    echo "name,runs,mean_ms,p95_ms,stddev_ms,peak_mb,growth_mb,threshold_ms"
    # Names use hyphens so LaTeX can typeset them.
    grep -o 'PERF name=.*' "$log" | sed -E 's/PERF //; s/[a-z_0-9]+=//g; s/ /,/g' | awk -F, -v OFS=, '{gsub(/_/, "-", $1)} 1' | sort -u
} > "$outdir/sprint3.csv"

echo "Wrote $outdir/sprint3.csv ($(($(wc -l < "$outdir/sprint3.csv") - 1)) scenarios) and $outdir/environment.txt"
grep -q '\*\* TEST SUCCEEDED \*\*' "$log" || { echo "Some performance tests failed (see thresholds above)"; exit 1; }
