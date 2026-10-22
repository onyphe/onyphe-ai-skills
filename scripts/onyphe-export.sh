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
#   1  usage error, CLI failure, or a query with an unclosed double quote
#   2  the query already carries its own -fields: (nothing to add)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/oql.sh
source "$SCRIPT_DIR/lib/oql.sh"

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

# An unclosed quote makes the CLI read the rest of the argument as quoted, so
# an appended -fields: would be swallowed into a value and the export would
# run unprojected.
if ! oql_quotes_balanced "$query"; then
   echo "The query has an unclosed double quote; -fields: cannot be added safely." >&2
   exit 1
fi

# Only an unquoted -fields: is a projection. One inside a value is just text.
if [[ "$(oql_unquoted "$query")" == *"-fields:"* ]]; then
   echo "The query already carries -fields:. Pass the field list once, not twice." >&2
   exit 2
fi

# Split the OQL from any OPP pipeline so -fields: lands on the OQL side. The
# CLI splits on the first unquoted |, and -fields: after that point would be
# read as an argument to a proc rather than as an OQL function.
oql_split "$query"
full="${OQL_PART} -fields:${fields}${OPP_PART:+ | ${OPP_PART}}"

# Split the result the way the CLI will. If -fields: does not end the OQL
# part, the projection would be lost: fail loudly rather than export the
# wrong query with full documents.
oql_split "$full"
if [[ "$OQL_PART" != *" -fields:${fields}" ]] || ! oql_quotes_balanced "$OQL_PART"; then
   echo "Refusing to export: -fields: would not land on the OQL side of: $full" >&2
   exit 1
fi

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
