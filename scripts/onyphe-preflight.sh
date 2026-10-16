#!/usr/bin/env bash
# Report the licence this API key actually has, before spending anything on it.
#
# Wraps `onyphe -user`. Prints view name, credit balance, authorised categories,
# authorised OQL functions and history depth. Everything else in the package
# reads this first: which categories exist, whether a function is usable, and
# how far back a timeline can go are all licence-dependent.
#
# The /user response embeds the API key. It is filtered out here and never
# printed, never written to a file.
#
# Usage: onyphe-preflight.sh [category ...]
#
# Output (stdout): human-readable summary; with --json, the redacted raw doc
# Exit codes:
#   0  success, and every requested category is authorised
#   1  CLI failure, missing key, or malformed response
#   3  a requested category is not authorised on this licence

set -euo pipefail

usage() {
   cat >&2 <<'USAGE'
Usage: onyphe-preflight.sh [--json] [category ...]

Reports the licence backing ~/.onyphe.ini. Naming one or more categories
checks them against the licence and exits 3 if any is unauthorised.

  onyphe-preflight.sh
  onyphe-preflight.sh ctiscan ctiurl
  onyphe-preflight.sh --json | jq .
USAGE
   exit 1
}

as_json=0
if [[ "${1:-}" == "--json" ]]; then
   as_json=1
   shift
fi
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

stderr_file=$(mktemp)
trap 'rm -f "$stderr_file"' EXIT

raw=$(onyphe -user 2>"$stderr_file") || true

if [[ -z "$raw" ]]; then
   if [[ -s "$stderr_file" ]]; then
      cat "$stderr_file" >&2
   else
      echo "onyphe -user returned nothing. Check api_key in ~/.onyphe.ini." >&2
   fi
   exit 1
fi

# Strip the API key before the document goes anywhere else.
doc=$(printf '%s' "$raw" | jq -c 'del(.apikey)' 2>/dev/null) || {
   echo "Could not parse the /user response as JSON." >&2
   exit 1
}

if [[ "$as_json" -eq 1 ]]; then
   printf '%s\n' "$doc"
   exit 0
fi

printf '%s' "$doc" | jq -r '
   "View:            \(.view // .licensename // "unknown")",
   "Customer:        \(.customer.name // "unknown")",
   "Expires:         \(.enddate // "unknown")",
   "OQL version:     \(.oqlversion // "unknown")",
   "History:         \(.history // "unknown")   (export: \(.exporthistory // "n/a"))",
   "Commercial use:  \(.commercialuse // "unknown")",
   "Credits:         \(if (.credits // 0) == 0 then "0 reported - unlimited views report 0 here, metered views report a real balance" else (.credits|tostring) end)",
   "",
   "Categories (\(.categories | length)):",
   "  \(.categories | join(" "))",
   "",
   "OQL functions (long forms):",
   "  \([.functions[] | select(length > 3)] | sort | join(" "))"
'

# A licence that cannot run the core hunting categories is worth saying out loud.
for want in "$@"; do
   if ! printf '%s' "$doc" | jq -e --arg c "$want" '.categories | index($c)' >/dev/null; then
      echo "" >&2
      echo "NOT AUTHORISED: category '$want' is not on this licence." >&2
      echo "Queries against it will return nothing rather than an error." >&2
      exit 3
   fi
done

exit 0
