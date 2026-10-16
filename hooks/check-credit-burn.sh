#!/usr/bin/env bash
# PreToolUse hook: warn before an ONYPHE call spends more than it looks like.
#
# Reads tool input JSON on stdin. Three advisory checks:
#   1. -search with no explicit -maxpage. The default lives in ~/.onyphe.ini,
#      which install.sh writes as api_maxpage = 1000, so a command that looks
#      like one query can page a thousand times.
#   2. -export with no -fields:. Export has no result ceiling; without a
#      projection every matching document comes back whole.
#   3. -search where -count would have scoped it first for a single credit.
#
# Exit 0 always. These are warnings, not blocks.

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

case "$COMMAND" in
  *onyphe*) ;;
  *) exit 0 ;;
esac

WARNINGS=()

case "$COMMAND" in
  *-search*)
    case "$COMMAND" in
      *-count*) ;;
      *)
        case "$COMMAND" in
          *-maxpage*) ;;
          *)
            WARNINGS+=("[onyphe-skills] -search without an explicit -maxpage: the page limit comes from ~/.onyphe.ini, which install.sh writes as api_maxpage = 1000. One command can spend up to 1000 credits. Pass -maxpage explicitly.")
            ;;
        esac
        case "$COMMAND" in
          *onyphe-count.sh*) ;;
          *)
            WARNINGS+=("[onyphe-skills] Scope before you pull: 'onyphe -count -search <OQL>' returns the exact total for one credit, and the number is not capped.")
            ;;
        esac
        ;;
    esac
    ;;
esac

case "$COMMAND" in
  *-export*)
    case "$COMMAND" in
      *-fields:*) ;;
      *)
        WARNINGS+=("[onyphe-skills] -export without -fields:. Export has no result ceiling, so an unprojected pull returns every matching document in full. Add -fields: to bound it.")
        ;;
    esac
    ;;
esac

[[ ${#WARNINGS[@]} -eq 0 ]] && exit 0

printf '%s\n' "${WARNINGS[@]}" | jq -Rs '{"systemMessage": .}'
exit 0
