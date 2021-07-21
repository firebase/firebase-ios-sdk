#!/bin/bash

# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# USAGE: git diff -U0 [base_commit] HEAD | get_diff_lines.sh
#
# This will generate a JSON output of changed files and their newly added
# lines.
oIFS=$IFS

json_output="["
# Concatenate files and line indices into a JSON file.
concatenate() {
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
        # Skip lines starting with "---". e.g. "--- a/.github/workflows/database.yml".
        # $REPLY, containing one line at a time, here and below are the default variable
        # of `read`.
        if [[ "$REPLY" =~ ---\ (a/)?.* ]]; then
            continue
        # Detect new changed files from `git diff`. e.g. "+++ b/.github/workflows/combine.yml".
        elif [[ "$REPLY" =~ ^\+\+\+\ (b/)?([^[:blank:]$esc]+).* ]]; then
          # Add the last changed file and its indices of added line to the output variable.
          if [ ${#lines[@]} -ne 0 ]; then
            json_output+="$(concatenate "${path}" ${lines[@]}),"
          fi
          # Refresh the array of line indices and file path for the new changed file.
            lines=()
            path=${BASH_REMATCH[2]}
        # Detect the started line index of a changed file, e.g. "@@ -53,0 +54,24 @@ jobs:" where "54" will be fetched.
        elif [[ "$REPLY" =~ @@\ -[0-9]+(,[0-9]+)?\ \+([0-9]+)(,[0-9]+)?\ @@.* ]]; then
            line=${BASH_REMATCH[2]}
        # Detect newly added lines. e.g. "+  storage-combine-integration:"
        elif [[ "$REPLY" =~ ^($esc\[[0-9;]+m)*([+]) ]]; then
            lines+=($line)
            ((line++))
        fi
    done
    json_output+=$(concatenate "${path}" ${lines[@]} )
}

diff-lines
json_output="${json_output}]"
echo $json_output
