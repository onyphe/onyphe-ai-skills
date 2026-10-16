#!/usr/bin/env bash
# Stream an OQL query to NDJSON through the Export API, with a mandatory
# field projection.
#
# Export has no page limit and no 10,000-result ceiling, which makes it the
# right endpoint for a full population pull - and the wrong one to run
# unprojected. `-fields:` is the only lever that bounds how much comes back
# per document, so this script refuses to run without one.
#
# Usage: onyphe-export.sh '<OQL>' '<field,field,...>' [outfile]
#
# Output: NDJSON on stdout, or to outfile. Progress goes to stderr, so the
#         stdout stream stays clean for a pipe into `opp`.
# Exit codes:
#   0  success
#   1  usage error or CLI failure
#   2  the query already carries its own -fields: (nothing to add)

set -euo pipefail

usage() {
   cat >&2 <<'USAGE'
Usage: onyphe-export.sh '<OQL>' '<field,field,...>' [outfile]

Streams every matching document as NDJSON. The field list is required.

  onyphe-export.sh 'category:ctiscan app.device:c2 -dayago:1' \
    ip.dest,tcp.dest,cert.subject.cn,ja3s.fingerprint.md5,tag

  onyphe-export.sh 'category:ctiurl html.title.text:"index of" -weekago:1' \
    ip.dest,http.url,html.title.raw data/opendir.ndjson

Scope the query with onyphe-count.sh first. Export streams whatever matches;
there is no ceiling to stop a query that was broader than intended.
USAGE
   exit 1
}

[[ $# -lt 2 || $# -gt 3 ]] && usage
[[ "$1" == "-h" || "$1" == "--help" ]] && usage

query="$1"
fields="$2"
outfile="${3:-}"

[[ -z "$query"  ]] && usage
[[ -z "$fields" ]] && usage

if [[ "$query" == *"-fields:"* ]]; then
   echo "The query already carries -fields:. Pass the field list once, not twice." >&2
   exit 2
fi

# Split the OQL from any OPP pipeline so -fields: lands on the OQL side. The
# CLI splits on the first unquoted |, and -fields: after that point would be
# read as an argument to a proc rather than as an OQL function.
if [[ "$query" == *"|"* ]]; then
   oql="${query%%|*}"
   opp="|${query#*|}"
   oql="${oql%"${oql##*[![:space:]]}"}"
else
   oql="$query"
   opp=""
fi

full="${oql} -fields:${fields}${opp:+ ${opp}}"

echo "[onyphe-export] $full" >&2

run_export() {
   onyphe -export "$full"
}

if [[ -n "$outfile" ]]; then
   mkdir -p "$(dirname "$outfile")"
   run_export > "$outfile"
   lines=$(wc -l < "$outfile" | tr -d ' ')
   echo "[onyphe-export] wrote $lines documents to $outfile" >&2
else
   run_export
fi
