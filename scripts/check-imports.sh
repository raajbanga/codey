#!/usr/bin/env bash
# R7 guardrail: only Services/Backend/Supabase/ may import Supabase or
# GoogleSignIn (and their sub-modules). Run from the repo root; exits 1 on a
# violation. Listed in .github/pull_request_template.md.
set -euo pipefail

cd "$(dirname "$0")/.."

pattern='^[[:space:]]*(@testable[[:space:]]+|@_exported[[:space:]]+)?import[[:space:]]+(struct[[:space:]]+|class[[:space:]]+|enum[[:space:]]+|protocol[[:space:]]+|func[[:space:]]+)?(Supabase|Auth|PostgREST|Realtime|Storage|Functions|GoogleSignIn|GoogleSignInSwift|GTMAppAuth|AppAuth)\b'

violations=$(grep -rEn "$pattern" codey/Sources --include='*.swift' | grep -v '^codey/Sources/Services/Backend/Supabase/' || true)

if [[ -n "$violations" ]]; then
    echo "Supabase/GoogleSignIn imported outside Services/Backend/Supabase/:"
    echo "$violations"
    exit 1
fi
echo "check-imports: OK"
