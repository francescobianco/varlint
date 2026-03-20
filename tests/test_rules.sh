#!/usr/bin/env bash
# tests/test_rules.sh — verify varlint rule detection against fixtures

set -euo pipefail

VARLINT="${VARLINT:-$(cd "$(dirname "$0")/.." && pwd)/target/debug/varlint}"
FIXTURES="$(cd "$(dirname "$0")" && pwd)/fixtures"

PASS=0
FAIL=0

pass() { printf "  PASS: %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  FAIL: %s\n" "$1"; FAIL=$((FAIL + 1)); }

assert_clean() {
  local fixture
  local label
  fixture="$1"
  label="${fixture##*/}"
  if "$VARLINT" "$fixture" > /dev/null 2>&1; then
    pass "$label: no violations"
  else
    fail "$label: expected no violations but got some"
  fi
}

assert_rule() {
  local fixture
  local rule
  local label
  local out
  fixture="$1"
  rule="$2"
  label="${fixture##*/}"
  out=$("$VARLINT" "$fixture" 2>&1 || true)
  if echo "$out" | grep -q "$rule"; then
    pass "$label: found $rule"
  else
    fail "$label: expected $rule but not found"
    printf "    output was:\n%s\n" "$out"
  fi
}

assert_not_rule() {
  local fixture
  local rule
  local label
  local out
  fixture="$1"
  rule="$2"
  label="${fixture##*/}"
  out=$("$VARLINT" "$fixture" 2>&1 || true)
  if ! echo "$out" | grep -q "$rule"; then
    pass "$label: $rule not present (correct)"
  else
    fail "$label: $rule should not appear but it did"
    printf "    output was:\n%s\n" "$out"
  fi
}

echo "--- test_rules.sh ---"

# clean.sh: no violations at all
assert_clean "$FIXTURES/clean.sh"

# local_assign.sh: local x=value must trigger VL07
assert_rule "$FIXTURES/local_assign.sh" "VL07"
# but bare locals + separate assignment must NOT trigger VL01
assert_not_rule "$FIXTURES/local_assign.sh" "VL01"

# global_write.sh: must detect VL01
assert_rule "$FIXTURES/global_write.sh" "VL01"

# global_read.sh: must detect VL02
assert_rule "$FIXTURES/global_read.sh" "VL02"

# dynamic_eval.sh: must detect VL03
assert_rule "$FIXTURES/dynamic_eval.sh" "VL03"

# side_effects.sh: must detect VL06
assert_rule "$FIXTURES/side_effects.sh" "VL06"

# annotations.sh: @impure and @allow suppress violations
assert_not_rule "$FIXTURES/annotations.sh" "VL01"
assert_not_rule "$FIXTURES/annotations.sh" "VL03"

# src/ must be clean (varlint passes its own rules)
assert_clean "$(dirname "$VARLINT")/../../src/checker.sh"
assert_clean "$(dirname "$VARLINT")/../../src/output.sh"
assert_clean "$(dirname "$VARLINT")/../../src/main.sh"

echo ""
printf "Results: %d passed, %d failed\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
