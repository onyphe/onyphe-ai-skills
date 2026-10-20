#!/usr/bin/env bash
# PreToolUse hook: catch OR / AND / NOT written as keywords in an OQL query.
#
# OQL has no boolean keywords. AND is implicit, '?field:v' is OR, '!field:v' is
# NOT. A literal OR is read as a field-name prefix and the API answers
# 'filter not allowed: ORdomain' (error 12), which agents misread as "OR is
# unsupported on this licence" and then give up on the query.
#
#   wrong:  category:datascan (domain:a.com OR domain:b.com)
#   right:  category:datascan ( ?domain:a.com ?domain:b.com )
#
# Only the query itself is inspected: single-quoted segments that name a
# category, up to the first '|' (the OPP pipeline starts there), with
# double-quoted values removed so a value such as "Smith OR Jones" is left alone.
# -orwildcard: / -orexists: never match, they have no whitespace-delimited OR.
# Exit 0 always; advisory, never a block.

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

case "$COMMAND" in
  *onyphe*) ;;
  *) exit 0 ;;
esac

HITS=$(printf '%s' "$COMMAND" | perl -0777 -ne '
   my %seen;
   while (/\x27([^\x27]*category:[^\x27]*)\x27/g) {
      my $q = $1;
      $q =~ s/"(?:[^"\\]|\\.)*"//g;      # drop quoted values
      $q =~ s/(?<!\|)\|(?!\|).*//s;      # drop the OPP pipeline (a lone |, not ||)
      while ($q =~ /(?:^|[\s(])(OR|AND|NOT|\|\||&&)(?=[\s)]|$)/g) {
         $seen{$1}++;
      }
   }
   print join(" ", sort keys %seen);
' 2>/dev/null || true)

[[ -z "$HITS" ]] && exit 0

{
   echo "[onyphe-skills] This query uses the keyword(s) '$HITS'. OQL has no OR/AND/NOT keyword: the API will fail with 'filter not allowed: ORdomain' (error 12). AND is implicit, '?field:value' is OR, '!field:value' is NOT, and groups need inner spaces: category:datascan ( ?domain:a.com ?domain:b.com ). For several patterns of one field use -orwildcard:FIELD,PATTERN / -notwildcard:FIELD,PATTERN. Rewrite the query; this is a syntax error, not a licence limit."
} | jq -Rs '{"systemMessage": .}'
exit 0
