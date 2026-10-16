#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
HOOK="$REPO_DIR/hooks/check-category-fields.sh"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

run_hook() {
   jq -n --arg c "$1" '{tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null
}

echo "--- Test: datascan names under ctiscan are caught ---"
out=$(run_hook "onyphe -search 'category:ctiscan data:\"Apache\" port:443 status:200'")
assert_contains "flags data:"   "'data:' is a datascan field"   "$out"
assert_contains "flags port:"   "'port:' is a datascan field"   "$out"
assert_contains "flags status:" "'status:' is a datascan field" "$out"
assert_contains "names the fix" "app.data.text:" "$out"

echo "--- Test: correct ctiscan dialect stays silent ---"
# These are the substring traps: services.port: contains port:, http.url: contains
# url:, app.protocol: contains protocol:. A hook that fires here is worse than none.
out=$(run_hook "onyphe -search 'category:ctiscan app.protocol:http services.port:443 http.url:\"/x\" app.data.text:\"y\"'")
assert_empty "no warning on correct query" "$out"

echo "--- Test: each substring trap individually ---"
for q in 'services.port:443' 'http.url:"/a"' 'app.protocol:ssh' 'ip.dest:203.0.113.10'; do
   out=$(run_hook "onyphe -search 'category:ctiscan $q'")
   assert_empty "silent on $q" "$out"
done

echo "--- Test: ctiurl is treated like ctiscan ---"
out=$(run_hook "onyphe -search 'category:ctiurl cpe:\"cpe:/a:x:y:-\"'")
assert_contains "flags cpe: under ctiurl" "component.cpe:" "$out"

echo "--- Test: fires in the other direction too ---"
out=$(run_hook "onyphe -search 'category:datascan app.data.text:\"Apache\" ip.dest:203.0.113.10'")
assert_contains "flags ctiscan name under datascan" "is a ctiscan field" "$out"

echo "--- Test: every non-cti category is the datascan model ---"
out=$(run_hook "onyphe -search 'category:vulnscan app.data.text:\"x\"'")
assert_contains "flags ctiscan name under vulnscan" "is a ctiscan field" "$out"
out=$(run_hook "onyphe -search 'category:vulnscan cpe:\"cpe:/a:x:y:-\" port:80'")
assert_empty "datascan names stay silent under vulnscan" "$out"

echo "--- Test: silent on non-onyphe commands ---"
assert_empty "git untouched" "$(run_hook 'git status')"
assert_empty "grep untouched" "$(run_hook "grep -r 'data:' .")"

echo "--- Test: silent when no category is named ---"
assert_empty "no category, no warning" "$(run_hook "onyphe -search 'data:\"Apache\"'")"

echo "--- Test: always exits 0 ---"
jq -n --arg c "onyphe -search 'category:ctiscan data:\"x\"'" '{tool_input:{command:$c}}' | bash "$HOOK" >/dev/null 2>&1
assert_exit "advisory, never blocks" 0 $?

echo "--- Test: output is valid JSON with a systemMessage ---"
out=$(run_hook "onyphe -search 'category:ctiscan data:\"x\"'")
assert_eq "systemMessage present" "true" "$(printf '%s' "$out" | jq -e 'has("systemMessage")' 2>/dev/null)"

report
