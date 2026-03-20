# Rule codes
_R_GLOBAL_WRITE="VL01"
_R_GLOBAL_READ="VL02"
_R_DYNAMIC_EVAL="VL03"
_R_INDIRECT_EXP="VL04"
_R_DYNAMIC_SRC="VL05"
_R_SIDE_EFFECT="VL06"

# Special shell variables that are always allowed (never flagged)
_VARLINT_SPECIAL=" BASH BASH_VERSION BASH_VERSINFO BASH_SOURCE BASH_LINENO \
BASH_ARGC BASH_ARGV BASH_COMMAND BASH_SUBSHELL BASH_REMATCH BASH_COMPAT \
IFS PS1 PS2 PS3 PS4 PWD OLDPWD HOME PATH SHELL TERM COLUMNS LINES \
RANDOM SECONDS LINENO HISTSIZE HISTFILE OPTERR OPTIND OPTARG REPLY \
PIPESTATUS FUNCNAME GROUPS DIRSTACK EUID UID GID PPID \
OSTYPE MACHTYPE HOSTTYPE HOSTNAME SHELLOPTS BASHOPTS \
LANG LANGUAGE LC_ALL LC_COLLATE LC_CTYPE LC_MESSAGES LC_NUMERIC LC_TIME \
TMOUT TIMEFORMAT SHLVL DISPLAY "

_varlint_is_special() {
  local var="$1"
  # Positional params and special params
  case "$var" in
    [0-9]|[0-9][0-9]|'@'|'*'|'#'|'?'|'$'|'!'|'-'|'_') return 0 ;;
  esac
  [[ "$_VARLINT_SPECIAL" == *" $var "* ]]
}

_varlint_is_local() {
  local var="$1"
  local locals="$2"
  [[ " $locals " == *" $var "* ]]
}

# Check if a rule is disabled in a comma-separated list
_varlint_rule_off() {
  local rule="$1"
  local list="$2"
  [ -z "$list" ] && return 1
  [[ ",$list," == *",$rule,"* ]]
}

# Emit a violation unless suppressed
_varlint_emit() {
  local code="$1" rule="$2" severity="$3" file="$4" line_num="$5"
  local message="$6" hint="$7"
  local global_off="$8" line_off="$9" allow="${10}" impure="${11}"

  # @impure suppresses everything
  [ "$impure" = "1" ] && return 0

  # @allow LIST suppresses specific rules
  _varlint_rule_off "$rule" "$allow" && return 0

  # varlint disable block / disable-line
  _varlint_rule_off "$rule" "$global_off" && return 0
  _varlint_rule_off "$rule" "$line_off" && return 0

  varlint_output_violation "$code" "$rule" "$severity" "$file" "$line_num" "$message" "$hint"
}

