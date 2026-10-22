#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"
# shellcheck source=scripts/lib/oql.sh
source "$REPO_DIR/scripts/lib/oql.sh"

# Expected splits mirror the CLI's own walk in bin/onyphe: only " toggles
# the quoted state, and both sides are trimmed.
check_split() {
   local label="$1" input="$2" oql="$3" opp="$4"
   oql_split "$input"
   assert_eq "$label (OQL)" "$oql" "$OQL_PART"
   assert_eq "$label (OPP)" "$opp" "$OPP_PART"
}

echo "--- Test: oql_split ---"
check_split "no pipe"         'a:b c:d'                  'a:b c:d'              ''
check_split "plain pipe"      'a:b | uniq ip'            'a:b'                  'uniq ip'
check_split "first pipe wins" 'a:b | uniq ip | top ip'   'a:b'                  'uniq ip | top ip'
check_split "quoted pipe"     'x:".*(a|b).*" -dayago:1'  'x:".*(a|b).*" -dayago:1' ''
check_split "quoted then real" 'x:"a|b" | uniq ip'       'x:"a|b"'              'uniq ip'
check_split "unclosed quote"  'x:"a | uniq ip'           'x:"a | uniq ip'       ''
check_split "trims"           '  a:b  |  uniq ip  '      'a:b'                  'uniq ip'
# Parity: the CLI does not honour \" as an escape, so neither does the split.
check_split "backslash quote" 'x:"a\"|b"'                'x:"a\"'               'b"'
check_split "single quotes"   "x:'a|b'"                  "x:'a"                 "b'"

echo "--- Test: oql_unquoted ---"
assert_eq "drops quoted spans" 'x: y:' "$(oql_unquoted 'x:"a -fields:b" y:"c|d"')"
assert_eq "unclosed quote swallows the rest" 'x:' "$(oql_unquoted 'x:"a -fields:b')"

echo "--- Test: oql_quotes_balanced ---"
oql_quotes_balanced 'x:"a|b"'; assert_exit "balanced" 0 $?
oql_quotes_balanced 'x:y';     assert_exit "no quotes" 0 $?
oql_quotes_balanced 'x:"a|b';  assert_exit "unclosed" 1 $?

report
