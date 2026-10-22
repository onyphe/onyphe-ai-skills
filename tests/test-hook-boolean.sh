#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
HOOK="$REPO_DIR/hooks/check-oql-boolean.sh"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

run_hook() {
   jq -n --arg c "$1" '{tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null
}

echo "--- Test: the reported failing command is caught ---"
out=$(run_hook "which jq; onyphe -search 'category:datascan (domain:example.com OR
 domain:example.net OR domain:example.org)' -maxpage 10 > datascan.ndjson")
assert_contains "flags OR" "keyword(s) 'OR'" "$out"
assert_contains "names the fix" "?domain:" "$out"
assert_contains "mentions the error signature" "ORdomain" "$out"

echo "--- Test: AND / NOT / || / && are caught too ---"
assert_contains "AND" "'AND'" "$(run_hook "onyphe -search 'category:ctiscan tcp.dest:443 AND app.protocol:http'")"
assert_contains "NOT" "'NOT'" "$(run_hook "onyphe -search 'category:ctiscan tcp.dest:443 NOT app.protocol:http'")"
assert_contains "||"  "||"    "$(run_hook "onyphe -search 'category:ctiscan ( tcp.dest:443 || tcp.dest:80 )'")"

echo "--- Test: correct OQLv2 stays silent ---"
assert_empty "grouped ? terms" "$(run_hook "onyphe -search 'category:datascan ( ?domain:example.com ?domain:example.net ?domain:example.org )'")"
assert_empty "! term" "$(run_hook "onyphe -search 'category:ctiscan !services.port:80'")"

echo "--- Test: wildcard / regexp / exists OR and NOT functions stay silent ---"
for q in '-orwildcard:domain,example.*' '-owd:domain,a*' '-notwildcard:domain,x.*' \
         '-orregexp:domain,"a.*"' '-notregexp:domain,"b.*"' '-orexists:tag'; do
   assert_empty "silent on $q" "$(run_hook "onyphe -search 'category:datascan $q'")"
done

echo "--- Test: OR inside a quoted value is a value, not a keyword ---"
assert_empty "quoted value" "$(run_hook "onyphe -search 'category:ctiscan app.data.text:\"Smith OR Jones\"'")"

echo "--- Test: OPP pipeline text is not OQL ---"
assert_empty "after the first pipe" "$(run_hook "onyphe -search 'category:ctiscan tcp.dest:443 | where x == 1 OR y == 2'")"

echo "--- Test: silent on non-onyphe commands ---"
assert_empty "git untouched" "$(run_hook 'git log --grep "fix OR retry"')"

echo "--- Test: always exits 0, output is JSON ---"
jq -n --arg c "onyphe -search 'category:ctiscan a:1 OR b:2'" '{tool_input:{command:$c}}' | bash "$HOOK" >/dev/null 2>&1
assert_exit "advisory, never blocks" 0 $?
out=$(run_hook "onyphe -search 'category:ctiscan a:1 OR b:2'")
assert_eq "systemMessage present" "true" "$(printf '%s' "$out" | jq -e 'has("systemMessage")' 2>/dev/null)"

report
