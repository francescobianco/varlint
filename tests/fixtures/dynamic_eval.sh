#!/bin/bash
# fixture: dynamic_eval.sh
# expect: VL03 DYNAMIC_EVAL (line 5)

run_cmd() {
  eval "$1"
}
