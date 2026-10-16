#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPT="$REPO_DIR/scripts/onyphe-export.sh"
FIXTURES="$SCRIPT_DIR/fixtures"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/onyphe-export.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

# The mock echoes the query it was handed to a side file, so the tests can
# assert on how -fields: was assembled, then emits the fixture.
cat > "$TEST_DIR/onyphe" <<MOCK
#!/usr/bin/env bash
printf '%s' "\$2" > "$TEST_DIR/seen_query"
cat "$FIXTURES/ctiscan_c2_3.ndjson"
MOCK
chmod +x "$TEST_DIR/onyphe"

echo "--- Test: streams NDJSON to stdout ---"
out=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan app.device:c2' ip.dest,tcp.dest 2>/dev/null)
assert_eq "three documents" "3" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"

echo "--- Test: appends -fields: to the OQL ---"
assert_contains "field list added" "-fields:ip.dest,tcp.dest" "$(cat "$TEST_DIR/seen_query")"

echo "--- Test: -fields: lands before an OPP pipeline, not after ---"
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan app.device:c2 | uniq ip.dest' ip.dest,tag >/dev/null 2>&1
seen=$(cat "$TEST_DIR/seen_query")
assert_contains "pipeline preserved" "| uniq ip.dest" "$seen"
# -fields: must sit on the OQL side of the first |, or the CLI reads it as a proc arg.
oql_side="${seen%%|*}"
assert_contains "-fields: on the OQL side" "-fields:ip.dest,tag" "$oql_side"

echo "--- Test: writes to a file and reports the count on stderr ---"
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan x:y' ip.dest "$TEST_DIR/out.ndjson" 2>"$TEST_DIR/err"
assert_eq "file has three lines" "3" "$(wc -l < "$TEST_DIR/out.ndjson" | tr -d ' ')"
assert_contains "count on stderr" "wrote 3 documents" "$(cat "$TEST_DIR/err")"

echo "--- Test: refuses a query that already carries -fields: ---"
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan x:y -fields:ip.dest' ip.dest >/dev/null 2>&1; rc=$?
assert_exit "double -fields: exits 2" 2 "$rc"

echo "--- Test: refuses to run with no field list ---"
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan x:y' >/dev/null 2>&1; rc=$?
assert_exit "missing fields exits 1" 1 "$rc"

echo "--- Test: usage on no args ---"
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" >/dev/null 2>&1; rc=$?
assert_exit "no args exits 1" 1 "$rc"

report
