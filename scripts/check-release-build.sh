#!/usr/bin/env bash
# SSC #12 / S3-G.1: a Release build must not contain the DEBUG-only test
# client (SupabaseTestClient) or other DEBUG tools. Builds Release for the Simulator, then searches the app binary's
# symbols and strings. Exits 1 on a hit.
#
#   scripts/check-release-build.sh            # build, then check
#   scripts/check-release-build.sh --no-build # check the last Release build
#
# Needs Xcode and a generated workspace (tuist install && tuist generate).
set -euo pipefail
cd "$(dirname "$0")/.."

derived=build/release-check
if [[ "${1:-}" != "--no-build" ]]; then
    xcodebuild build \
        -workspace codey.xcworkspace -scheme codey -configuration Release \
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath "$derived" -quiet
fi

binary="$derived/Build/Products/Release-iphonesimulator/codey.app/codey"
[[ -f "$binary" ]] || { echo "No Release binary at $binary (build first)"; exit 2; }

# Names that exist only inside #if DEBUG.
needles=(SupabaseTestClient "Replay Onboarding" ComponentGallery)
fail=0
for needle in "${needles[@]}"; do
    if nm "$binary" 2>/dev/null | grep -qF -- "$needle" || strings -a "$binary" | grep -qF -- "$needle"; then
        echo "Release binary contains: $needle"; fail=1
    fi
done

[[ $fail -eq 0 ]] && echo "check-release-build: OK (${needles[*]} absent)"
exit $fail
