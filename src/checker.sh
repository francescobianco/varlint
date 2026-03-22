# Special shell variables that are always allowed (never flagged)
_VARLINT_SPECIAL=" BASH BASH_VERSION BASH_VERSINFO BASH_SOURCE BASH_LINENO \
BASH_ARGC BASH_ARGV BASH_COMMAND BASH_SUBSHELL BASH_REMATCH BASH_COMPAT \
IFS PS1 PS2 PS3 PS4 PWD OLDPWD HOME PATH SHELL TERM COLUMNS LINES \
RANDOM SECONDS LINENO HISTSIZE HISTFILE OPTERR OPTIND OPTARG REPLY \
PIPESTATUS FUNCNAME GROUPS DIRSTACK EUID UID GID PPID \
OSTYPE MACHTYPE HOSTTYPE HOSTNAME SHELLOPTS BASHOPTS \
LANG LANGUAGE LC_ALL LC_COLLATE LC_CTYPE LC_MESSAGES LC_NUMERIC LC_TIME \
TMOUT TIMEFORMAT SHLVL DISPLAY "

# @varlint allow=GLOBAL_READ
varlint_checker_is_special() {
  local var
  var="$1"
  case "$var" in
    [0-9]|[0-9][0-9]|'@'|'*'|'#'|'?'|'$'|'!'|'-'|'_') return 0 ;;
  esac
  [[ "$_VARLINT_SPECIAL" == *" $var "* ]]
}

varlint_checker_is_local() {
  local var
  local locals
  var="$1"
  locals="$2"
  [[ " $locals " == *" $var "* ]]
}

varlint_checker_rule_off() {
  local rule
  local list
  rule="$1"
  list="$2"
  [ -z "$list" ] && return 1
  [[ ",$list," == *",$rule,"* ]]
}

varlint_checker_emit() {
  local code
  local rule
  local severity
  local file
  local line_num
  local message
  local global_off
  local line_off
  local allow
  local impure
  local only
  code="$1"
  rule="$2"
  severity="$3"
  file="$4"
  line_num="$5"
  message="$6"
  global_off="$7"
  line_off="$8"
  allow="$9"
  impure="${10}"
  only="${11}"

  [ "$impure" = "1" ]                            && return 0
  varlint_checker_rule_off "$rule" "$allow"      && return 0
  varlint_checker_rule_off "$rule" "$global_off" && return 0
  varlint_checker_rule_off "$rule" "$line_off"   && return 0

  # --only filter: if set, show only the listed codes
  if [ -n "$only" ] && ! varlint_checker_rule_off "$code" "$only"; then
    return 0
  fi

  varlint_output_violation "$code" "$severity" "$file" "$line_num" "$message"
}

