module checker
module output

usage() {
  echo "Usage: varlint [OPTIONS] <file>..."
  echo ""
  echo "Options:"
  echo "  --strict              GLOBAL_READ and SIDE_EFFECT_BUILTIN become errors"
  echo "  --enforce-pure        Treat all functions as @pure"
  echo "  --only <codes>        Show only violations matching these codes (comma-separated)"
  echo "  --fail-on <rules>     Exit 1 if any of these rules fire (comma-separated)"
  echo "  --no-color            Disable colored output"
  echo "  -h, --help            Print this help and exit"
  echo "  -V, --version         Print version and exit"
  echo ""
  echo "Examples:"
  echo "  varlint script.sh"
  echo "  varlint --only VL07 script.sh"
  echo "  varlint --only VL01,VL02 lib/*.sh"
  echo "  varlint --strict lib/*.sh"
}

# @varlint allow=GLOBAL_READ
main() {
  local strict
  local enforce_pure
  local only
  local fail_on
  local no_color
  local files
  strict=""
  enforce_pure=""
  only=""
  fail_on=""
  no_color="${NO_COLOR:+1}"
  files=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --strict)       strict=1 ;;
      --enforce-pure) enforce_pure=1 ;;
      --only)         only="$2"; shift ;;
      --fail-on)      fail_on="$2"; shift ;;
      --no-color)     no_color=1 ;;
      -h|--help)      usage; exit 0 ;;
      -V|--version)   echo "varlint 0.1.0"; exit 0 ;;
      -*)
        printf "error: unknown option '%s'\n" "$1" >&2
        exit 1
        ;;
      *)
        if [[ "$1" == *'*'* ]] || [[ "$1" == *'?'* ]]; then
          local pattern
          local expanded
          pattern="$1"
          shopt -s globstar nullglob 2>/dev/null
          for expanded in $pattern; do
            [ -f "$expanded" ] && files+=("$expanded")
          done
          shopt -u globstar nullglob 2>/dev/null
        else
          files+=("$1")
        fi
        ;;
    esac
    shift
  done || true

  if [ "${#files[@]}" -eq 0 ]; then
    printf "error: no files specified\n" >&2
    usage >&2
    exit 1
  fi

  varlint_output_init "$no_color"

  local f
  for f in "${files[@]}"; do
    varlint_check_file "$f" "$strict" "$enforce_pure" "$only"
  done

  varlint_output_summary

  local exit_code
  exit_code=0
  if [ -n "$fail_on" ]; then
    [ "$VARLINT_ERROR_COUNT" -gt 0 ]   && exit_code=1
    [ "$VARLINT_WARNING_COUNT" -gt 0 ] && exit_code=1
  else
    [ "$VARLINT_ERROR_COUNT" -gt 0 ] && exit_code=1
  fi

  exit "$exit_code"
}
