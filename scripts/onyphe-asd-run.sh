#!/usr/bin/env bash
# Run one passive ASD pivot over a seed value or a file of seeds.
#
# Wraps `onyphe -asd-<tool>`. Differences from calling it by hand:
#   - an allow-list of passive tools; the -asd-dns-* family performs live DNS
#     lookups from ONYPHE's side and is refused unless --allow-live-dns is given
#   - ASD answers "no match" as HTTP 400, error 1006. The CLI prints that as an
#     ERROR line. It means an empty result, not a failure, so it exits 0 here
#   - anything shaped like an API key or ?k= query string is redacted before it
#     reaches your terminal, and output is de-duplicated
#
# Usage: onyphe-asd-run.sh [--allow-live-dns] <tool> <value|file>
#   onyphe-asd-run.sh web-subdomain-domain example.com
#   onyphe-asd-run.sh ip-domain domains.txt
#   onyphe-asd-run.sh --allow-live-dns dns-domain-ns example.com
#
# Exit codes: 0 ok (including empty), 1 API/CLI failure, 2 usage or refused tool

set -euo pipefail

PASSIVE="domain-tld domain-wildcard domain-certso domain-exist web-subdomain-domain \
certso-domain certso-wildcard ip-domain ip-certso org-inventory ip-inventory vhost-inventory"
LIVE_DNS="dns-domain-ns dns-domain-mx dns-domain-soa dns-domain-mstenantid dns-domain-exist dns-domain-ns-exist"

usage() {
   cat >&2 <<USAGE
Usage: onyphe-asd-run.sh [--allow-live-dns] <tool> <value|file>

Passive tools:   $PASSIVE
Live DNS tools:  $LIVE_DNS  (need --allow-live-dns)

A tool is the CLI flag without the -asd- prefix. Never calls anything else.
USAGE
   exit 2
}

allow_live=0
args=()
for a in "$@"; do
   case "$a" in
      --allow-live-dns) allow_live=1 ;;
      -h|--help) usage ;;
      *) args+=("$a") ;;
   esac
done

[[ ${#args[@]} -eq 2 ]] || usage
tool="${args[0]}"
input="${args[1]}"
[[ -n "$input" ]] || usage

in_list() { [[ " $2 " == *" $1 "* ]]; }

if in_list "$tool" "$LIVE_DNS"; then
   if [[ "$allow_live" -ne 1 ]]; then
      echo "Refused: -asd-$tool sends live DNS lookups from ONYPHE's side." >&2
      echo "Confirm with the user, then re-run with --allow-live-dns." >&2
      exit 2
   fi
elif ! in_list "$tool" "$PASSIVE"; then
   echo "Unknown or unsupported ASD tool: $tool" >&2
   usage
fi

stderr_file=$(mktemp)
trap 'rm -f "$stderr_file"' EXIT

redact() { sed -E 's/([?&]k=)[^&" ]+/\1REDACTED/g; s/(apikey|api_key|api_asd_key)[=: ]+[A-Za-z0-9._-]+/\1=REDACTED/gI'; }

rc=0
onyphe "-asd-$tool" "$input" 2>"$stderr_file" | redact | awk '!seen[$0]++' || rc=$?
err=$(redact < "$stderr_file")

if [[ -n "$err" ]]; then
   # 1006 is "search failed: no result found": an empty answer, not an error.
   if [[ "$err" == *1006* ]]; then
      echo "[onyphe-asd-run] no result (error 1006). Empty is not 'safe': it only means ASD found nothing for this input." >&2
      exit 0
   fi
   echo "$err" >&2
   exit 1
fi

exit "$rc"
