#!/usr/bin/env bash
# Score a host's attributes by how many other documents share each one.
#
# Takes one ctiscan document (or an IP, which is pulled first), extracts every
# value of the curated pivot-field set, and counts the population sharing each.
# A low count is a distinctive attribute worth pivoting on; a high count is
# context, not tradecraft.
#
# This costs ONE CREDIT PER ATTRIBUTE VALUE. There is no single call that
# returns a rarity table, so the table is assembled one count at a time. The
# estimate is printed before any of them are spent.
#
# Usage: onyphe-rarity.sh <ip> [options]
#        onyphe-rarity.sh --file <doc.ndjson> [options]
#
# Options:
#   --window <fn>     OQL time function to count within (default: -dayago:1)
#   --fields <list>   comma-separated pivot fields, overriding the default set
#   --dry-run         print the queries and the credit cost, spend nothing
#
# Output (stdout): TSV `count<TAB>field<TAB>value`, rarest first
# Exit codes:
#   0  success
#   1  usage error, CLI failure, or no document found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COUNT="$SCRIPT_DIR/onyphe-count.sh"

# The curated pivot set. Hashes and fingerprints first (operator artefacts),
# then the contextual fields that are expected to come back broad and are kept
# precisely so the broad/narrow split is visible in one table.
#
# JA4S, JA4T, JARM, domhash and ssdeep are deliberately absent. They exist in
# the ctiscan schema but carry no data: -exists: returns 0 for each of them over
# a one-month window, where ja3s.fingerprint.md5 returns 581816163 (measured
# 2026-09-25). Listing an empty field as a pivot invites a hunt built on a
# signal that can never match.
DEFAULT_FIELDS="cert.fingerprint.md5,cert.fingerprint.sha256,cert.serial.hex,\
ja3s.fingerprint.md5,\
tcp.fingerprint.md5,\
app.data.md5,app.data.sha256,\
http.header.data.md5,http.header.data.sha256,\
http.body.data.md5,http.body.data.sha256,\
favicon.data.md5,favicon.data.mmh3,\
hhhash.fingerprint.md5,hhhash.fingerprint.sha256,\
ssh.fingerprint.md5,ssh.fingerprint.sha256,hassh.fingerprint.md5,\
http.header.etag,http.header.server,\
cert.subject.cn,cert.issuer.cn,\
component.text,entity.text,ip.asn,ip.organization"

usage() {
   cat >&2 <<'USAGE'
Usage: onyphe-rarity.sh <ip> [--category <list>] [--window <fn>] [--fields <list>] [--dry-run]
       onyphe-rarity.sh --file <doc.ndjson> [...]

Builds a rarity table for one host's pivotable attributes.

  onyphe-rarity.sh 203.0.113.10
  onyphe-rarity.sh 203.0.113.10 --window -weekago:1
  onyphe-rarity.sh --file data/host.ndjson --dry-run
  onyphe-rarity.sh 203.0.113.10 --category ctiurl

--category takes ctiscan (default), ctiurl, or ctiscan,ctiurl. Nothing else:
the seed pull keys on ip.dest and every default field is a ctiscan-model name,
so a datascan-model category would return 0 with no error - which in this
table is indistinguishable from a maximally rare attribute.

Run ctiscan and ctiurl as SEPARATE passes rather than pooling them. A rarity
band is a claim about a denominator, and the two corpora differ by roughly an
order of magnitude.

Reads rarest-first. Under ~5 documents is a candidate operator artefact worth
pivoting; over ~25 is shared infrastructure or a product default. Confirm a
candidate against a second, independent attribute before treating a cluster as
real, and run it through onyphe-hpcheck.sh before treating it as tradecraft.

Cost: one credit per distinct attribute value, plus one to pull the document.
USAGE
   exit 1
}

target=""
docfile=""
window="-dayago:1"
fields="$DEFAULT_FIELDS"
category="ctiscan"
dry_run=0

