# Quote-aware handling of a CLI argument that mixes OQL and an OPP pipeline.
# Sourced by the helper scripts, not executed.
#
# The onyphe CLI splits its argument at the first | outside a double-quoted
# span, so a regexp alternation such as ".*(a|b).*" stays in the OQL. These
# functions mirror that walk exactly: only " toggles the quoted state, and
# neither \" nor single quotes are special. Being cleverer than the CLI would
# make the helpers and the CLI disagree about where the OQL ends.
# shellcheck shell=bash

# Split $1 at the first unquoted |. Sets OQL_PART and OPP_PART, both trimmed;
# OPP_PART is empty when there is no pipeline.
oql_split() {
   local s="$1" c i quoted=0
   OQL_PART="$s"
   OPP_PART=""
   for ((i = 0; i < ${#s}; i++)); do
      c="${s:i:1}"
      [[ "$c" == '"' ]] && quoted=$((1 - quoted))
      if [[ $quoted -eq 0 && "$c" == "|" ]]; then
         OQL_PART="${s:0:i}"
         OPP_PART="${s:i+1}"
         break
      fi
   done
   OQL_PART="${OQL_PART#"${OQL_PART%%[![:space:]]*}"}"
   OQL_PART="${OQL_PART%"${OQL_PART##*[![:space:]]}"}"
   OPP_PART="${OPP_PART#"${OPP_PART%%[![:space:]]*}"}"
   OPP_PART="${OPP_PART%"${OPP_PART##*[![:space:]]}"}"
}

# Print $1 with every double-quoted span removed, quotes included, so a
# keyword search cannot match inside a value. An unclosed quote swallows the
# rest of the string, as it does in the CLI.
oql_unquoted() {
   local s="$1" c i quoted=0 out=""
   for ((i = 0; i < ${#s}; i++)); do
      c="${s:i:1}"
      if [[ "$c" == '"' ]]; then
         quoted=$((1 - quoted))
         continue
      fi
      [[ $quoted -eq 0 ]] && out+="$c"
   done
   printf '%s' "$out"
}

# True when $1 holds an even number of double quotes. With an odd number, the
# CLI reads everything after the last quote as quoted: a term appended to the
# end would never be parsed as OQL.
oql_quotes_balanced() {
   local q="${1//[^\"]/}"
   (( ${#q} % 2 == 0 ))
}
