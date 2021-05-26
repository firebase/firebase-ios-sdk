#!/bin/bash

oIFS=$IFS
output_file=$1
json_output="["
concatenate(){
  local path=$1
  shift
  IFS=","
  local lines=$@
  echo "{\"file\": \"${path}\", \"added_lines\": [${lines[*]}]}"
  IFS=$oIFS
}
diff-lines() {
    local path=
    local line=
    local lines=()
    while read; do
        esc='\033'
        if [[ "$REPLY" =~ ---\ (a/)?.* ]]; then
            continue
        elif [[ "$REPLY" =~ ^\+\+\+\ (b/)?([^[:blank:]$esc]+).* ]]; then
          if [ ${#lines[@]} -ne 0 ]; then
            json_output+="$(concatenate "${path}" ${lines[@]}),"
          fi
            lines=()
            path=${BASH_REMATCH[2]}
        elif [[ "$REPLY" =~ @@\ -[0-9]+(,[0-9]+)?\ \+([0-9]+)(,[0-9]+)?\ @@.* ]]; then
            line=${BASH_REMATCH[2]}
        elif [[ "$REPLY" =~ ^($esc\[[0-9;]+m)*([+]) ]]; then
            lines+=($line)
            ((line++))
        fi
    done
    json_output+=$(concatenate "${path}" ${lines[@]} )
}

diff-lines
json_output="${json_output}]"
echo $json_output > "${output_file}"

