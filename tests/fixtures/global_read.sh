#!/bin/bash
# fixture: global_read.sh
# expect: VL02 GLOBAL_READ (line 5), VL02 GLOBAL_READ (line 11)

greet() {
  echo "Hello, $NAME"
}

build_path() {
  local prefix="$1"
  echo "${prefix}/${BASE_DIR}/bin"
}
