#!/bin/bash
# fixture: global_write.sh
# expect: VL01 GLOBAL_WRITE (line 6), VL01 GLOBAL_WRITE (line 12)

set_counter() {
  counter=0
}

set_name() {
  local prefix="$1"
  name="${prefix}_value"
}
