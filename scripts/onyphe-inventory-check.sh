#!/usr/bin/env bash
# Validate an inventory.txt before it is handed to `onyphe -discovery`.
#
# Why this exists: a line the Discovery API cannot parse is NOT an error. A file
# containing the single line `foo bar` returned 10000 documents, none of them
# related to anything in the file (measured 2026-10-16, riskscan). A typo
# therefore looks like a very large, successful result. Validate first.
#
# Accepted lines (blank lines and lines starting with # are ignored):
#   filter:"value"        e.g. domain:"example.com"  ip:"192.0.2.10"
#                              subject.organization:"Example Corp"
#
# Usage: onyphe-inventory-check.sh inventory.txt
#
# Output (stdout): line counts per filter type, then any warnings
# Exit codes:
#   0  every line is valid
#   1  one or more invalid lines (each reported on stderr with its line number)
#   2  usage error or unreadable/empty file

set -euo pipefail

usage() {
   cat >&2 <<'USAGE'
Usage: onyphe-inventory-check.sh inventory.txt

Checks every line is filter:"value" with a dotted ONYPHE field name and a
non-empty value of at most 256 characters. Reports duplicates and a count per
filter type. Never calls the API.
USAGE
   exit 2
}

[[ $# -ne 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

file="$1"
[[ -r "$file" ]] || { echo "Cannot read $file" >&2; exit 2; }

max_len=256
bad=0
entries=0
declare -A per_type=()
declare -A seen=()
dups=0
lineno=0

while IFS= read -r line || [[ -n "$line" ]]; do
   lineno=$((lineno + 1))
   [[ -z "${line//[[:space:]]/}" || "$line" == \#* ]] && continue

   if [[ ! "$line" =~ ^([a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*):\"([^\"]+)\"$ ]]; then
      echo "line $lineno: not filter:\"value\": $line" >&2
      bad=$((bad + 1))
      continue
   fi

   type="${BASH_REMATCH[1]}"
   value="${BASH_REMATCH[3]}"

   # A shortened domain is a different, wrong asset, so reject rather than truncate.
   if (( ${#value} > max_len )); then
      echo "line $lineno: value longer than $max_len characters" >&2
      bad=$((bad + 1))
      continue
   fi

   entries=$((entries + 1))
   per_type[$type]=$(( ${per_type[$type]:-0} + 1 ))

   if [[ -n "${seen[$line]:-}" ]]; then
      echo "line $lineno: duplicate of line ${seen[$line]}" >&2
      dups=$((dups + 1))
   else
      seen[$line]=$lineno
   fi
done < "$file"

if (( entries == 0 && bad == 0 )); then
   echo "No entries in $file" >&2
   exit 2
fi

echo "entries: $entries"
for t in $(printf '%s\n' "${!per_type[@]}" | sort); do
   echo "  $t: ${per_type[$t]}"
done
(( dups > 0 )) && echo "duplicates: $dups"

(( bad > 0 )) && exit 1
exit 0
