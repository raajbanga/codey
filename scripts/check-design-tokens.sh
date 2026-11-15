#!/usr/bin/env bash
# Design-system guardrails (Stage 2 "Done when"; D19; R12). Run from anywhere:
#   scripts/check-design-tokens.sh
# Exits non-zero and prints offending lines if any rule is broken.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
SRC=codey/Sources
fail=0

check() { # description, grep pattern, paths...
  local desc=$1 pattern=$2; shift 2
  local hits
  hits=$(grep -rnE "$pattern" "$@" 2>/dev/null | grep -v '^\s*//' || true)
  if [[ -n "$hits" ]]; then
    echo "✗ $desc"; echo "$hits" | sed 's/^/    /'; fail=1
  else
    echo "✓ $desc"
  fi
}

# Screens use tokens: no raw colors, radii, fonts, or UIKit haptics.
SCREENS=("$SRC/Features" "$SRC/App" "$SRC/Navigation")
check "no raw Color(...) / hex in screens" 'Color\(|#[0-9A-Fa-f]{6}|Color\.(red|blue|green|orange|yellow|purple|pink|gray|white|black)\b|\.foregroundStyle\(\.(white|black)\)' "${SCREENS[@]}"
check "no literal corner radii in screens" 'cornerRadius: *[0-9]|\.cornerRadius\(' "${SCREENS[@]}"
check "no raw system fonts in screens" '\.font\(\.(largeTitle|title|title2|title3|headline|body|callout|subheadline|footnote|caption|caption2)\b|\.system\(size' "${SCREENS[@]}"
check "haptics via .sensoryFeedback, not UIKit generators" 'UI(Impact|Notification|Selection)FeedbackGenerator' "$SRC"

# Capsule only for bars (§3b, Nov 15): progress bars and the onboarding
# step dots. Every pill-shaped control uses the shared `.pill` shape.
hits=$(grep -rnE 'Capsule\(\)' "$SRC" \
    | grep -vE "DesignSystem/Components/ProgressBar\.swift|Features/Onboarding/OnboardingView\.swift" || true)
if [[ -n "$hits" ]]; then echo "✗ Capsule() outside approved single-line components"; echo "$hits" | sed 's/^/    /'; fail=1
else echo "✓ Capsule() only in approved single-line components"; fi

# Third-party UI libraries stay behind one wrapper each (R12).
hits=$(grep -rlnE '^import Textual' "$SRC" | grep -v "DesignSystem/Markdown/CardMarkdownView.swift" || true)
if [[ -n "$hits" ]]; then echo "✗ Textual imported outside CardMarkdownView"; echo "$hits" | sed 's/^/    /'; fail=1
else echo "✓ Textual only in CardMarkdownView"; fi
hits=$(grep -rlnE '^import (Runestone|TreeSitter)' "$SRC" | grep -v "DesignSystem/CodeEditor/" || true)
if [[ -n "$hits" ]]; then echo "✗ Runestone/TreeSitter imported outside DesignSystem/CodeEditor"; echo "$hits" | sed 's/^/    /'; fail=1
else echo "✓ Runestone only in DesignSystem/CodeEditor"; fi

exit $fail
