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

# Fail if any source files contain Objective-C module @imports, excluding:
#   * Example sources
#   * Sample sources

options=(
  -n  # show line numbers
  -I  # exclude binary files
  '^@import'
)

function exit_with_error {
  echo "ERROR: @import statement found in the files above. Please use #import instead."
  exit 1
}

# SwiftPM needs module references.
git grep "${options[@]}" \
  -- ':(exclude,glob)**/Example/**' ':(exclude,glob)**/Sample/**' \
  ':(exclude,glob)FirebaseStorage/**' ':(exclude,glob)FirebaseAuth/**' \
  ':(exclude,glob)FirebaseCore/**' \
  ':(exclude)Firebase/Sources/Public/Firebase.h' && exit_with_error

# We need to explicitly exit 0, since we expect `git grep` to return an error
# if no @import calls are found.
exit 0
