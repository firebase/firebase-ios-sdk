#!/bin/bash
# Copyright 2023 Google LLC
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

set -euo pipefail

recursive_unminify_json() {
    target_dir="$1";
    pushd "$target_dir";
    find . -name "*.json" -print0 | while read -d $'\0' file
    do
        python3 -m json.tool "$file" "$file";
    done
    popd;
}

recursive_unminify_json $1;
recursive_unminify_json $2;

# git diff exits with a non-zero code when a diff is present,
# which we want to ignore.
set +euo pipefail

git diff --no-index "$1" "$2";

exit 0;
