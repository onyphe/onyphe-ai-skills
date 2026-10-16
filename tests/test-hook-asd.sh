#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
HOOK="$REPO_DIR/hooks/check-asd-live.sh"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

run_hook() {
   jq -n --arg c "$1" '{tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null
}

echo "--- Test: live DNS pivot warns ---"
out=$(run_hook "onyphe -asd-dns-domain-ns example.com")
assert_contains "names live DNS" "live DNS lookups" "$out"

echo "--- Test: passive ASD pivot is silent ---"
assert_empty "web-subdomain is passive" "$(run_hook "onyphe -asd-web-subdomain-domain example.com")"

echo "--- Test: opted-in live DNS through the wrapper is silent ---"
assert_empty "wrapper with flag" "$(run_hook "./scripts/onyphe-asd-run.sh --allow-live-dns dns-domain-ns example.com")"

echo "--- Test: delall gets the strong warning ---"
out=$(run_hook "onyphe -asm-inventory-delall")
assert_contains "entire inventory" "ENTIRE ASM inventory" "$out"

echo "--- Test: other inventory calls say not covered ---"
out=$(run_hook "onyphe -asm-inventory-addall inventory.txt")
assert_contains "not covered" "not covered by this package" "$out"
assert_not_contains "not the delall text" "ENTIRE" "$out"

echo "--- Test: ondemand warns ---"
assert_contains "out of scope" "out of scope" "$(run_hook "onyphe -ondemand-scope-ip 192.0.2.1")"

echo "--- Test: bare -discovery warns, scoped one does not ---"
assert_contains "warns" "neither -since: nor -fields:" "$(run_hook "onyphe -discovery riskscan 'inventory.txt'")"
assert_empty "since is enough" "$(run_hook "onyphe -discovery riskscan 'inventory.txt -since:3M'")"

echo "--- Test: non-onyphe commands untouched ---"
assert_empty "ls" "$(run_hook "ls -la")"

report
