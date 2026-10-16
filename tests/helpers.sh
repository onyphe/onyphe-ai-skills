# Shared assertions. Sourced by every test-*.sh, not executed.
# shellcheck shell=bash

pass=0
fail=0

assert_eq() {
   local label="$1" expected="$2" actual="$3"
   if [[ "$expected" == "$actual" ]]; then
      echo "  PASS: $label"
      pass=$((pass + 1))
   else
      echo "  FAIL: $label (expected '$expected', got '$actual')"
      fail=$((fail + 1))
   fi
}

assert_exit() {
   local label="$1" expected="$2" actual="$3"
   if [[ "$expected" -eq "$actual" ]]; then
      echo "  PASS: $label"
      pass=$((pass + 1))
   else
      echo "  FAIL: $label (expected exit $expected, got $actual)"
      fail=$((fail + 1))
   fi
}

assert_contains() {
   local label="$1" needle="$2" haystack="$3"
   if [[ "$haystack" == *"$needle"* ]]; then
      echo "  PASS: $label"
      pass=$((pass + 1))
   else
      echo "  FAIL: $label (expected to contain '$needle', got '$haystack')"
      fail=$((fail + 1))
   fi
}

assert_not_contains() {
   local label="$1" needle="$2" haystack="$3"
   if [[ "$haystack" != *"$needle"* ]]; then
      echo "  PASS: $label"
      pass=$((pass + 1))
   else
      echo "  FAIL: $label (expected NOT to contain '$needle', got '$haystack')"
      fail=$((fail + 1))
   fi
}

assert_empty() {
   local label="$1" actual="$2"
   if [[ -z "$actual" ]]; then
      echo "  PASS: $label"
      pass=$((pass + 1))
   else
      echo "  FAIL: $label (expected empty, got '$actual')"
      fail=$((fail + 1))
   fi
}

report() {
   echo "=== Results: $pass passed, $fail failed ==="
   [[ $fail -eq 0 ]] && exit 0 || exit 1
}
