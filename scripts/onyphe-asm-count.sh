#!/usr/bin/env bash
# Tag-by-tag summary of what riskscan or vulnscan hold for an inventory.
#
# One `onyphe -discovery` call per tag, projected to ip,port so almost nothing
# is transferred, then counted as BOTH documents and distinct ip:port assets.
# The two differ a lot once a window is given: a -since:7M query returned 57
# documents for 6 assets on a small test inventory (measured 2026-10-16), because
# every re-scan is a separate document. Quote assets, not documents.
#
# Usage: onyphe-asm-count.sh <riskscan|vulnscan> <inventory.txt> <window> [tag ...]
#   onyphe-asm-count.sh riskscan inventory.txt 3M risk::exposeddatabase risk::loginpage
#   onyphe-asm-count.sh vulnscan inventory.txt 1M vulnerable
#
# With no tag, one unfiltered line is reported ("(any)").
# For vulnscan, -exists:cve is always added so only records carrying a CVE count;
# that excludes verdicts with no CVE (e.g. unknownversion) by design.
# Zero is reported as 0, never as "clean": see the skill for why.
#
# Cost: one Discovery call per tag (unlimited on Griffin View).
# Exit codes: 0 ok, 1 call failed, 2 usage error or invalid inventory

set -euo pipefail

usage() {
   cat >&2 <<'USAGE'
Usage: onyphe-asm-count.sh <riskscan|vulnscan> <inventory.txt> <window> [tag ...]

window is an OQL -since: value such as 1d, 1M or 7M.
The inventory is validated first (onyphe-inventory-check.sh).
USAGE
   exit 2
}

[[ $# -ge 3 ]] || usage
category="$1"; inv="$2"; window="$3"; shift 3

case "$category" in
   riskscan|vulnscan) ;;
   *) echo "Category must be riskscan or vulnscan, got: $category" >&2; exit 2 ;;
esac
[[ "$window" =~ ^[0-9]+[A-Za-z]+$ ]] || { echo "Bad window: $window (expected e.g. 3M)" >&2; exit 2; }

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$here/onyphe-inventory-check.sh" "$inv" >/dev/null || {
   echo "Inventory failed validation; a malformed line returns unrelated documents, not an error." >&2
   exit 2
}

suffix=""
[[ "$category" == "vulnscan" ]] && suffix="-exists:cve "

tags=("$@")
[[ ${#tags[@]} -gt 0 ]] || tags=("")

printf '%-34s %10s %10s\n' "tag" "documents" "assets"
for tag in "${tags[@]}"; do
   filter=""
   [[ -n "$tag" ]] && filter="tag:$tag "
   out=$(onyphe -discovery "$category" "$inv ${suffix}${filter}-since:$window -fields:ip,port" 2>/dev/null) || {
      echo "Discovery call failed for tag '${tag:-(any)}'." >&2
      exit 1
   }
   docs=0; assets=0
   if [[ -n "$out" ]]; then
      docs=$(printf '%s\n' "$out" | jq -c 'select(.ip != null)' | wc -l | tr -d ' ')
      assets=$(printf '%s\n' "$out" | jq -r 'select(.ip != null) | "\(.ip):\(.port)"' | sort -u | wc -l | tr -d ' ')
   fi
   printf '%-34s %10s %10s\n' "${tag:-(any)}" "$docs" "$assets"
done
