#!/usr/bin/env bash
# Check the prerequisites of the ONYPHE skills: the ONYPHE CLI and its Perl
# modules, jq, and an API key.
#
# Nothing is installed without a typed confirmation, and nothing needs the
# network until you accept an install: first the CLI's missing Perl modules
# (apt-get/cpanm), then the CLI itself. The CLI is cloned into a throwaway
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
CLI_MIN_VERSION="4.20.2"
CONTACT="contact@onyphe.io"
INI="$HOME/.onyphe.ini"

missing=0
tmpdir=""

# Invoked through the EXIT trap below, which shellcheck does not follow.
# shellcheck disable=SC2317
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

# Non-core modules the CLI needs, from its Build.PL plus Module::Build to run
# it and Compress::Raw::Zlib from its README.
CLI_PERL_MODULES=(
   Module::Build Mojolicious Config::INI::Tiny Tie::IxHash
   LWP::Protocol::https JSON::XS Text::ParseWords File::Slurp
   Net::IPv4Addr Regexp::IPv4 Regexp::IPv6 Text::CSV_XS Net::IP
   Compress::Raw::Zlib
)

# Debian packages the modules where it can; the rest come from CPAN.
DEBIAN_APT_PACKAGES=(
   cpanminus libmodule-build-perl libmojolicious-perl libtie-ixhash-perl
   liblwp-protocol-https-perl libjson-xs-perl libfile-slurp-perl
   libregexp-ipv6-perl libtext-csv-xs-perl libnet-ip-perl
)
DEBIAN_CPAN_MODULES=(
   Config::INI::Tiny Text::ParseWords Net::IPv4Addr Regexp::IPv4
   Compress::Raw::Zlib
)

missing_perl_modules() {
   local module
   for module in "${CLI_PERL_MODULES[@]}"; do
      perl -M"$module" -e1 >/dev/null 2>&1 || printf '%s\n' "$module"
   done
}

# Report missing Perl modules and offer to install them.
# Returns 0 when none are missing afterwards.
check_cli_deps() {
   local -a absent
   command -v perl >/dev/null 2>&1 || {
      bad "perl is not installed (the CLI is written in Perl)"
      return 1
   }
   mapfile -t absent < <(missing_perl_modules)
   if [[ ${#absent[@]} -eq 0 ]]; then
      ok "Perl modules for the CLI: all ${#CLI_PERL_MODULES[@]} present"
      return 0
   fi
   bad "Perl modules for the CLI: ${absent[*]}"
   say "     Install them with:"
   if [[ "$(os_family)" == "debian" ]]; then
      say "       sudo apt-get install ${DEBIAN_APT_PACKAGES[*]}"
      say "       sudo cpanm -n ${DEBIAN_CPAN_MODULES[*]}"
   else
      say "       (install cpanminus first)"
      say "       sudo cpanm -n ${CLI_PERL_MODULES[*]}"
   fi
   confirm "     Run these commands now?" || return 1
   if [[ "$(os_family)" == "debian" ]]; then
      sudo apt-get install "${DEBIAN_APT_PACKAGES[@]}" || return 1
      sudo cpanm -n "${DEBIAN_CPAN_MODULES[@]}" || return 1
   else
      command -v cpanm >/dev/null 2>&1 || {
         say "     cpanm is not installed; install cpanminus and run this script again."
         return 1
      }
      sudo cpanm -n "${CLI_PERL_MODULES[@]}" || return 1
   fi
   mapfile -t absent < <(missing_perl_modules)
   if [[ ${#absent[@]} -gt 0 ]]; then
      bad "Perl modules still missing: ${absent[*]}"
      return 1
   fi
   ok "Perl modules for the CLI: installed"
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
      # Chained, because errexit does not apply when install_cli is called
      # as part of an && list.
      cd "$tmpdir/cli" && perl Build.PL && ./Build && ./Build test || exit 1
      say "     './Build install' normally needs root."
      confirm "     Run 'sudo ./Build install' now?" || {
         say "     Skipped. The temporary clone is deleted on exit; run this script again to retry."
         exit 2
      }
      sudo ./Build install || exit 1
   )
}

cli_version() {
   command -v onyphe >/dev/null 2>&1 || return 0
   onyphe -version 2>/dev/null | sed -n 's/^ONYPHE Version: *//p' | head -n1
}

check_cli() {
   local version missing_before_cli=$missing
   version=$(cli_version)
   if [[ -n "$version" ]] && version_ge "$version" "$CLI_MIN_VERSION"; then
      ok "onyphe CLI: $version (minimum $CLI_MIN_VERSION)"
      return 0
   fi
   missing=1
   if ! command -v onyphe >/dev/null 2>&1; then
      bad "onyphe CLI is not installed (source: ${CLI_REPO%.git})"
   elif [[ -z "$version" ]]; then
      bad "onyphe is on PATH but 'onyphe -version' printed no version (often a missing Perl module)"
   else
      bad "onyphe CLI $version is older than $CLI_MIN_VERSION; update it from $CLI_REPO"
   fi

   # Building without the modules only fails later, in './Build test'.
   check_cli_deps || {
      say "     Install the missing Perl modules, then run this script again to build the CLI."
      return 0
   }
   if confirm "     Clone the CLI into a temporary directory and build it now?"; then
      version=""
      install_cli && version=$(cli_version)
      if [[ -n "$version" ]] && version_ge "$version" "$CLI_MIN_VERSION"; then
         ok "onyphe CLI installed: $version"
         missing=$missing_before_cli
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
