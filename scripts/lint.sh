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

# Joins the given arguments with the separator given as the first argument.
function join() {
  local IFS="$1"
  shift
  echo "$*"
}

git_options=(
    -z    # \0 terminate output
)

objc_lint_filters=(
  # Objective-C uses #import and does not use header guards
  -build/header_guard

  # Inline definitions of Objective-C blocks confuse
  -readability/braces

  # C-style casts are acceptable in Objective-C++
  -readability/casting

  # Objective-C needs use type 'long' for interop between types like NSInteger
  # and printf-style functions.
  -runtime/int

  # cpplint is generally confused by Objective-C mixing with C++.
  #   * Objective-C method invocations in a for loop make it think its a
  #     range-for
  #   * Objective-C dictionary literals confuse brace spacing
  #   * Empty category declarations ("@interface Foo ()") look like function
  #     invocations
  -whitespace
)

objc_lint_options=(
  # cpplint normally excludes Objective-C++
  --extensions=h,m,mm

  # Objective-C style allows longer lines
  --linelength=100

  --filter=$(join , "${objc_lint_filters[@]}")
)

if [[ $# -gt 0 ]]; then
  # Interpret any command-line argument as a revision range
  command=(git diff --name-only --diff-filter=ACMR)
  git_options+=("$@")

else
  # Default to operating on all files that match the pattern
  command=(git ls-files)
fi

# Straight C++ files get regular cpplint
"${command[@]}" "${git_options[@]}" \
    -- 'Firestore/core/**/*.'{h,cc} \
  | xargs -0 python scripts/cpplint.py --quiet 2>&1
CPP_STATUS=$?

# Objective-C++ files get a looser cpplint
"${command[@]}" "${git_options[@]}" \
    -- 'Firestore/Source/**/*.'{h,m,mm} \
      'Firestore/Example/Tests/**/*.'{h,m,mm} \
      'Firestore/core/**/*.mm' \
  | xargs -0 python scripts/cpplint.py "${objc_lint_options[@]}" --quiet 2>&1
OBJC_STATUS=$?

if [[ $CPP_STATUS != 0 || $OBJC_STATUS != 0 ]]; then
  exit 1
fi
