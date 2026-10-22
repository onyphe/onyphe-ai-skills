#!/usr/bin/env bash
# Exact result count for an OQL query, for one credit and one round trip.
#
# Wraps `onyphe -count -search`, which asks the server for the total and
# returns a single {"total":N} document instead of any results. The number is
# the true total: it is not capped, not a page count, and not a floor. This is
# why scoping with a count is cheap enough to be mandatory before any pull.
#
# Usage: onyphe-count.sh '<OQL>'
#
# Output (stdout): the integer total
# Exit codes:
#   0  success
#   1  usage error, CLI failure, or a response with no total

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/oql.sh
source "$SCRIPT_DIR/lib/oql.sh"

usage() {
   cat >&2 <<'USAGE'
Usage: onyphe-count.sh '<OQL>'

Prints the exact number of documents matching an OQL query.

  onyphe-count.sh 'category:ctiscan app.device:c2 -dayago:1'
  onyphe-count.sh 'category:ctiurl html.title.text:"index of" -weekago:1'

Cost: one credit, regardless of how many documents match.
USAGE
   exit 1
}

[[ $# -ne 1 || -z "${1:-}" ]] && usage
[[ "$1" == "-h" || "$1" == "--help" ]] && usage

query="$1"

# An unclosed quote turns everything after it into a value. onyphe-hpcheck.sh
# appends its control terms to the end, where they would silently vanish.
if ! oql_quotes_balanced "$query"; then
   echo "onyphe-count.sh: the query has an unclosed double quote." >&2
   exit 1
fi

# An OPP pipeline changes what comes back and would break the total parse.
# Only an unquoted | starts one; a | inside a quoted value, such as a regexp
# alternation, is OQL.
oql_split "$query"
if [[ -n "$OPP_PART" ]]; then
   echo "onyphe-count.sh takes a bare OQL query, with no | pipeline." >&2
   echo "Counting happens server-side; there is nothing for OPP to process." >&2
   exit 1
fi

stderr_file=$(mktemp)
trap 'rm -f "$stderr_file"' EXIT

raw=$(onyphe -count -search "$query" 2>"$stderr_file") || true

if [[ -z "$raw" ]]; then
   if [[ -s "$stderr_file" ]]; then
      cat "$stderr_file" >&2
   else
      echo "No response for query: $query" >&2
   fi
   exit 1
fi

# The count response is a single document; take the first total seen.
total=$(printf '%s' "$raw" | jq -r 'select(.total != null) | .total' 2>/dev/null | head -1)

if [[ -z "$total" ]]; then
   # An error document carries text/error rather than total; surface it as-is.
   err=$(printf '%s' "$raw" | jq -r 'select(.text != null) | "\(.error // "?"): \(.text)"' 2>/dev/null | head -1)
   if [[ -n "$err" ]]; then
      echo "API error for query: $query" >&2
      echo "  $err" >&2
   else
      echo "No total in the response for query: $query" >&2
   fi
   exit 1
fi

printf '%s\n' "$total"
