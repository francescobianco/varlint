#!/bin/bash
# fixture: annotations.sh
# expect: no violations (all suppressed by annotations)

# @varlint impure
update_state() {
  state=1
  eval "$cmd"
  cd /tmp
}

# @varlint allow=GLOBAL_READ
read_config() {
  echo "$CONFIG_FILE"
}

# @varlint pure
pure_fn() {
  local x
  x="$1"
  echo "$x"
}

# varlint disable=GLOBAL_WRITE
set_global() {
  RESULT=42
}
# varlint enable
