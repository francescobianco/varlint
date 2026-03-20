#!/bin/bash
# fixture: clean.sh
# expect: no violations

# @pure
add() {
  local a="$1"
  local b="$2"
  echo $((a + b))
}

greet() {
  local name="$1"
  local greeting="Hello, $name!"
  echo "$greeting"
}

parse_args() {
  local input="$1"
  local result=0
  local flag=""
  local count=0
  local -r max=100

  if [ "$input" = "yes" ]; then
    result=1
  fi

  echo "$result $flag $count $max"
}
