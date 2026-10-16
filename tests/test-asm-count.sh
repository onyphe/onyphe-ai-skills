#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPT="$REPO_DIR/scripts/onyphe-asm-count.sh"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/onyphe-asm.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT
printf 'domain:"example.com"\n' > "$TEST_DIR/inv.txt"

mock_onyphe() {
   cat > "$TEST_DIR/onyphe" <<MOCK
#!/usr/bin/env bash
echo "\$@" >> "$TEST_DIR/calls"
$1
MOCK
   chmod +x "$TEST_DIR/onyphe"
   : > "$TEST_DIR/calls"
}

echo "--- Test: documents and distinct assets are reported separately ---"
mock_onyphe 'printf "{\"ip\":\"192.0.2.1\",\"port\":443}\n{\"ip\":\"192.0.2.1\",\"port\":443}\n{\"ip\":\"192.0.2.2\",\"port\":22}\n"'
out=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" riskscan "$TEST_DIR/inv.txt" 3M risk::loginpage 2>&1); rc=$?
assert_exit "exits 0" 0 "$rc"
assert_contains "3 documents, 2 assets" "risk::loginpage                             3          2" "$out"
assert_contains "query shape" "tag:risk::loginpage -since:3M -fields:ip,port" "$(cat "$TEST_DIR/calls")"

echo "--- Test: zero is printed as 0 ---"
mock_onyphe 'true'
out=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" vulnscan "$TEST_DIR/inv.txt" 1M vulnerable 2>&1)
assert_contains "vulnscan adds -exists:cve" "-exists:cve tag:vulnerable -since:1M" "$(cat "$TEST_DIR/calls")"
assert_contains "zero row" "vulnerable                                  0          0" "$out"

echo "--- Test: riskscan does not get -exists:cve ---"
mock_onyphe 'true'
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" riskscan "$TEST_DIR/inv.txt" 3M risk::loginpage >/dev/null 2>&1
assert_not_contains "riskscan unfiltered by cve" "-exists:cve" "$(cat "$TEST_DIR/calls")"

echo "--- Test: invalid inventory stops before any call ---"
printf 'foo bar\n' > "$TEST_DIR/bad.txt"
mock_onyphe 'echo "{}"'
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" riskscan "$TEST_DIR/bad.txt" 3M >/dev/null 2>&1; rc=$?
assert_exit "invalid exits 2" 2 "$rc"
assert_empty "no call made" "$(cat "$TEST_DIR/calls")"

echo "--- Test: category and window validated ---"
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" datascan "$TEST_DIR/inv.txt" 3M >/dev/null 2>&1; rc=$?
assert_exit "bad category exits 2" 2 "$rc"
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" riskscan "$TEST_DIR/inv.txt" forever >/dev/null 2>&1; rc=$?
assert_exit "bad window exits 2" 2 "$rc"

report
