#!/usr/bin/env bash
# Run every test suite. One failing suite does not abort the rest.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failed_suites=()

for suite in "$SCRIPT_DIR"/test-*.sh; do
   [[ -e "$suite" ]] || continue
   name=$(basename "$suite")
   echo ""
   echo "############################################"
   echo "# $name"
   echo "############################################"
   set +e
   bash "$suite"
   rc=$?
   set -e
   [[ $rc -ne 0 ]] && failed_suites+=("$name")
done

echo ""
if [[ ${#failed_suites[@]} -eq 0 ]]; then
   echo "ALL SUITES PASSED"
   exit 0
fi
echo "FAILED SUITES: ${failed_suites[*]}"
exit 1
