_VARLINT_COLOR=1

# @varlint allow=GLOBAL_WRITE
varlint_output_init() {
  local no_color
  no_color="$1"
  if [ "$no_color" = "1" ] || [ "${TERM:-}" = "dumb" ]; then
    _VARLINT_COLOR=0
  else
    _VARLINT_COLOR=1
  fi
}

# @varlint allow=GLOBAL_READ
varlint_output_cc() {
  local seq
  seq="$1"
  [ "$_VARLINT_COLOR" = "1" ] && printf '%b' "$seq"
}

varlint_output_cc_reset()  { varlint_output_cc '\033[0m'; }
varlint_output_cc_bold()   { varlint_output_cc '\033[1m'; }
varlint_output_cc_red()    { varlint_output_cc '\033[0;31m'; }
varlint_output_cc_yellow() { varlint_output_cc '\033[0;33m'; }

VARLINT_ERROR_COUNT=0
VARLINT_WARNING_COUNT=0

# @varlint allow=GLOBAL_WRITE
varlint_output_violation() {
  local code
  local severity
  local file
  local line_num
  local message
  code="$1"
  severity="$2"
  file="$3"
  line_num="$4"
  message="$5"

  if [ "$severity" = "error" ]; then
    VARLINT_ERROR_COUNT=$((VARLINT_ERROR_COUNT + 1))
    printf "%s:%s => $(varlint_output_cc_red)$(varlint_output_cc_bold)Error$(varlint_output_cc_reset): [%s] %s\n" \
      "$file" "$line_num" "$code" "$message"
  else
    VARLINT_WARNING_COUNT=$((VARLINT_WARNING_COUNT + 1))
    printf "%s:%s => $(varlint_output_cc_yellow)$(varlint_output_cc_bold)Warning$(varlint_output_cc_reset): [%s] %s\n" \
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
