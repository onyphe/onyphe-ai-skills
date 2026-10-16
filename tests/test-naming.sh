#!/usr/bin/env bash
# Guard: no competitor product name appears anywhere in this package.
#
# The package documents ONYPHE on its own terms. A competitor name in a shipped
# artefact reads as positioning rather than documentation, and dates the work to
# someone else's feature set.
#
# The forbidden terms are base64-encoded below for exactly the reason this test
# exists: written literally, this file would itself be the violation it checks
# for. Decode with: echo 'Y2Vuc3lzfGNlbmNsaXxjZW5xbHxjZW5zZXll' | base64 -d
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

PATTERN=$(printf '%s' 'Y2Vuc3lzfGNlbmNsaXxjZW5xbHxjZW5zZXll' | base64 -d)

echo "--- Test: no competitor name in any shipped file ---"
hits=$(grep -rniE "$PATTERN" "$REPO_DIR" \
         --exclude-dir=.hg --exclude-dir=.git --exclude-dir=data \
         --exclude=test-naming.sh 2>/dev/null || true)
assert_empty "package is free of competitor names" "$hits"

echo "--- Test: the guard actually detects a violation ---"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/onyphe-naming.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
printf '%s\n' "$PATTERN" | cut -d'|' -f1 > "$tmp/planted.md"
planted=$(grep -rniE "$PATTERN" "$tmp" 2>/dev/null || true)
assert_contains "a planted name is caught" "planted.md" "$planted"

report
