#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPT="$REPO_DIR/scripts/onyphe-count.sh"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/onyphe-count.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

mock_onyphe() {
   cat > "$TEST_DIR/onyphe" <<MOCK
#!/usr/bin/env bash
$1
MOCK
   chmod +x "$TEST_DIR/onyphe"
}

echo "--- Test: parses total ---"
mock_onyphe 'echo "{\"@category\":\"user\",\"total\":3411,\"count\":0}"'
out=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan app.device:c2' 2>/dev/null)
assert_eq "total extracted" "3411" "$out"

echo "--- Test: zero is a real answer, not an error ---"
mock_onyphe 'echo "{\"total\":0}"'
out=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan nothing:here' 2>/dev/null); rc=$?
assert_eq "zero returned" "0" "$out"
assert_exit "zero exits 0" 0 "$rc"

echo "--- Test: API error document surfaces, exit 1 ---"
mock_onyphe 'echo "{\"status\":\"nok\",\"error\":12,\"text\":\"access denied: filter not allowed: nosuchfield\"}"'
out=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan nosuchfield:x' 2>"$TEST_DIR/err"); rc=$?
assert_exit "error doc exits 1" 1 "$rc"
assert_contains "error text surfaced" "filter not allowed" "$(cat "$TEST_DIR/err")"

echo "--- Test: empty response exits 1 ---"
mock_onyphe 'true'
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan x:y' >/dev/null 2>&1; rc=$?
assert_exit "empty exits 1" 1 "$rc"

echo "--- Test: refuses an OPP pipeline ---"
mock_onyphe 'echo "{\"total\":1}"'
out=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan x:y | uniq ip.dest' 2>&1); rc=$?
assert_exit "pipeline exits 1" 1 "$rc"
assert_contains "explains why" "no | pipeline" "$out"

echo "--- Test: | inside a quoted regexp is counted ---"
mock_onyphe 'printf "%s" "$3" > "'"$TEST_DIR"'/seen_query"; echo "{\"total\":7}"'
out=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan -regexp:x,".*(a|b).*" -dayago:1' 2>/dev/null); rc=$?
assert_exit "quoted | exits 0" 0 "$rc"
assert_eq "total returned" "7" "$out"
assert_eq "query passed through unchanged" 'category:ctiscan -regexp:x,".*(a|b).*" -dayago:1' "$(cat "$TEST_DIR/seen_query")"

echo "--- Test: | inside a quoted value at the end is counted ---"
out=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan html.title.text:"a|b"' 2>/dev/null); rc=$?
assert_exit "quoted | exits 0" 0 "$rc"

echo "--- Test: quoted | plus a real pipeline is still refused ---"
out=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan -regexp:x,".*(a|b).*" -dayago:1 | uniq ip.dest' 2>&1); rc=$?
assert_exit "pipeline exits 1" 1 "$rc"
assert_contains "explains why" "no | pipeline" "$out"

echo "--- Test: refuses an unclosed quote ---"
out=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan html.title.text:"a|b' 2>&1); rc=$?
assert_exit "unclosed quote exits 1" 1 "$rc"
assert_contains "explains why" "unclosed double quote" "$out"

echo "--- Test: usage on no args ---"
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" >/dev/null 2>&1; rc=$?
assert_exit "no args exits 1" 1 "$rc"

report
