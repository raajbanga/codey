#!/usr/bin/env bash
# NFR-01 launch metric (TC-P08). The app logs
# "home-ready ms=<process start -> Home onAppear>" (LaunchTimer.swift) and
# this script relaunches it N times on a booted Simulator and reads the log.
#
#   PERF_TAG=sprint4 scripts/perf-launch.sh [runs]
#   default 10 runs (the first is discarded); writes docs/source/perf/<tag>-launch.csv
#   (default tag sprint4)
#
# First it runs the opt-in LaunchFixtureSeed test (Release, hosted in the
# app) on the booted Simulator: that installs the Release app, adds the
# Activity 9_2 store (starter decks + 5 user decks x 50 cards), and marks
# onboarding done. SKIP_SEED=1 skips this step. Each launch is a terminate +
# launch (dyld/file caches warm), not a reboot-cold launch; the doc says so.
# Cold launch is local-first and makes no network call before Home, so the
# LTE network profile doesn't change it.
set -euo pipefail
cd "$(dirname "$0")/.."

runs=${1:-10}
bundle=edu.wku.cs360.codey
out=docs/source/perf/${PERF_TAG:-sprint4}-launch.csv
mkdir -p "$(dirname "$out")"

xcrun simctl list devices booted | grep -q Booted || { echo "Boot a Simulator first"; exit 2; }

if [[ "${SKIP_SEED:-0}" != 1 ]]; then
    udid=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
    TEST_RUNNER_CODEY_PERF_SEED=1 xcodebuild test \
        -workspace codey.xcworkspace -scheme codey -configuration Release \
        ENABLE_TESTABILITY=YES -destination "id=$udid" \
        -only-testing:codeyTests/LaunchFixtureSeed >/dev/null 2>&1 \
        || { echo "Seeding the launch store failed"; exit 1; }
    echo "Launch store seeded (starter decks + 5 x 50-card user decks)"
fi

samples=()
for ((i = 1; i <= runs; i++)); do
    xcrun simctl terminate booted "$bundle" >/dev/null 2>&1 || true
    sleep 1
    since=$(date '+%Y-%m-%d %H:%M:%S')
    xcrun simctl launch booted "$bundle" >/dev/null
    ms=""
    for _ in {1..20}; do
        sleep 0.5
        ms=$(xcrun simctl spawn booted log show --style compact --start "$since" \
                --predicate "subsystem == \"$bundle\" AND category == \"Performance\"" 2>/dev/null \
             | sed -n 's/.*home-ready ms=\([0-9.]*\).*/\1/p' | tail -1)
        [[ -n "$ms" ]] && break
    done
    [[ -z "$ms" ]] && { echo "run $i: no home-ready line (is onboarding finished?)"; exit 1; }
    echo "run $i: $ms ms"
    samples+=("$ms")
done

printf '%s\n' "${samples[@]:1}" | sort -n | awk -v out="$out" -v runs="$runs" '
    { v[NR] = $1; sum += $1 }
    END {
        n = NR; mean = sum / n
        for (i = 1; i <= n; i++) ss += (v[i] - mean) ^ 2
        rank = int(0.95 * n); if (rank < 0.95 * n) rank++
        printf "name,runs,mean_ms,p95_ms,stddev_ms\nlaunch_home_ready,%d,%.1f,%.1f,%.1f\n", n, mean, v[rank], sqrt(ss / n) > out
        printf "launch (first of %d discarded): mean %.1f ms, p95 %.1f ms -> %s\n", runs, mean, v[rank], out
    }'
