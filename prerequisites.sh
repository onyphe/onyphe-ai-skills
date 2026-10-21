#!/usr/bin/env bash
# Check the prerequisites of the ONYPHE skills: the ONYPHE CLI, jq, and an API key.
#
# Nothing is installed without a typed confirmation, and nothing needs the
# network until you accept the CLI install. The CLI is cloned into a throwaway
# temporary directory that is removed on exit. The API key is never read,
# printed or copied: only the existence of ~/.onyphe.ini is checked.
#
# Usage: prerequisites.sh
#
# Exit codes:
#   0  everything present (CLI >= minimum version, jq, ~/.onyphe.ini)
#   1  something is missing or too old

set -euo pipefail

CLI_REPO="https://github.com/onyphe/cli.git"
CLI_MIN_VERSION="4.20.1"
CONTACT="contact@onyphe.io"
INI="$HOME/.onyphe.ini"

missing=0
tmpdir=""

cleanup() {
   [[ -n "$tmpdir" && -d "$tmpdir" ]] && rm -rf "$tmpdir"
   return 0
}
trap cleanup EXIT

say() { printf '%s\n' "$*"; }
ok() { printf '  [ok]      %s\n' "$*"; }
bad() { printf '  [missing] %s\n' "$*"; }

# Ask a yes/no question; default no. Non-interactive runs answer no.
confirm() {
   local answer
   [[ -t 0 ]] || return 1
   read -r -p "$1 [y/N] " answer
   [[ "$answer" =~ ^[Yy]$ ]]
}

# True when $1 >= $2 (dotted numeric versions).
version_ge() {
   [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

os_family() {
   local id=""
   if [[ -r /etc/os-release ]]; then
      id=$(. /etc/os-release && echo "${ID:-} ${ID_LIKE:-}")
   fi
   case "$(uname -s)" in
      Darwin) echo macos ;;
      *)
         case "$id" in
            *debian*|*ubuntu*|*kali*) echo debian ;;
            *rhel*|*fedora*|*centos*) echo redhat ;;
            *alpine*) echo alpine ;;
            *arch*) echo arch ;;
            *) echo other ;;
         esac
         ;;
   esac
}

# --- jq ---------------------------------------------------------------------

check_jq() {
   if command -v jq >/dev/null 2>&1; then
      ok "jq: $(jq --version)"
      return 0
   fi
   bad "jq is not installed (required by the helper scripts)"
   missing=1
   say "     Install it with:"
   case "$(os_family)" in
      debian) say "       sudo apt-get install jq" ;;
      redhat) say "       sudo dnf install jq" ;;
      alpine) say "       sudo apk add jq" ;;
      arch) say "       sudo pacman -S jq" ;;
      macos) say "       brew install jq" ;;
      *) say "       see https://jqlang.org/download/" ;;
   esac
}

# --- ONYPHE CLI -------------------------------------------------------------

print_cli_deps() {
   say "     The CLI is Perl and needs these modules first:"
   if [[ "$(os_family)" == "debian" ]]; then
      cat <<'DEPS'
       sudo apt-get install cpanminus libmojolicious-perl libtie-ixhash-perl \
          liblwp-protocol-https-perl libjson-xs-perl libfile-slurp-perl \
          libregexp-ipv6-perl libtext-csv-xs-perl
       sudo cpanm -n Config::INI::Tiny Text::ParseWords Net::IPv4Addr \
          Regexp::IPv4 Compress::Raw::Zlib
DEPS
   else
      cat <<'DEPS'
       (install cpanminus first)
       sudo cpanm -n Mojolicious Config::INI::Tiny Tie::IxHash \
          LWP::Protocol::https JSON::XS Text::ParseWords File::Slurp \
          Regexp::IPv4 Text::CSV_XS Net::IPv4Addr Regexp::IPv6 \
          Compress::Raw::Zlib
DEPS
   fi
}

install_cli() {
   command -v git >/dev/null 2>&1 || {
      say "     git is required to fetch the CLI; install it and run this script again."
      return 1
   }
   command -v perl >/dev/null 2>&1 || {
      say "     perl is required to build the CLI; install it and run this script again."
      return 1
   }
   tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/onyphe-cli.XXXXXX")
   say "     Cloning $CLI_REPO into $tmpdir"
   git clone --depth 1 "$CLI_REPO" "$tmpdir/cli" || return 1
   (
      cd "$tmpdir/cli"
      perl Build.PL
      ./Build
      ./Build test
      say "     './Build install' normally needs root."
      confirm "     Run 'sudo ./Build install' now?" || {
         say "     Skipped. The temporary clone is deleted on exit; run this script again to retry."
         exit 2
      }
      sudo ./Build install
   )
}

check_cli() {
   local version
   if command -v onyphe >/dev/null 2>&1; then
      version=$(onyphe -version 2>/dev/null | sed -n 's/^ONYPHE Version: *//p' | head -n1)
      if [[ -z "$version" ]]; then
         bad "onyphe is on PATH but 'onyphe -version' printed no version"
         missing=1
      elif version_ge "$version" "$CLI_MIN_VERSION"; then
         ok "onyphe CLI: $version (minimum $CLI_MIN_VERSION)"
         return 0
      else
         bad "onyphe CLI $version is older than $CLI_MIN_VERSION; update it from $CLI_REPO"
         missing=1
      fi
   else
      bad "onyphe CLI is not installed (source: ${CLI_REPO%.git})"
      missing=1
   fi

   print_cli_deps
   if confirm "     Clone the CLI into a temporary directory and build it now?"; then
      if install_cli && command -v onyphe >/dev/null 2>&1; then
         ok "onyphe CLI installed: $(onyphe -version 2>/dev/null | head -n1)"
         missing=0
      else
         say "     CLI install did not complete. Follow ${CLI_REPO%.git} by hand."
      fi
   else
      say "     Then, from a clone of $CLI_REPO:"
      say "       perl Build.PL && ./Build && ./Build test && sudo ./Build install"
   fi
}

# --- API key ----------------------------------------------------------------

check_key() {
   if [[ -f "$INI" ]]; then
      ok "$INI exists (contents not read; run scripts/onyphe-preflight.sh to test the key)"
      return 0
   fi
   bad "$INI not found"
   missing=1
   cat <<EOF
     An API key needs an ONYPHE subscription with API access. If you do not
     have one, contact $CONTACT.
     Once you have a key, create $INI containing:

       api_endpoint = https://www.onyphe.io/api/v2
       api_key = YOUR_KEY

     and restrict it:  chmod 600 $INI
     Never paste the key into a repository file.
EOF
}

say "Checking ONYPHE skills prerequisites"
check_jq
check_cli
check_key

say ""
if [[ $missing -eq 0 ]]; then
   say "All prerequisites are present. Next: ./scripts/onyphe-preflight.sh"
   exit 0
fi
say "Some prerequisites are missing. Fix them and run ./prerequisites.sh again."
exit 1
