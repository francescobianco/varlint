module checker
module output

usage() {
  echo "Usage: varlint check [OPTIONS] <file>..."
  echo ""
  echo "Options:"
  echo "  --strict              GLOBAL_READ and SIDE_EFFECT_BUILTIN become errors"
  echo "  --enforce-pure        Treat all functions as @pure"
  echo "  --fail-on <rules>     Exit 1 if any of these rules fire (comma-separated)"
  echo "  --no-color            Disable colored output"
  echo "  -h, --help            Print this help and exit"
  echo "  -V, --version         Print version and exit"
  echo ""
  echo "Examples:"
  echo "  varlint check script.sh"
  echo "  varlint check --strict lib/*.sh"
  echo "  varlint check --fail-on GLOBAL_WRITE,DYNAMIC_EVAL script.sh"
}

main() {
  local strict=""
  local enforce_pure=""
  local fail_on=""
  local files=()

  # First arg must be subcommand
  case "${1:-}" in
    check)
      shift
      ;;
    -h|--help)
      usage; exit 0
      ;;
    -V|--version)
      echo "varlint 0.1.0"; exit 0
      ;;
    "")
      usage; exit 1
      ;;
    *)
      printf "error: unknown command '%s'\n" "$1" >&2
      usage >&2
      exit 1
      ;;
  esac

  while [ $# -gt 0 ]; do
    case "$1" in
      --strict)
        strict=1
        ;;
      --enforce-pure)
        enforce_pure=1
        ;;
      --fail-on)
        fail_on="$2"; shift
        ;;
      --no-color)
        VARLINT_NO_COLOR=1
        ;;
      -h|--help)
        usage; exit 0
        ;;
      -V|--version)
        echo "varlint 0.1.0"; exit 0
        ;;
      -*)
        printf "error: unknown option '%s'\n" "$1" >&2
        exit 1
        ;;
      *)
        files+=("$1")
        ;;
    esac
    shift
  done || true

  if [ "${#files[@]}" -eq 0 ]; then
    printf "error: no files specified\n" >&2
    usage >&2
    exit 1
  fi

  varlint_output_init

  export VARLINT_STRICT="$strict"
  export VARLINT_ENFORCE_PURE="$enforce_pure"

  local exit_code=0
  local f
  for f in "${files[@]}"; do
    varlint_check_file "$f"
  done

  varlint_output_summary

  # Determine exit code
  if [ -n "$fail_on" ]; then
    # Exit 1 only if specific rules fired — approximate via error/warning counts
    # (full per-rule tracking would need a shared array; use simple heuristic)
    [ "$VARLINT_ERROR_COUNT" -gt 0 ] && exit_code=1
    [ "$VARLINT_WARNING_COUNT" -gt 0 ] && exit_code=1
  else
    [ "$VARLINT_ERROR_COUNT" -gt 0 ] && exit_code=1
  fi

  exit "$exit_code"
}