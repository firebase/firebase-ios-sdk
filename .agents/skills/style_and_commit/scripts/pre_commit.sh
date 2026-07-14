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
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# The directory where this pre_commit script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate the firebase-ios-sdk directory for shared scripts (style.sh, add_copyright.sh)
FIREBASE_SDK_DIR=""
FIREBASE_SDK_CONFIG_FILE="$HOME/.gemini/config/.firebase_sdk_path"

if [ -f "$REPO_ROOT/scripts/style.sh" ]; then
  FIREBASE_SDK_DIR="$REPO_ROOT"
elif [ -d "$HOME/Developer/firebase-ios-sdk" ] && [ -f "$HOME/Developer/firebase-ios-sdk/scripts/style.sh" ]; then
  FIREBASE_SDK_DIR="$HOME/Developer/firebase-ios-sdk"
elif [ -f "$FIREBASE_SDK_CONFIG_FILE" ] && SDK_PATH="$(cat "$FIREBASE_SDK_CONFIG_FILE")" && [ -f "$SDK_PATH/scripts/style.sh" ]; then
  FIREBASE_SDK_DIR="$SDK_PATH"
else
  echo "========================================"
  echo "Configuration Required"
  echo "========================================"
  echo "The style and copyright scripts are missing from this repository."
  echo "We need the path to your local 'firebase-ios-sdk' repository to proceed."

  if [ -t 0 ]; then
    # Try to grab tty in case we are deep in a hook
    read -r -p "Please enter the path to your firebase-ios-sdk repository: " INPUT_PATH < /dev/tty || true
    INPUT_PATH="${INPUT_PATH/#\~/$HOME}"
    if [ -z "$INPUT_PATH" ]; then
      echo "Error: Path cannot be empty."
      exit 1
    elif [ -d "$INPUT_PATH" ]; then
      ABS_PATH="$(cd "$INPUT_PATH" && pwd)"
      if [ -f "$ABS_PATH/scripts/style.sh" ]; then
        FIREBASE_SDK_DIR="$ABS_PATH"
        mkdir -p "$HOME/.gemini/config"
        echo "$FIREBASE_SDK_DIR" > "$FIREBASE_SDK_CONFIG_FILE"
        echo "Saved path to $FIREBASE_SDK_CONFIG_FILE for future use."
      else
        echo "Error: Could not find scripts/style.sh in '$INPUT_PATH'."
        exit 1
      fi
    else
      echo "Error: '$INPUT_PATH' is not a valid directory."
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
ALL_MODIFIED=()
while IFS= read -r -d $'\0' file; do
  [[ -n "$file" && -f "$file" ]] && ALL_MODIFIED+=("$file")
done < <({ git diff -z --name-only --cached --diff-filter=ACMR 2>/dev/null || true; git diff -z --name-only --diff-filter=ACMR 2>/dev/null || true; } | perl -0 -ne 'print unless $seen{$_}++')

if [ ${#ALL_MODIFIED[@]} -eq 0 ]; then
  echo "No modified files to check. Exiting cleanly."
  exit 0
fi

echo "========================================"
echo "1. Styling code..."
echo "========================================"
# style.sh accepts a list of files/directories
bash "$FIREBASE_SDK_DIR/scripts/style.sh" "${ALL_MODIFIED[@]}"

echo "========================================"
echo "2. Checking and formatting copyrights..."
echo "========================================"
if [ -f "$FIREBASE_SDK_DIR/scripts/add_copyright.sh" ]; then
  # add_copyright.sh checks 'git diff --diff-filter=A' against a base branch.
  # By passing HEAD, we restrict it to only newly added files in the uncommitted working directory/staging area.
  bash "$FIREBASE_SDK_DIR/scripts/add_copyright.sh" HEAD
else
  echo "No scripts/add_copyright.sh found in $FIREBASE_SDK_DIR, skipping."
fi

echo "========================================"
echo "3. Formatting markdown..."
echo "========================================"
# Pass the modified files to the markdown formatter
bash "$SCRIPT_DIR/format_markdown.sh" "${ALL_MODIFIED[@]}"

echo "========================================"
echo "4. Linting shell scripts..."
echo "========================================"
if command -v shellcheck &> /dev/null; then
  SH_FILES=()
  for file in "${ALL_MODIFIED[@]}"; do
    if [[ "$file" == *.sh && -f "$file" ]]; then
      SH_FILES+=("$file")
    fi
  done
  if [ ${#SH_FILES[@]} -gt 0 ]; then
    echo "Running shellcheck on modified scripts..."
    shellcheck "${SH_FILES[@]}"
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
