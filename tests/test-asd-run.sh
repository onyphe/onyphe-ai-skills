#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPT="$REPO_DIR/scripts/onyphe-asd-run.sh"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/onyphe-asd.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

mock_onyphe() {
   cat > "$TEST_DIR/onyphe" <<MOCK
#!/usr/bin/env bash
echo "\$@" >> "$TEST_DIR/calls"
$1
MOCK
   chmod +x "$TEST_DIR/onyphe"
   : > "$TEST_DIR/calls"
}

echo "--- Test: passive tool runs and output is de-duplicated ---"
mock_onyphe 'printf "{\"hostname\":\"a.example.com\"}\n{\"hostname\":\"a.example.com\"}\n{\"hostname\":\"b.example.com\"}\n"'
out=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" web-subdomain-domain example.com 2>/dev/null); rc=$?
assert_exit "exits 0" 0 "$rc"
assert_eq "two distinct lines" "2" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
assert_contains "flag form" "-asd-web-subdomain-domain example.com" "$(cat "$TEST_DIR/calls")"

echo "--- Test: live DNS tool refused without the flag, CLI never called ---"
mock_onyphe 'echo "{}"'
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" dns-domain-ns example.com >/dev/null 2>"$TEST_DIR/err"; rc=$?
assert_exit "refused exits 2" 2 "$rc"
assert_contains "explains" "live DNS" "$(cat "$TEST_DIR/err")"
assert_empty "no CLI call made" "$(cat "$TEST_DIR/calls")"

echo "--- Test: live DNS tool allowed with the flag ---"
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" --allow-live-dns dns-domain-ns example.com >/dev/null 2>&1; rc=$?
assert_exit "allowed exits 0" 0 "$rc"
assert_contains "CLI called" "-asd-dns-domain-ns" "$(cat "$TEST_DIR/calls")"

echo "--- Test: error 1006 is an empty result, exit 0 ---"
mock_onyphe 'echo "ERROR: ASD API call failed: 400, {\"text\":\"search failed: no result found\",\"error\":1006}" >&2'
out=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" certso-domain example.com 2>&1); rc=$?
assert_exit "1006 exits 0" 0 "$rc"
assert_contains "says empty is not safe" "Empty is not 'safe'" "$out"

echo "--- Test: other errors fail and the key is redacted ---"
mock_onyphe 'echo "ERROR: ASD API call failed: 500 https://x/asd/domain/tld?k=SECRETKEY123 boom" >&2'
out=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" domain-tld example.com 2>&1); rc=$?
assert_exit "500 exits 1" 1 "$rc"
assert_not_contains "key not printed" "SECRETKEY123" "$out"
assert_contains "redaction marker" "REDACTED" "$out"

echo "--- Test: unknown tool exits 2 ---"
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" nonsense example.com >/dev/null 2>&1; rc=$?
assert_exit "unknown exits 2" 2 "$rc"

report
