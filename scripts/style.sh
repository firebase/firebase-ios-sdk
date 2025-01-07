#!/bin/bash

# Copyright 2017 Google LLC
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

# Usage:
# ./scripts/style.sh [branch-name | filenames]
#
# With no arguments, formats all eligible files in the repo
# Pass a branch name to format all eligible files changed since that branch
# Pass a specific file or directory name to format just files found there
#
# Commonly
# ./scripts/style.sh main

# Set the environment variable FIR_CLANG_FORMAT_PATH to use a specific version
# of clang-format, regardless of its order in the shell PATH.
#
# Example (add to ~/.bash_profile, ~/.zshrc or run in interactive shell):
#   FIR_CLANG_FORMAT_PATH="$(brew --prefix clang-format)/bin/clang-format"
#   export FIR_CLANG_FORMAT_PATH
if [[ -n "$FIR_CLANG_FORMAT_PATH" ]]; then
  clang_format_bin="$FIR_CLANG_FORMAT_PATH"
elif ! clang_format_bin=$(command -v clang-format); then
  echo "clang-format not found, install with 'brew install clang-format'"
  exit 1
fi

# Strip the clang-format version output down to the major version. Examples:
#   clang-format version 7.0.0 (tags/google/stable/2018-01-11)
#   clang-format version google3-trunk (trunk r333779)
version=$("$clang_format_bin" --version)

# Log the version in non-interactive use as it can be useful in travis logs.
if [[ ! -t 1 ]]; then
  echo "Clang-format Path: $clang_format_bin"
  echo "Clang-format Version: $version"
fi

# Remove leading "clang-format version"
version="${version/*version /}"
# Remove trailing parenthetical version details
version="${version/ (*)/}"
# Remove everything after the first dot (note this is a glob, not a regex)
version="${version/.*/}"

case "$version" in
  19)
    ;;
  google3-trunk)
    echo "Please use a publicly released clang-format; a recent LLVM release"
    echo "from http://releases.llvm.org/download.html will work."
    echo "Prepend to PATH when running style.sh."
    exit 1
    ;;
  *)
    echo "Please upgrade to clang-format version 19."
    echo "If it's installed via homebrew you can run:"
    echo "brew upgrade clang-format"
    exit 1
    ;;
esac

# Ensure that tools in `Mintfile` are installed locally to avoid permissions
# problems that would otherwise arise from the default of installing in
# /usr/local.
export MINT_PATH=Mint

if ! which mint >/dev/null 2>&1; then
  echo "mint is not available, install with 'brew install mint'"
  exit 1
fi

system=$(uname -s)

# Joins the given arguments with the separator given as the first argument.
function join() {
  local IFS="$1"
  shift
  echo "$*"
}

clang_options=(-style=file)

# Swift formatting options for the repo should be configured in
# https://github.com/firebase/firebase-ios-sdk/blob/main/.swiftformat.
# These may be overridden with additional `.swiftformat` files in subdirectories.
swift_options=()

if [[ $# -gt 0 && "$1" == "test-only" ]]; then
  test_only=true
  clang_options+=(-output-replacements-xml)
  swift_options+=(--dryrun)
  shift
else
  test_only=false
  clang_options+=(-i)
fi

#TODO(#2223) - Find a way to handle spaces in filenames

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
# find . includes a leading "./" that git does not include
s%^./%%

# Build outputs
\%/Pods/% d
\%^build/% d
\%^Debug/% d
\%^Release/% d
\%^cmake-build-debug/% d
\%^.build/% d
\%^.swiftpm/% d

# pod gen output
\%^gen/% d

# FirestoreEncoder is under 'third_party' for licensing reasons but should be
# formatted.
\%Firestore/third_party/FirestoreEncoder/.*\.swift% p

# Sources controlled outside this tree
\%/third_party/% d

# Public headers for closed sourced FirebaseAnalytics
\%^(FirebaseAnalyticsWrapper)/% d

# Generated source
\%/Firestore/core/src/util/config.h% d

# Generated Code for Data Connect sample
\%/Examples/FriendlyFlix/app/FriendlyFlixSDK/% d

# Sources pulled in by travis bundler, with and without a leading slash
\%^/?vendor/bundle/% d

# Sources pulled in by the Mint package manager
\%^mint% d

# Auth Sample Objective-C does not format well
\%^(FirebaseAuth/Tests/Sample/Sample)/% d

# Keep Firebase.h indenting
\%^CoreOnly/Sources/Firebase.h% d

# Checked-in generated code
\%\.pb(objc|rpc)\.% d
\%\.pb\.% d
\%\.nanopb\.% d

# Format C-ish sources only
\%\.(h|m|mm|cc|swift)$% p
'
)

needs_formatting=false
for f in $files; do
  if [[ "${f: -6}" == '.swift' ]]; then
    if [[ "$system" == 'Darwin' ]]; then
      # Match output that says:
      # 1/1 files would have been formatted.  (with --dryrun)
      # 1/1 files formatted.                  (without --dryrun)
      mint run swiftformat "${swift_options[@]}" "$f" 2>&1 | grep '^1/1 files' > /dev/null
    else
      false
    fi
  else
    "$clang_format_bin" "${clang_options[@]}" "$f" | grep "<replacement " > /dev/null
  fi

  if [[ "$test_only" == true && $? -ne 1 ]]; then
    echo "$f needs formatting."
    needs_formatting=true
  fi
done

if [[ "$needs_formatting" == true ]]; then
  echo "Proposed commit is not style compliant."
  echo "Run scripts/style.sh and git add the result."
  exit 1
fi
