#!/usr/bin/env bash
# PreToolUse hook: warn before ASD, ASM or Discovery calls that behave unlike a search.
#
# Reads tool input JSON on stdin. Advisory checks:
#   1. -asd-dns-*: ONYPHE sends live DNS lookups for the input domains. Every other
#      -asd-* call reads existing data. Needs the user's go-ahead per run.
#   2. -asm-inventory-*: the ASM Inventory API changes tenant data and is not
#      covered by this package; -asm-inventory-delall removes the whole inventory.
#   3. -discovery with no -since: and no -fields:. A Discovery call returns whole
#      documents, one per matching ip:port per scan, so it can be large.
#   4. -ondemand-*: on-demand scanning is out of scope here.
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
  *-asd-dns-*)
    case "$COMMAND" in
      *--allow-live-dns*) ;;
      *)
        WARNINGS+=("[onyphe-skills] -asd-dns-* sends live DNS lookups from ONYPHE's side for the input domains. Every other -asd-* call reads existing data. Confirm with the user before running it, and only for domains they are authorised to assess.")
        ;;
    esac
    ;;
esac

case "$COMMAND" in
  *-asm-inventory-delall*)
    WARNINGS+=("[onyphe-skills] -asm-inventory-delall deletes the ENTIRE ASM inventory and cannot be undone. The ASM Inventory API is not covered by this package. Do not run it without explicit, specific instruction.")
    ;;
  *-asm-inventory-*)
    WARNINGS+=("[onyphe-skills] The ASM Inventory API (-asm-inventory-*) changes tenant data and is not covered by this package. Assessments here use a local inventory.txt with -discovery.")
    ;;
esac

case "$COMMAND" in
  *-ondemand-*)
    WARNINGS+=("[onyphe-skills] On-demand scanning (-ondemand-*) is out of scope for this package: it originates scans against third-party targets.")
    ;;
esac

case "$COMMAND" in
  *-discovery*)
    case "$COMMAND" in
      *-since:*|*-fields:*) ;;
      *)
        WARNINGS+=("[onyphe-skills] -discovery with neither -since: nor -fields:. It returns whole documents, one per matching ip:port, so it can be large. Project with -fields:ip,port,tag first, and validate the inventory with onyphe-inventory-check.sh (a malformed line returns unrelated documents, not an error).")
        ;;
    esac
    ;;
esac

[[ ${#WARNINGS[@]} -eq 0 ]] && exit 0

printf '%s\n' "${WARNINGS[@]}" | jq -Rs '{"systemMessage": .}'
exit 0
