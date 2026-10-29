#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPT="$REPO_DIR/scripts/onyphe-hpcheck.sh"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/onyphe-hpcheck.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

# Mock the count script, keying each of the four counts off the query shape.
# Numbers are the real 2026-09-25 measurement for the Paramiko SSH banner:
# total 53, tagged 22, mp199 31, other 0 -> hpish 100.0
mock_counts() {
   mkdir -p "$TEST_DIR/scripts"
   cat > "$TEST_DIR/scripts/onyphe-count.sh" <<MOCK
#!/usr/bin/env bash
q="\$1"
if [[ "\$q" == *'!tag:honeypot !services.count:199'* ]]; then echo "$4"
elif [[ "\$q" == *'!tag:honeypot services.count:199'* ]]; then echo "$3"
elif [[ "\$q" == *'tag:honeypot'* ]]; then echo "$2"
else echo "$1"; fi
MOCK
   chmod +x "$TEST_DIR/scripts/onyphe-count.sh"
   cp "$SCRIPT" "$TEST_DIR/scripts/onyphe-hpcheck.sh"
   chmod +x "$TEST_DIR/scripts/onyphe-hpcheck.sh"
}

echo "--- Test: fully-honeypot population (real Paramiko figures) ---"
mock_counts 53 22 31 0
out=$(bash "$TEST_DIR/scripts/onyphe-hpcheck.sh" 'app.data.text:"SSH-2.0-Paramiko"' 2>/dev/null)
row=$(printf '%s\n' "$out" | tail -1)
assert_eq "row" "53	22	31	0	41.5	100.0" "$row"

echo "--- Test: mp199 is what makes hpish exceed tag% ---"
# 31 of 53 carry no honeypot tag at all; counting only tagged would report 41.5%.
assert_contains "hpish 100.0" "100.0" "$row"
assert_contains "tag% 41.5" "41.5" "$row"

echo "--- Test: clean population (real Cobalt Strike cert figures) ---"
mock_counts 6 0 0 6
out=$(bash "$TEST_DIR/scripts/onyphe-hpcheck.sh" 'cert.issuer.cn:"Major Cobalt Strike"' 2>/dev/null)
assert_eq "row" "6	0	0	6	0.0	0.0" "$(printf '%s\n' "$out" | tail -1)"

echo "--- Test: zero total is inconclusive, not clean ---"
mock_counts 0 0 0 0
out=$(bash "$TEST_DIR/scripts/onyphe-hpcheck.sh" 'app.data.text:"nothing"' 2>"$TEST_DIR/err"); rc=$?
assert_exit "zero total exits 2" 2 "$rc"
assert_contains "says inconclusive" "inconclusive, not clean" "$(cat "$TEST_DIR/err")"
assert_not_contains "never says clean on its own" "is clean" "$(cat "$TEST_DIR/err")"

echo "--- Test: header row is always present ---"
mock_counts 10 1 2 7
out=$(bash "$TEST_DIR/scripts/onyphe-hpcheck.sh" 'x:y' 2>/dev/null)
assert_eq "header" "total	tagged	mp199	other	tag%	hpish%" "$(printf '%s\n' "$out" | head -1)"

echo "--- Test: a quoted regexp alternation runs all four counts ---"
# The real onyphe-count.sh this time, over a stub CLI that logs each query.
mkdir -p "$TEST_DIR/bin"
cat > "$TEST_DIR/bin/onyphe" <<MOCK
#!/usr/bin/env bash
printf '%s\n' "\$3" >> "$TEST_DIR/queries"
echo '{"total":4}'
MOCK
chmod +x "$TEST_DIR/bin/onyphe"
rm -f "$TEST_DIR/queries"
out=$(PATH="$TEST_DIR/bin:$PATH" bash "$SCRIPT" '-regexp:x,".*(a|b).*"' 2>"$TEST_DIR/err"); rc=$?
assert_exit "alternation exits 0" 0 "$rc"
assert_eq "four counts sent" "4" "$(wc -l < "$TEST_DIR/queries" | tr -d ' ')"
assert_contains "quoted regexp reached the CLI" '-regexp:x,".*(a|b).*"' "$(head -1 "$TEST_DIR/queries")"

echo "--- Test: --base retargets all four counts ---"
rm -f "$TEST_DIR/queries"
PATH="$TEST_DIR/bin:$PATH" bash "$SCRIPT" 'http.hostname:"www.example.com"' \
  --base 'category:ctiurl' >/dev/null 2>&1
assert_eq "four counts sent" "4" "$(wc -l < "$TEST_DIR/queries" | tr -d ' ')"
assert_eq "every query is ctiurl" "4" "$(grep -c 'category:ctiurl' "$TEST_DIR/queries")"
assert_eq "none fell back to ctiscan" "0" "$(grep -c 'category:ctiscan' "$TEST_DIR/queries" || true)"

echo "--- Test: --base is documented in the usage text ---"
usage=$(bash "$SCRIPT" -h 2>&1 || true)
assert_contains "usage explains --base" "--base replaces the default" "$usage"

echo "--- Test: usage on no args ---"
bash "$SCRIPT" >/dev/null 2>&1; rc=$?
assert_exit "no args exits 1" 1 "$rc"

report
