#!/bin/bash
# fixture: clean.sh
# expect: no violations

# @varlint pure
add() {
  local a
  local b
  a="$1"
  b="$2"
  echo $((a + b))
}

greet() {
  local name
  local greeting
  name="$1"
  greeting="Hello, $name!"
  echo "$greeting"
}

parse_args() {
  local input
  local result
  local flag
  local count
  input="$1"
  result=0
  flag=""
  count=0

  if [ "$input" = "yes" ]; then
    result=1
  fi

  echo "$result $flag $count"
}
