_VARLINT_COLOR=1

varlint_output_init() {
  if [ -n "${NO_COLOR:-}" ] || [ "${TERM:-}" = "dumb" ] || [ "${VARLINT_NO_COLOR:-0}" = "1" ]; then
    _VARLINT_COLOR=0
  fi
}

_cc() { [ "$_VARLINT_COLOR" = "1" ] && printf '%b' "$1"; }

cc_reset()  { _cc '\033[0m'; }
cc_bold()   { _cc '\033[1m'; }
cc_red()    { _cc '\033[0;31m'; }
cc_yellow() { _cc '\033[0;33m'; }
cc_cyan()   { _cc '\033[0;36m'; }
cc_blue()   { _cc '\033[0;34m'; }

VARLINT_ERROR_COUNT=0
VARLINT_WARNING_COUNT=0

varlint_output_violation() {
  local code="$1"
  local rule="$2"
  local severity="$3"
  local file="$4"
  local line_num="$5"
  local message="$6"
  # hint ($7) reserved for future use

  if [ "$severity" = "error" ]; then
    VARLINT_ERROR_COUNT=$((VARLINT_ERROR_COUNT + 1))
    printf "%s:%s => $(cc_red)$(cc_bold)Error$(cc_reset): [%s] %s\n" \
      "$file" "$line_num" "$code" "$message"
  else
    VARLINT_WARNING_COUNT=$((VARLINT_WARNING_COUNT + 1))
    printf "%s:%s => $(cc_yellow)$(cc_bold)Warning$(cc_reset): [%s] %s\n" \
      "$file" "$line_num" "$code" "$message"
  fi
}

varlint_output_summary() {
  if [ "$VARLINT_ERROR_COUNT" -eq 0 ] && [ "$VARLINT_WARNING_COUNT" -eq 0 ]; then
    printf "$(cc_bold)$(cc_blue)ok$(cc_reset): no issues found\n"
  else
    printf "$(cc_bold)summary$(cc_reset): %d error(s), %d warning(s)\n" \
      "$VARLINT_ERROR_COUNT" "$VARLINT_WARNING_COUNT"
  fi
}