#!/usr/bin/env bash
# R10 / metric "secrets in source = 0". Scans tracked files and (with --history)
# every commit for key-shaped strings, and for the real values in
# Config/Secrets.xcconfig if that file exists locally. Exits 1 on a hit.
# Never prints a matched secret, only where it was found.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
patterns='eyJ[A-Za-z0-9_-]{20,}|sb_secret_[A-Za-z0-9_-]{10,}|sb_publishable_[A-Za-z0-9_-]{10,}|[0-9]{6,}-[a-z0-9]{20,}\.apps\.googleusercontent\.com|GOCSPX-[A-Za-z0-9_-]{10,}|sk-or-v1-[A-Fa-f0-9]{20,}'

if git ls-files --error-unmatch Config/Secrets.xcconfig >/dev/null 2>&1; then
    echo "Config/Secrets.xcconfig is tracked"; fail=1
fi

hits=$(git grep -lE "$patterns" -- . ':!scripts/check-secrets.sh' || true)
if [[ -n "$hits" ]]; then echo "Key-shaped strings in tracked files:"; echo "$hits"; fail=1; fi

# The real values, if this machine has them.
if [[ -f Config/Secrets.xcconfig ]]; then
    while IFS= read -r value; do
        [[ ${#value} -lt 12 ]] && continue
        files=$(git grep -lF -- "$value" || true)
        if [[ -n "$files" ]]; then echo "A value from Secrets.xcconfig appears in:"; echo "$files"; fail=1; fi
        if [[ "${1:-}" == "--history" ]] && git log --all -p | grep -qF -- "$value"; then
            echo "A value from Secrets.xcconfig appears in git history"; fail=1
        fi
    # OPENROUTER_MODEL is a public model ID, not a secret.
    done < <(grep -E '^[A-Z_]+ *=' Config/Secrets.xcconfig | grep -v '^OPENROUTER_MODEL' | sed 's/^[^=]*= *//; s#/\$()/#//#')
fi

if [[ "${1:-}" == "--history" ]] && git log --all -p | grep -qE "$patterns"; then
    echo "Key-shaped strings in git history (run: git log --all -p | grep -nE '<pattern>')"; fail=1
fi

[[ $fail -eq 0 ]] && echo "check-secrets: OK"
exit $fail
