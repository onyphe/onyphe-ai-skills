#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPT="$REPO_DIR/scripts/onyphe-inventory-check.sh"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/onyphe-inv.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

echo "--- Test: valid file, comments and blanks ignored ---"
printf '# assets\n\ndomain:"example.com"\nip:"192.0.2.10"\nsubject.organization:"Example Corp"\n' > "$TEST_DIR/ok.txt"
out=$(bash "$SCRIPT" "$TEST_DIR/ok.txt" 2>&1); rc=$?
assert_exit "valid exits 0" 0 "$rc"
assert_contains "total" "entries: 3" "$out"
assert_contains "per type" "domain: 1" "$out"
assert_contains "dotted type" "subject.organization: 1" "$out"

echo "--- Test: a line that is not filter:\"value\" fails ---"
printf 'foo bar\n' > "$TEST_DIR/bad.txt"
out=$(bash "$SCRIPT" "$TEST_DIR/bad.txt" 2>&1); rc=$?
assert_exit "bad exits 1" 1 "$rc"
assert_contains "line number" "line 1" "$out"

echo "--- Test: unquoted value fails ---"
printf 'domain:example.com\n' > "$TEST_DIR/unq.txt"
bash "$SCRIPT" "$TEST_DIR/unq.txt" >/dev/null 2>&1; rc=$?
assert_exit "unquoted exits 1" 1 "$rc"

echo "--- Test: over-long value is rejected, not truncated ---"
long=$(printf 'a%.0s' $(seq 1 300))
printf 'domain:"%s.com"\n' "$long" > "$TEST_DIR/long.txt"
out=$(bash "$SCRIPT" "$TEST_DIR/long.txt" 2>&1); rc=$?
assert_exit "long exits 1" 1 "$rc"
assert_contains "says why" "longer than 256" "$out"

echo "--- Test: duplicates reported but valid ---"
printf 'domain:"example.com"\ndomain:"example.com"\n' > "$TEST_DIR/dup.txt"
out=$(bash "$SCRIPT" "$TEST_DIR/dup.txt" 2>&1); rc=$?
assert_exit "dup exits 0" 0 "$rc"
assert_contains "dup count" "duplicates: 1" "$out"

echo "--- Test: empty file and missing file exit 2 ---"
: > "$TEST_DIR/empty.txt"
bash "$SCRIPT" "$TEST_DIR/empty.txt" >/dev/null 2>&1; rc=$?
assert_exit "empty exits 2" 2 "$rc"
bash "$SCRIPT" "$TEST_DIR/nope.txt" >/dev/null 2>&1; rc=$?
assert_exit "missing exits 2" 2 "$rc"

report
