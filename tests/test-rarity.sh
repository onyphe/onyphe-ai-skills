#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPT="$REPO_DIR/scripts/onyphe-rarity.sh"
FIXTURES="$SCRIPT_DIR/fixtures"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/onyphe-rarity.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/scripts"
cp "$SCRIPT" "$TEST_DIR/scripts/onyphe-rarity.sh"
chmod +x "$TEST_DIR/scripts/onyphe-rarity.sh"

# Counts keyed off the field being queried, so ordering can be asserted.
cat > "$TEST_DIR/scripts/onyphe-count.sh" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  *cert.fingerprint.md5*) echo 1 ;;
  *cert.issuer.cn*)       echo 6 ;;
  *ja3s*)                 echo 26812618 ;;
  *tcp.fingerprint*)      echo 41074061 ;;
  *)                      echo 999 ;;
esac
MOCK
chmod +x "$TEST_DIR/scripts/onyphe-count.sh"

RARITY="$TEST_DIR/scripts/onyphe-rarity.sh"

echo "--- Test: extracts pivot values from a document ---"
out=$(bash "$RARITY" --file "$FIXTURES/ctiscan_c2_3.ndjson" \
   --fields cert.fingerprint.md5,cert.issuer.cn,ja3s.fingerprint.md5,tcp.fingerprint.md5 2>/dev/null)
assert_contains "found the cert issuer" "Major Cobalt Strike" "$out"
assert_contains "found the JA3S" "15af977ce25de452b96affa2addb1036" "$out"

echo "--- Test: sorted rarest first ---"
first=$(printf '%s\n' "$out" | head -1 | cut -f1)
last=$(printf '%s\n' "$out" | tail -1 | cut -f1)
assert_eq "rarest first" "1" "$first"
assert_eq "broadest last" "41074061" "$last"

echo "--- Test: output is count/field/value TSV ---"
cols=$(printf '%s\n' "$out" | head -1 | awk -F'\t' '{print NF}')
assert_eq "three columns" "3" "$cols"

echo "--- Test: values are deduplicated across documents ---"
# Two fixture docs share one cert fingerprint; it must be counted once.
n=$(printf '%s\n' "$out" | grep -c '562664f622db669088fdf3c299d910ed')
assert_eq "shared value counted once" "1" "$n"

echo "--- Test: --dry-run spends nothing ---"
cat > "$TEST_DIR/scripts/onyphe-count.sh" <<'MOCK'
#!/usr/bin/env bash
echo "COUNT SHOULD NOT RUN" >&2
exit 1
MOCK
chmod +x "$TEST_DIR/scripts/onyphe-count.sh"
out=$(bash "$RARITY" --file "$FIXTURES/ctiscan_c2_3.ndjson" --fields cert.issuer.cn --dry-run 2>/dev/null)
assert_contains "placeholder instead of a count" "?" "$out"
assert_not_contains "no count ran" "COUNT SHOULD NOT RUN" "$out"

echo "--- Test: reports credit cost before spending ---"
err=$(bash "$RARITY" --file "$FIXTURES/ctiscan_c2_3.ndjson" --fields cert.issuer.cn --dry-run 2>&1 >/dev/null)
assert_contains "cost announced" "credits" "$err"

echo "--- Test: missing file exits 1 ---"
bash "$RARITY" --file "$TEST_DIR/nope.ndjson" >/dev/null 2>&1; rc=$?
assert_exit "missing file exits 1" 1 "$rc"

echo "--- Test: a document with none of the fields exits 1 ---"
bash "$RARITY" --file "$FIXTURES/ctiscan_c2_3.ndjson" --fields no.such.field >/dev/null 2>&1; rc=$?
assert_exit "no pivot fields exits 1" 1 "$rc"

echo "--- Test: --category defaults to ctiscan ---"
err=$(bash "$RARITY" --file "$FIXTURES/ctiscan_c2_3.ndjson" --fields cert.issuer.cn --dry-run 2>&1 >/dev/null)
assert_contains "default category is ctiscan" "category:ctiscan " "$err"

echo "--- Test: --category ctiurl reaches the query ---"
err=$(bash "$RARITY" --file "$FIXTURES/ctiscan_c2_3.ndjson" --fields cert.issuer.cn --dry-run --category ctiurl 2>&1 >/dev/null)
assert_contains "ctiurl used" "category:ctiurl " "$err"
assert_not_contains "ctiscan not used" "category:ctiscan " "$err"

echo "--- Test: --category passes a comma list through verbatim ---"
err=$(bash "$RARITY" --file "$FIXTURES/ctiscan_c2_3.ndjson" --fields cert.issuer.cn --dry-run --category ctiscan,ctiurl 2>&1 >/dev/null)
assert_contains "comma list preserved" "category:ctiscan,ctiurl " "$err"

echo "--- Test: a datascan-model category is rejected, not silently zeroed ---"
err=$(bash "$RARITY" --file "$FIXTURES/ctiscan_c2_3.ndjson" --fields cert.issuer.cn --category datascan 2>&1 >/dev/null); rc=$?
assert_exit "unsupported category exits 1" 1 "$rc"
assert_contains "reason named" "ctiscan-model only" "$err"

echo "--- Test: usage on no args ---"
bash "$RARITY" >/dev/null 2>&1; rc=$?
assert_exit "no args exits 1" 1 "$rc"

report
