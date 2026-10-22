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

# The CLI splits on the first *unquoted* |. A regexp alternation inside a
# quoted value is OQL, and -fields: must land after it, not inside it.
export_seen() {
   PATH="$TEST_DIR:$PATH" bash "$SCRIPT" "$1" F >/dev/null 2>&1
   cat "$TEST_DIR/seen_query"
}

echo "--- Test: | inside a quoted regexp is not a pipeline ---"
assert_eq "regexp alternation kept whole" \
   'category:ctiscan -regexp:x,".*(a|b).*" -dayago:1 -fields:F' \
   "$(export_seen 'category:ctiscan -regexp:x,".*(a|b).*" -dayago:1')"

echo "--- Test: quoted | plus a real pipeline ---"
assert_eq "-fields: before the unquoted |" \
   'category:ctiscan -regexp:x,".*(a|b).*" -dayago:1 -fields:F | uniq ip.dest' \
   "$(export_seen 'category:ctiscan -regexp:x,".*(a|b).*" -dayago:1 | uniq ip.dest')"

echo "--- Test: | inside a quoted value at the end of the query ---"
assert_eq "-fields: after the closing quote" \
   'category:ctiscan html.title.text:"a|b" -fields:F' \
   "$(export_seen 'category:ctiscan html.title.text:"a|b"')"

echo "--- Test: plain pipeline is unchanged ---"
assert_eq "control case" \
   'category:ctiscan app.device:c2 -dayago:1 -fields:F | uniq ip.dest' \
   "$(export_seen 'category:ctiscan app.device:c2 -dayago:1 | uniq ip.dest')"

echo "--- Test: refuses an unclosed quote ---"
rm -f "$TEST_DIR/seen_query"
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan html.title.text:"a|b' F >/dev/null 2>"$TEST_DIR/err"; rc=$?
assert_exit "unclosed quote exits 1" 1 "$rc"
assert_contains "explains why" "unclosed double quote" "$(cat "$TEST_DIR/err")"
assert_eq "CLI never called" "no" "$([[ -e "$TEST_DIR/seen_query" ]] && echo yes || echo no)"

echo "--- Test: -fields: inside a quoted value is not a projection ---"
assert_eq "quoted -fields: accepted" \
   'category:ctiscan html.title.text:"x -fields:y" -fields:F' \
   "$(export_seen 'category:ctiscan html.title.text:"x -fields:y"')"

echo "--- Test: refuses a field list that would break the split ---"
rm -f "$TEST_DIR/seen_query"
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 'category:ctiscan x:y' 'ip.dest|tag' >/dev/null 2>"$TEST_DIR/err"; rc=$?
assert_exit "| in field list exits 1" 1 "$rc"
assert_eq "CLI never called" "no" "$([[ -e "$TEST_DIR/seen_query" ]] && echo yes || echo no)"

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
