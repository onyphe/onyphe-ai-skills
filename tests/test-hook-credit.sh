#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
HOOK="$REPO_DIR/hooks/check-credit-burn.sh"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

run_hook() {
   jq -n --arg c "$1" '{tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null
}

echo "--- Test: -search without -maxpage warns ---"
out=$(run_hook "onyphe -search 'category:ctiscan app.device:c2'")
assert_contains "warns on maxpage" "without an explicit -maxpage" "$out"
assert_contains "names the config source" "api_maxpage = 1000" "$out"

echo "--- Test: -search with -maxpage does not warn about paging ---"
out=$(run_hook "onyphe -maxpage 1 -size 100 -search 'category:ctiscan app.device:c2'")
assert_not_contains "no maxpage warning" "without an explicit -maxpage" "$out"

echo "--- Test: -count -search is exempt entirely ---"
assert_empty "count is already the cheap path" "$(run_hook "onyphe -count -search 'category:ctiscan x:y'")"

echo "--- Test: suggests counting first ---"
out=$(run_hook "onyphe -maxpage 1 -search 'category:ctiscan x:y'")
assert_contains "suggests -count" "Scope before you pull" "$out"

echo "--- Test: the count script itself is not told to count first ---"
out=$(run_hook "./scripts/onyphe-count.sh 'category:ctiscan x:y'")
assert_not_contains "no recursion" "Scope before you pull" "$out"

echo "--- Test: -export without -fields: warns ---"
out=$(run_hook "onyphe -export 'category:ctiscan app.device:c2'")
assert_contains "warns on missing projection" "-export without -fields:" "$out"
assert_contains "says why it matters" "no result ceiling" "$out"

echo "--- Test: -export with -fields: does not warn ---"
out=$(run_hook "onyphe -export 'category:ctiscan app.device:c2 -fields:ip.dest,tag'")
assert_not_contains "projected export is fine" "-export without -fields:" "$out"

echo "--- Test: silent on unrelated commands ---"
assert_empty "git untouched"  "$(run_hook 'git status')"
assert_empty "ls untouched"   "$(run_hook 'ls -la')"
assert_empty "user untouched" "$(run_hook 'onyphe -user')"

echo "--- Test: always exits 0 ---"
jq -n --arg c "onyphe -search 'category:ctiscan x:y'" '{tool_input:{command:$c}}' | bash "$HOOK" >/dev/null 2>&1
assert_exit "advisory, never blocks" 0 $?

echo "--- Test: output is valid JSON ---"
out=$(run_hook "onyphe -export 'category:ctiscan x:y'")
assert_eq "systemMessage present" "true" "$(printf '%s' "$out" | jq -e 'has("systemMessage")' 2>/dev/null)"

report
