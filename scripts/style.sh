#!/bin/bash

# Copyright 2017 Google
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Usage:
# ./scripts/style.sh [branch-name | filenames]
#
# With no arguments, formats all eligible files in the repo
# Pass a branch name to format all eligible files changed since that branch
# Pass a specific file or directory name to format just files found there
#
# Commonly
# ./scripts/style.sh master

if [[ $(clang-format --version) != **"version 6"** ]]; then
  echo "Please upgrade to clang-format version 6."
  echo "If it's installed via homebrew you can run: brew upgrade clang-format"
  exit 1
fi

if [[ $# -gt 0 && "$1" = "test-only" ]]; then
  test_only=true
  options="-output-replacements-xml"
  shift
else
  test_only=false
  options="-i"
fi

files=$(
(
  if [[ $# -gt 0 ]]; then
    if git rev-parse "$1" -- >& /dev/null; then
      # Argument was a branch name show files changed since that branch
      git diff --name-only --relative --diff-filter=ACMR "$1"
    else
      # Otherwise assume the passed things are files or directories
      find "$@" -type f
    fi
  else
    # Do everything by default
    find . -type f
  fi
) | sed -E -n '
# Build outputs
\%/Pods/% d
\%^./build/% d

# Sources controlled outside this tree
\%/third_party/% d
\%/Firestore/Port/% d

# Generated source
\%/Firestore/core/src/firebase/firestore/util/config.h% d

# Sources pulled in by travis bundler
\%/vendor/bundle/% d

# Sources within the tree that are not subject to formatting
\%^./(Example|Firebase)/(Auth|AuthSamples|Database|Messaging)/% d

# Checked-in generated code
\%\.pb(objc|rpc)\.% d

# Format C-ish sources only
\%\.(h|m|mm|cc)$% p
'
)
needs_formatting=false
for f in $files; do
  clang-format -style=file $options $f | grep "<replacement " > /dev/null
  if [[ "$test_only" = true && $? -ne 1 ]]; then
    echo "$f needs formatting."
    needs_formatting=true
  fi
done

if [[ "$needs_formatting" = true ]]; then
  echo "Proposed commit is not style compliant."
  echo "Run scripts/style.sh and git add the result."
  exit 1
fi
