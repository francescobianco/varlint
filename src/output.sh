_VARLINT_COLOR=1

# @varlint allow=GLOBAL_WRITE
varlint_output_init() {
  local no_color="$1"
  if [ "$no_color" = "1" ] || [ "${TERM:-}" = "dumb" ]; then
    _VARLINT_COLOR=0
  else
    _VARLINT_COLOR=1
  fi
}

# @varlint allow=GLOBAL_READ
_cc() { [ "$_VARLINT_COLOR" = "1" ] && printf '%b' "$1"; }

cc_reset()  { _cc '\033[0m'; }
cc_bold()   { _cc '\033[1m'; }
cc_red()    { _cc '\033[0;31m'; }
cc_yellow() { _cc '\033[0;33m'; }

VARLINT_ERROR_COUNT=0
VARLINT_WARNING_COUNT=0

# @varlint allow=GLOBAL_WRITE
varlint_output_violation() {
  local code="$1"
  local severity="$2"
  local file="$3"
  local line_num="$4"
  local message="$5"

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

# @varlint allow=GLOBAL_READ
varlint_output_summary() {
  if [ "$VARLINT_ERROR_COUNT" -eq 0 ] && [ "$VARLINT_WARNING_COUNT" -eq 0 ]; then
    printf "ok: no issues found\n"
  else
    printf "summary: %d error(s), %d warning(s)\n" \
      "$VARLINT_ERROR_COUNT" "$VARLINT_WARNING_COUNT"
  fi
}
