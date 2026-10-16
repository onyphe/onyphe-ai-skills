#!/usr/bin/env bash
# Measure how much of a candidate indicator's population is honeypot.
#
# Roughly one ctiscan document in ten carries tag:honeypot, and the tagging is
# known to stop one port short of a very large emulator fleet - so `!tag:honeypot`
# alone is not a control population. This runs the four counts that separate a
# real signal from a deception artefact:
#
#   total   the candidate's whole population
#   tagged  of those, already tagged tag:honeypot
#   mp199   untagged, but sitting on services.count:199 - the fleet the tagging
#           misses, which is why it is counted separately rather than trusted
#   other   untagged and not on 199 - the genuinely new population
#
#   hpish = (tagged + mp199) / total
#
# A high hpish means the candidate is mostly re-finding known deception. A low
# hpish with a large `other` means it is finding something new - which is the
# point at which the residual still has to be profiled by hand (hosting-vs-
# consumer ASN mix, port plausibility) before anything is claimed.
#
# Silence is never a pass: a candidate with total 0 is inconclusive, not clean.
#
# Usage: onyphe-hpcheck.sh '<OQL fragment>' [--window <fn>] [--base '<OQL>']
#
# Output (stdout): TSV header + one row
# Exit codes:
#   0  success
#   1  usage error or CLI failure
#   2  total is 0 - the candidate matched nothing, result is inconclusive

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COUNT="$SCRIPT_DIR/onyphe-count.sh"

usage() {
   cat >&2 <<'USAGE'
Usage: onyphe-hpcheck.sh '<OQL fragment>' [--window <fn>] [--base '<OQL>']

Runs the four-count honeypot validation on a candidate indicator.

  onyphe-hpcheck.sh 'cert.issuer.cn:"Major Cobalt Strike"'
  onyphe-hpcheck.sh 'app.protocol:ssh app.data.text:"SSH-2.0-Paramiko"' --window -weekago:1

Columns: total tagged mp199 other tag% hpish%

  high hpish  -> mostly known deception, not a new finding
  low hpish   -> new population; profile the residual by ASN mix and port
                 plausibility before calling it tradecraft
  total 0     -> inconclusive. Not "clean".

Cost: four credits per candidate.
USAGE
   exit 1
}

[[ $# -lt 1 || -z "${1:-}" ]] && usage
[[ "$1" == "-h" || "$1" == "--help" ]] && usage

frag="$1"; shift
window="-dayago:1"
base="category:ctiscan"

while [[ $# -gt 0 ]]; do
   case "$1" in
      --window) window="${2:-}"; shift 2 ;;
      --base)   base="${2:-}";   shift 2 ;;
      -h|--help) usage ;;
      *) echo "Unknown option: $1" >&2; usage ;;
   esac
done

c() {
   "$COUNT" "$1" 2>/dev/null || echo "ERR"
}

total=$(c  "$base $frag $window")
tagged=$(c "$base $frag $window tag:honeypot")
mp199=$(c  "$base $frag $window !tag:honeypot services.count:199")
other=$(c  "$base $frag $window !tag:honeypot !services.count:199")

for v in "$total" "$tagged" "$mp199" "$other"; do
   if [[ "$v" == "ERR" ]]; then
      echo "One or more counts failed. Re-run the fragment through onyphe-count.sh to see the error." >&2
      exit 1
   fi
done

printf 'total\ttagged\tmp199\tother\ttag%%\thpish%%\n'

if [[ "$total" -eq 0 ]]; then
   printf '0\t0\t0\t0\tn/a\tn/a\n'
   echo "" >&2
   echo "total is 0: the candidate matched nothing in $window." >&2
   echo "This is inconclusive, not clean. Confirm the field is populated at all:" >&2
   echo "  onyphe-count.sh '$base -exists:<field> $window'" >&2
   exit 2
fi

awk -v t="$total" -v g="$tagged" -v m="$mp199" -v o="$other" 'BEGIN {
   printf "%d\t%d\t%d\t%d\t%.1f\t%.1f\n", t, g, m, o, (g*100.0)/t, ((g+m)*100.0)/t
}'
