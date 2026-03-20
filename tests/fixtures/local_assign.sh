#!/bin/bash
# fixture: local_assign.sh
# expect: VL07 for every local x=value (inline assignment is a smell)
# rule: local x=value is a smell — use "local x" then "x=value" on separate line

smell_func() {
  local count=0
  local name="world"
  local flag=""
  echo "$count $name $flag"
}

clean_func() {
  local count
  local name
  local flag
  count=0
  name="world"
  flag=""
  echo "$count $name $flag"
}
