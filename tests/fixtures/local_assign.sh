#!/bin/bash
# fixture: local_assign.sh
# expect: no violations
# rule: local x=value is NOT a smell

init() {
  local count=0
  local name="default"
  local -r max=100
  local -i timeout=30
  local a=1 b=2 c=3
  echo "$count $name $max $timeout $a $b $c"
}
