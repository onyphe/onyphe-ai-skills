#!/usr/bin/env bash
# PreToolUse hook: catch a query written in the wrong field dialect.
#
# ctiscan/ctiurl and datascan are different data models. A datascan field name
# under category:ctiscan does not error - it returns exactly 0, silently, which
# reads as "nothing out there" rather than "wrong field name".
#
# Measured 2026-09-25 on a one-day ctiscan window, datascan name vs ctiscan
# native, same intent:
#
#   data:"Apache"      0  ->  app.data.text:"Apache"      7663474
#   cpe:"...apache..." 0  ->  component.cpe:"...apache..."  3063115
#   port:443           0  ->  tcp.dest:443               23194680
#   status:200         0  ->  http.code:200              33224626
#   protocol:http      0  ->  app.protocol:http         176146431
#   device.class:c2    0  ->  app.device:c2                  3411
#   app.http.title:... 0  ->  html.title.text:...           91744
#
# Model by category: ctiscan/ctiurl use the ctiscan model, every other category
# uses the datascan model. Fires in both directions. Exit 0 always; advisory, never a block.

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

case "$COMMAND" in
  *onyphe*) ;;
  *) exit 0 ;;
esac

# field-name-as-used : the equivalent in the other model
DATASCAN_TO_CTI="data:|app.data.text:
cpe:|component.cpe:
status:|http.code:
url:|http.url:
port:|tcp.dest: (single service) or services.port: (any open port on the host)
protocol:|app.protocol:
device.class:|app.device:
productversion:|component.version:
productvendor:|component.vendor:
app.http.title:|html.title.text: (full-text) or html.title.raw: (exact/regexp)
app.http.component.product:|component.product:
app.http.bodymd5:|http.body.data.md5:
app.http.headermd5:|http.header.data.md5:
datamd5:|app.data.md5:
app.favicon.imagemd5:|favicon.data.md5:"

CTI_TO_DATASCAN="app.data.text:|data:
component.cpe:|cpe:
http.code:|status:
http.url:|url:
tcp.dest:|port:
app.protocol:|protocol:
app.device:|device.class:
ip.dest:|ip:
html.title.text:|app.http.title:
component.product:|app.http.component.product:"

WARNINGS=()

check_dialect() {
   local label="$1" table="$2" right_model="$3" wrong_model="$4"
   while IFS='|' read -r bad good; do
      [[ -z "$bad" ]] && continue
      # Anchor the field name at a token boundary. Without this, 'port:' matches
      # inside the correct 'services.port:', 'url:' inside 'http.url:' and
      # 'protocol:' inside 'app.protocol:' - firing on queries that are already
      # right, which is worse than staying quiet.
      if grep -qE "(^|[[:space:]\"'(])$(printf '%s' "$bad" | sed 's/[.]/[.]/g')" <<< "$COMMAND"; then
         WARNINGS+=("[onyphe-skills] '$bad' is a $right_model field, but this query is $label ($wrong_model model). It will return 0 with no error. Use '$good' instead.")
      fi
   done <<< "$table"
}

# Model by category: ctiscan and ctiurl use the ctiscan model; every other
# category uses the datascan model.
if grep -qE "category:(ctiscan|ctiurl)" <<< "$COMMAND"; then
   check_dialect "category:ctiscan/ctiurl" "$DATASCAN_TO_CTI" datascan ctiscan
elif grep -qE "category:[a-z]+" <<< "$COMMAND"; then
   check_dialect "a non-ctiscan category" "$CTI_TO_DATASCAN" ctiscan datascan
fi

[[ ${#WARNINGS[@]} -eq 0 ]] && exit 0

{
   printf '%s\n' "${WARNINGS[@]}"
   echo "A zero result from a dialect mismatch is indistinguishable from a real absence. Re-check the field names before reporting 'nothing found'."
} | jq -Rs '{"systemMessage": .}'
exit 0