varlint_checker_parse_local() {
  local decl
  local after
  local stripped
  local result
  local token
  decl="$1"
  after="${decl#*local}"
  stripped=$(printf '%s' "$after" | sed 's/[[:space:]]*-[a-zA-Z]\+//g')
  result=""
  for token in $stripped; do
    token="${token%%=*}"
    [[ "$token" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && result="${result:+$result }$token"
  done
  printf '%s' "$result"
}

# Returns 0 if the local declaration has an inline value (has '=')
# Exception: -r flag (readonly must be assigned at declaration time)
varlint_checker_local_has_value() {
  local decl
  decl="$1"
  # readonly exception: local -r x=val is allowed
  [[ "$decl" =~ [[:space:]]-r([[:space:]]|$) ]] && return 1
  [[ "$decl" =~ = ]]
}

varlint_checker_check_file() {
  local file
  local strict
  local enforce_pure
  local only
  file="$1"
  strict="$2"
  enforce_pure="$3"
  only="$4"

  if [ ! -f "$file" ]; then
    printf "error: file not found: %s\n" "$file" >&2
    return 1
  fi

  local line_num
  local in_func
  local brace_depth
  local func_name
  local local_vars
  local global_off
  local pending_ann
  local func_pure
  local func_allow
  local func_impure
  local line
  line_num=0
  in_func=0
  brace_depth=0
  func_name=""
  local_vars=""
  global_off=""
  pending_ann=""
  func_pure=0
  func_allow=""
  func_impure=0
  line=""

  while IFS= read -r line || [ -n "$line" ]; do
    line_num=$((line_num + 1))

    local s
    s="${line#"${line%%[![:space:]]*}"}"

    # ── annotations and disable comments ──────────────────────────────────
    case "$s" in
      "# varlint enable"*)   global_off="";                          continue ;;
      "# varlint disable="*) global_off="${s#*=}";                   continue ;;
      "# @varlint pure"*)    pending_ann="pure";                     continue ;;
      "# @varlint allow="*)  pending_ann="allow:${s#*@varlint allow=}"; continue ;;
      "# @varlint impure"*)  pending_ann="impure";                   continue ;;
      "#"*)                                                           continue ;;
    esac

    local line_off
    line_off=""
    if [[ "$line" =~ \#[[:space:]]*varlint[[:space:]]+disable-line=([A-Za-z_,]+) ]]; then
      line_off="${BASH_REMATCH[1]}"
    fi

    # ── outside function: detect start ────────────────────────────────────
    if [ "$in_func" -eq 0 ]; then
      local fname
      fname=""
      if [[ "$s" =~ ^([A-Za-z_][A-Za-z0-9_:.+-]*)[[:space:]]*\(\) ]]; then
        fname="${BASH_REMATCH[1]}"
      elif [[ "$s" =~ ^function[[:space:]]+([A-Za-z_][A-Za-z0-9_:.+-]*) ]]; then
        fname="${BASH_REMATCH[1]}"
      fi

      if [ -n "$fname" ]; then
        func_name="$fname"
        local_vars=""
        func_pure=0
        func_allow=""
        func_impure=0
        case "$pending_ann" in
          pure)    func_pure=1 ;;
          allow:*) func_allow="${pending_ann#allow:}" ;;
          impure)  func_impure=1 ;;
        esac
        pending_ann=""

        local opens
        local closes
        opens=$(printf '%s' "$line" | tr -cd '{' | wc -c)
        closes=$(printf '%s' "$line" | tr -cd '}' | wc -c)
        brace_depth=$((opens - closes))
        [ "$brace_depth" -gt 0 ] && in_func=1
        continue
      fi

      pending_ann=""
      if [[ "$s" == "{"* ]]; then brace_depth=1; in_func=1; fi
      continue
    fi

    # ── inside function: track depth ──────────────────────────────────────
    local opens
    local closes
    opens=$(printf '%s' "$line" | tr -cd '{' | wc -c)
    closes=$(printf '%s' "$line" | tr -cd '}' | wc -c)
    brace_depth=$((brace_depth + opens - closes))

    if [ "$brace_depth" -le 0 ]; then
      in_func=0
      func_name=""
      local_vars=""
      continue
    fi

    local code
    code=$(printf '%s' "$line" | sed 's/[[:space:]]*#.*$//')

    local sev_read
    local sev_side
    sev_read="warning"
    sev_side="warning"
    [ "$strict" = "1" ]       && sev_read="error" && sev_side="error"
    [ "$enforce_pure" = "1" ] && sev_read="error"
    [ "$func_pure" = "1" ]    && sev_read="error" && sev_side="error"

    # ── local declaration ─────────────────────────────────────────────────
    if [[ "$code" =~ ^[[:space:]]*local[[:space:]] ]]; then
      local new_vars
      new_vars=$(varlint_checker_parse_local "$code")
      local_vars="$local_vars $new_vars"

      # VL07: inline value assignment in local declaration is a smell
      if varlint_checker_local_has_value "$code"; then
        varlint_checker_emit "VL07" "LOCAL_SPLIT" "warning" \
          "$file" "$line_num" \
          "inline value in 'local' declaration in '$func_name': use 'local $new_vars' then assign separately" \
          "$global_off" "$line_off" "$func_allow" "$func_impure" "$only"
      fi
      continue
    fi

    # ── VL03 DYNAMIC_EVAL ─────────────────────────────────────────────────
    if [[ "$code" =~ (^|[[:space:]])eval[[:space:]] ]]; then
      varlint_checker_emit "VL03" "DYNAMIC_EVAL" "error" \
        "$file" "$line_num" \
        "'eval' used in '$func_name': dynamic execution prevents static analysis" \
        "$global_off" "$line_off" "$func_allow" "$func_impure" "$only"
    fi

    # ── VL04 INDIRECT_EXPANSION ───────────────────────────────────────────
    if [[ "$code" =~ \$\{! ]]; then
      varlint_checker_emit "VL04" "INDIRECT_EXPANSION" "error" \
        "$file" "$line_num" \
        "indirect expansion used in '$func_name': not statically resolvable" \
        "$global_off" "$line_off" "$func_allow" "$func_impure" "$only"
    fi

    # ── VL05 DYNAMIC_SOURCE ───────────────────────────────────────────────
    if [[ "$code" =~ ^[[:space:]]*(source|\.)[[:space:]].*\$ ]]; then
      varlint_checker_emit "VL05" "DYNAMIC_SOURCE" "error" \
        "$file" "$line_num" \
        "dynamic source with variable path in '$func_name'" \
        "$global_off" "$line_off" "$func_allow" "$func_impure" "$only"
    fi

    # ── VL06 SIDE_EFFECT_BUILTIN ──────────────────────────────────────────
    if [[ "$code" =~ ^[[:space:]]*(cd|export|read)[[:space:]] ]] || \
       [[ "$code" =~ ^[[:space:]]*(cd|export|read)$ ]]; then
      local builtin
      builtin="${BASH_REMATCH[1]}"
      varlint_checker_emit "VL06" "SIDE_EFFECT_BUILTIN" "$sev_side" \
        "$file" "$line_num" \
        "side-effect builtin '$builtin' in '$func_name'" \
        "$global_off" "$line_off" "$func_allow" "$func_impure" "$only"
    fi

    # ── VL01 GLOBAL_WRITE ─────────────────────────────────────────────────
    if [[ "$code" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)= ]]; then
      local var
      var="${BASH_REMATCH[1]}"
      if ! varlint_checker_is_local "$var" "$local_vars" && ! varlint_checker_is_special "$var"; then
        varlint_checker_emit "VL01" "GLOBAL_WRITE" "error" \
          "$file" "$line_num" \
          "variable '$var' assigned without local in '$func_name'" \
          "$global_off" "$line_off" "$func_allow" "$func_impure" "$only"
      fi
    fi

    # ── VL02 GLOBAL_READ ──────────────────────────────────────────────────
    local var_refs
    var_refs=$(printf '%s' "$code" | grep -oE '\$\{?[A-Za-z_][A-Za-z0-9_]*' | sed 's/[${}]//g' | sort -u)

    local var
    while IFS= read -r var; do
      [ -z "$var" ] && continue
      varlint_checker_is_special "$var" && continue
      varlint_checker_is_local "$var" "$local_vars" && continue
      varlint_checker_emit "VL02" "GLOBAL_READ" "$sev_read" \
        "$file" "$line_num" \
        "variable '\$$var' read from global scope in '$func_name'" \
        "$global_off" "$line_off" "$func_allow" "$func_impure" "$only"
    done <<< "$var_refs"

  done < "$file"
}
