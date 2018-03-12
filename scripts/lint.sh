# Copyright 2018 Google
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

# Lints C++ files for conformance with the Google C++ style guide

options=(
    -z    # \0 terminate output
)

if [[ $# -gt 0 ]]; then
  # Interpret any command-line argument as a revision range
  command=(git diff --name-only)
  options+=("$@")

else
  # Default to operating on all files that match the pattern
  command=(git ls-files)
fi


"${command[@]}" "${options[@]}" \
    -- 'Firestore/core/**/*.'{h,cc} \
  | xargs -0 python scripts/cpplint.py --quiet