# Extract variable names from a "local" declaration line
# Handles: local x, local x=v, local x y, local x=v y=w, local -r x=v, local -ri x
_varlint_parse_local() {
  local decl="$1"
  # Remove "local" keyword
  decl="${decl#*local}"
  # Remove option flags like -r, -i, -a, -A, -n, -x (including combined like -ri)
  decl=$(printf '%s' "$decl" | sed 's/[[:space:]]*-[a-zA-Z]\+//g')
  # For each token, take the part before '='
  local result=""
  local token
  for token in $decl; do
    token="${token%%=*}"
    [[ "$token" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && result="$result $token"
  done
  printf '%s' "$result"
}

# Main analysis function
varlint_check_file() {
  local file="$1"

  if [ ! -f "$file" ]; then
    printf "error: file not found: %s\n" "$file" >&2
    return 1
  fi

  local line_num=0
  local in_func=0        # 0=global, 1=inside function
  local brace_depth=0
  local func_name=""
  local local_vars=""
  local global_off=""    # active varlint disable=... block
  local pending_ann=""   # annotation before next function: pure|allow:...|impure
  local func_pure=0
  local func_allow=""
  local func_impure=0

  while IFS= read -r line || [ -n "$line" ]; do
    line_num=$((line_num + 1))

    # Trim leading whitespace for easier matching
    local s="${line#"${line%%[![:space:]]*}"}"

    # ── varlint block comments (any state) ────────────────────────────────
    case "$s" in
      "# varlint enable"*)
        global_off=""
        continue ;;
      "# varlint disable="*)
        global_off="${s#*=}"
        continue ;;
      "# @pure"*)
        pending_ann="pure"
        continue ;;
      "# @allow "*)
        pending_ann="allow:${s#*@allow }"
        continue ;;
      "# @impure"*)
        pending_ann="impure"
        continue ;;
      "#"*)
        # Generic comment: skip (don't clear pending_ann so consecutive
        # annotation + comment + func still works)
        continue ;;
    esac

    # ── Per-line disable comment ───────────────────────────────────────────
    local line_off=""
    if [[ "$line" =~ \#[[:space:]]*varlint[[:space:]]+disable-line=([A-Za-z_,]+) ]]; then
      line_off="${BASH_REMATCH[1]}"
    fi

    # ── Outside function: look for function start ──────────────────────────
    if [ "$in_func" -eq 0 ]; then
      local fname=""
      if [[ "$s" =~ ^([A-Za-z_][A-Za-z0-9_:.+-]*)[[:space:]]*\(\) ]]; then
        fname="${BASH_REMATCH[1]}"
      elif [[ "$s" =~ ^function[[:space:]]+([A-Za-z_][A-Za-z0-9_:.+-]*) ]]; then
        fname="${BASH_REMATCH[1]}"
      fi

      if [ -n "$fname" ]; then
        func_name="$fname"
        local_vars=""
        func_pure=0; func_allow=""; func_impure=0
        case "$pending_ann" in
          pure)    func_pure=1 ;;
          allow:*) func_allow="${pending_ann#allow:}" ;;
          impure)  func_impure=1 ;;
        esac
        pending_ann=""

        # Count braces on the function definition line itself
        local opens closes
        opens=$(printf '%s' "$line" | tr -cd '{' | wc -c)
        closes=$(printf '%s' "$line" | tr -cd '}' | wc -c)
        brace_depth=$((opens - closes))

        if [ "$brace_depth" -gt 0 ]; then
          in_func=1
        fi
        # If brace_depth <= 0: { not on this line yet, wait for next line
        continue
      fi

      pending_ann=""

      # Still outside function: wait for opening { if brace_depth is 0
      # (handles "foo()\n{" style)
      if [[ "$s" == "{"* ]]; then
        brace_depth=1
        in_func=1
      fi
      continue
    fi

    # ── Inside function: track brace depth ────────────────────────────────
    local opens closes
    opens=$(printf '%s' "$line" | tr -cd '{' | wc -c)
    closes=$(printf '%s' "$line" | tr -cd '}' | wc -c)
    brace_depth=$((brace_depth + opens - closes))

    if [ "$brace_depth" -le 0 ]; then
      in_func=0
      func_name=""
      local_vars=""
      continue
    fi

    # Strip trailing comment for smell analysis
    local code
    code=$(printf '%s' "$line" | sed 's/[[:space:]]*#.*$//')

    # Severity for rules that depend on mode
    local sev_read="warning"
    local sev_side="warning"
    [ "${VARLINT_STRICT:-}" = "1" ]       && sev_read="error" && sev_side="error"
    [ "${VARLINT_ENFORCE_PURE:-}" = "1" ] && sev_read="error"
    [ "$func_pure" = "1" ]                && sev_read="error" && sev_side="error"

    # ── local declaration → register vars, not a smell ────────────────────
    if [[ "$code" =~ ^[[:space:]]*local[[:space:]] ]]; then
      local new_vars
      new_vars=$(_varlint_parse_local "$code")
      local_vars="$local_vars $new_vars"
      continue
    fi

    # ── DYNAMIC_EVAL ──────────────────────────────────────────────────────
    if [[ "$code" =~ (^|[[:space:]])eval[[:space:]] ]]; then
      _varlint_emit "$_R_DYNAMIC_EVAL" "DYNAMIC_EVAL" "error" \
        "$file" "$line_num" \
        "dynamic execution via eval in '$func_name'" \
        "avoid eval; restructure or annotate with @impure" \
        "$global_off" "$line_off" "$func_allow" "$func_impure"
    fi

    # ── INDIRECT_EXPANSION ────────────────────────────────────────────────
    if [[ "$code" =~ \$\{! ]]; then
      _varlint_emit "$_R_INDIRECT_EXP" "INDIRECT_EXPANSION" "error" \
        "$file" "$line_num" \
        "indirect expansion \${!var} in '$func_name'" \
        "pass value directly or use @allow INDIRECT_EXPANSION" \
        "$global_off" "$line_off" "$func_allow" "$func_impure"
    fi

    # ── DYNAMIC_SOURCE ────────────────────────────────────────────────────
    if [[ "$code" =~ ^[[:space:]]*(source|\.)[[:space:]].*\$ ]]; then
      _varlint_emit "$_R_DYNAMIC_SRC" "DYNAMIC_SOURCE" "error" \
        "$file" "$line_num" \
        "dynamic source with variable path in '$func_name'" \
        "use a fixed path or @allow DYNAMIC_SOURCE" \
        "$global_off" "$line_off" "$func_allow" "$func_impure"
    fi

    # ── SIDE_EFFECT_BUILTIN ───────────────────────────────────────────────
    if [[ "$code" =~ ^[[:space:]]*(cd|export|read)[[:space:]] ]] || \
       [[ "$code" =~ ^[[:space:]]*(cd|export|read)$ ]]; then
      local builtin="${BASH_REMATCH[1]}"
      _varlint_emit "$_R_SIDE_EFFECT" "SIDE_EFFECT_BUILTIN" "$sev_side" \
        "$file" "$line_num" \
        "side-effect builtin '$builtin' in '$func_name'" \
        "avoid state-modifying builtins or annotate with @impure" \
        "$global_off" "$line_off" "$func_allow" "$func_impure"
    fi

    # ── GLOBAL_WRITE ─────────────────────────────────────────────────────
    # Pattern: VAR=... at start of line (not inside "local")
    if [[ "$code" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)= ]]; then
      local var="${BASH_REMATCH[1]}"
      if ! _varlint_is_local "$var" "$local_vars" && ! _varlint_is_special "$var"; then
        _varlint_emit "$_R_GLOBAL_WRITE" "GLOBAL_WRITE" "error" \
          "$file" "$line_num" \
          "variable '$var' assigned without local declaration in '$func_name'" \
          "add 'local $var' before the assignment, or annotate with @allow GLOBAL_WRITE" \
          "$global_off" "$line_off" "$func_allow" "$func_impure"
      fi
    fi

    # ── GLOBAL_READ ───────────────────────────────────────────────────────
    # Extract all $VAR and ${VAR} references from the line
    local var_refs
    var_refs=$(printf '%s' "$code" | grep -oE '\$\{?[A-Za-z_][A-Za-z0-9_]*' | sed 's/[${}]//g' | sort -u)

    local var
    while IFS= read -r var; do
      [ -z "$var" ] && continue
      _varlint_is_special "$var" && continue
      _varlint_is_local "$var" "$local_vars" && continue
      _varlint_emit "$_R_GLOBAL_READ" "GLOBAL_READ" "$sev_read" \
        "$file" "$line_num" \
        "variable '\$$var' read from global scope in '$func_name'" \
        "pass as argument or declare 'local $var', or annotate with @allow GLOBAL_READ" \
        "$global_off" "$line_off" "$func_allow" "$func_impure"
    done <<< "$var_refs"

  done < "$file"
}