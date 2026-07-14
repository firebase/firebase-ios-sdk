#!/bin/bash

# Copyright 2026 Google LLC
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

# scripts/ai-infra/pre_commit.sh
#
# Unified script to run all pre-commit formatting and linting tasks.
# Operates STRICTLY on modified/staged files to prevent PR scope creep.

set -e

# Operate on the repository where the command is invoked from
REPO_ROOT="$PWD"

# The directory where this pre_commit script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate the firebase-ios-sdk directory for shared scripts (style.sh, add_copyright.sh)
FIREBASE_SDK_DIR=""
FIREBASE_SDK_CONFIG_FILE="$HOME/.gemini/config/.firebase_sdk_path"

if [ -f "$REPO_ROOT/scripts/style.sh" ]; then
  FIREBASE_SDK_DIR="$REPO_ROOT"
elif [ -d "$HOME/Developer/firebase-ios-sdk" ] && [ -f "$HOME/Developer/firebase-ios-sdk/scripts/style.sh" ]; then
  FIREBASE_SDK_DIR="$HOME/Developer/firebase-ios-sdk"
elif [ -f "$FIREBASE_SDK_CONFIG_FILE" ] && [ -f "$(cat "$FIREBASE_SDK_CONFIG_FILE")/scripts/style.sh" ]; then
  FIREBASE_SDK_DIR="$(cat "$FIREBASE_SDK_CONFIG_FILE")"
else
  echo "========================================"
  echo "Configuration Required"
  echo "========================================"
  echo "The style and copyright scripts are missing from this repository."
  echo "We need the path to your local 'firebase-ios-sdk' repository to proceed."

  if [ -t 0 ]; then
    # Try to grab tty in case we are deep in a hook
    exec < /dev/tty || true
    read -r -p "Please enter the absolute path to your firebase-ios-sdk repository: " INPUT_PATH
    if [ -f "$INPUT_PATH/scripts/style.sh" ]; then
      FIREBASE_SDK_DIR="$INPUT_PATH"
      mkdir -p "$HOME/.gemini/config"
      echo "$FIREBASE_SDK_DIR" > "$FIREBASE_SDK_CONFIG_FILE"
      echo "Saved path to $FIREBASE_SDK_CONFIG_FILE for future use."
    else
      echo "Error: Could not find scripts/style.sh in '$INPUT_PATH'."
      exit 1
    fi
  else
    echo "Error: Non-interactive environment. Cannot prompt for firebase-ios-sdk path."
    echo "Please manually configure it by running:"
    echo "  mkdir -p $HOME/.gemini/config"
    echo "  echo \"/path/to/firebase-ios-sdk\" > $FIREBASE_SDK_CONFIG_FILE"
    exit 1
  fi
fi

# Gather all modified files (both staged and unstaged)
MODIFIED_FILES=$(git diff --name-only --cached --diff-filter=AM || true)
UNSTAGED_FILES=$(git diff --name-only --diff-filter=AM || true)
ALL_MODIFIED=$(printf "%s\n%s\n" "$MODIFIED_FILES" "$UNSTAGED_FILES" | sort -u | grep -v '^$')

if [ -z "$ALL_MODIFIED" ]; then
  echo "No modified files to check. Exiting cleanly."
  exit 0
fi

echo "========================================"
echo "1. Styling code..."
echo "========================================"
# style.sh accepts a list of files/directories
# shellcheck disable=SC2086
"$FIREBASE_SDK_DIR/scripts/style.sh" $ALL_MODIFIED

echo "========================================"
echo "2. Checking and formatting copyrights..."
echo "========================================"
if [ -x "$FIREBASE_SDK_DIR/scripts/add_copyright.sh" ]; then
  # add_copyright.sh checks 'git diff --diff-filter=A' against a base branch.
  # By passing HEAD, we restrict it to only newly added files in the uncommitted working directory/staging area.
  "$FIREBASE_SDK_DIR/scripts/add_copyright.sh" HEAD
else
  echo "No scripts/add_copyright.sh found in $FIREBASE_SDK_DIR, skipping."
fi

echo "========================================"
echo "3. Formatting markdown..."
echo "========================================"
# Pass the modified files to the markdown formatter
# shellcheck disable=SC2086
"$SCRIPT_DIR/format_markdown.sh" $ALL_MODIFIED

echo "========================================"
echo "4. Linting shell scripts..."
echo "========================================"
if command -v shellcheck &> /dev/null; then
  SH_FILES=$(echo "$ALL_MODIFIED" | grep '\.sh$' || true)
  if [ -n "$SH_FILES" ]; then
    echo "Running shellcheck on modified scripts..."
    echo "$SH_FILES" | xargs shellcheck
    echo "Shellcheck passed!"
  else
    echo "No modified shell scripts to lint."
  fi
else
  echo "shellcheck not installed, skipping shell linting."
fi

echo "========================================"
echo "All pre-commit checks passed successfully!"
echo "========================================"