while [[ $# -gt 0 ]]; do
   case "$1" in
      --file)    docfile="${2:-}"; shift 2 ;;
      --window)  window="${2:-}";  shift 2 ;;
      --fields)  fields="${2:-}";  shift 2 ;;
      --category) category="${2:-}"; shift 2 ;;
      --dry-run) dry_run=1;        shift   ;;
      -h|--help) usage ;;
      -*)        echo "Unknown option: $1" >&2; usage ;;
      *)         target="$1";      shift   ;;
   esac
done

# Reject anything outside the ctiscan field model rather than letting it return
# a silent zero. See the --category note in the usage text.
case "$category" in
   ctiscan|ctiurl|ctiscan,ctiurl|ctiurl,ctiscan) ;;
   *) echo "Unsupported --category '$category': this script is ctiscan-model only (ip.dest seed, ctiscan field names)." >&2; exit 1 ;;
esac

[[ -z "$target" && -z "$docfile" ]] && usage
[[ -n "$target" && -n "$docfile" ]] && usage

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

if [[ -n "$docfile" ]]; then
   [[ -f "$docfile" ]] || { echo "No such file: $docfile" >&2; exit 1; }
   cp "$docfile" "$tmp"
else
   echo "[onyphe-rarity] pulling $category for $target" >&2
   onyphe -search "category:$category ip.dest:$target $window" -size 10 -maxpage 1 > "$tmp" 2>/dev/null || true
   if [[ ! -s "$tmp" ]]; then
      echo "No $category document for $target within $window." >&2
      echo "Widen the window, or confirm the IP was scanned at all:" >&2
      echo "  onyphe-count.sh 'category:$category ip.dest:$target -monthago:1'" >&2
      exit 1
   fi
fi

# Flatten every document to dotted keys and keep only the pivot fields.
#
# Known limitation: this does NOT explode arrays. paths(scalars) renders an
# array element as 'tag.0', 'tag.1', ... which never equals the bare field
# name, so array-valued fields are dropped rather than counted. In practice
# the loss is small - the array-valued fields here are tag-like, and tag
# rarity does not signal a relationship between hosts the way a key or hash
# does. Fixing it would also multiply the credit cost, so it needs its own
# change and its own cost estimate rather than riding along here.
IFS=',' read -r -a field_list <<< "$fields"
: > "$tmp.pairs"
for f in "${field_list[@]}"; do
   [[ -z "$f" ]] && continue
   jq -r --arg f "$f" '
      [paths(scalars) as $p | {k: ($p | join(".")), v: getpath($p)}]
      | map(select(.k == $f))
      | .[] | "\(.k)\t\(.v)"
   ' "$tmp" 2>/dev/null || true
done | sort -u > "$tmp.pairs"

n=$(wc -l < "$tmp.pairs" | tr -d ' ')

if [[ "$n" -eq 0 ]]; then
   echo "The document carries none of the requested pivot fields." >&2
   echo "Checked: $fields" >&2
   exit 1
fi

echo "[onyphe-rarity] $n distinct attribute values -> $n credits" >&2

while IFS=$'\t' read -r field value; do
   # Values containing a double quote cannot be quoted safely in OQL; skip
   # rather than emit a query that silently means something else.
   case "$value" in
      *'"'*) echo "[onyphe-rarity] skipping $field (value contains a quote)" >&2; continue ;;
   esac
   q="category:${category} ${field}:\"${value}\" ${window}"
   if [[ "$dry_run" -eq 1 ]]; then
      printf '?\t%s\t%s\n' "$field" "$value"
      echo "  $q" >&2
      continue
   fi
   c=$("$COUNT" "$q" 2>/dev/null) || c="ERR"
   printf '%s\t%s\t%s\n' "$c" "$field" "$value"
done < "$tmp.pairs" | sort -n -k1,1

rm -f "$tmp.pairs"
