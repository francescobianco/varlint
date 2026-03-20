#!/bin/bash
# fixture: side_effects.sh
# expect: VL06 SIDE_EFFECT_BUILTIN for cd, export, read (lines 5, 6, 7)

navigate() {
  cd /tmp
  export MY_VAR=1
  read input
  echo "$input"
}
