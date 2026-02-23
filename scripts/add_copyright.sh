#!/bin/bash

# Copyright 2024 Google LLC
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

# Add copyright notices to new source files in the current branch.

set -u

# Check if git is available.
if ! command -v git &> /dev/null; then
    echo "git command could not be found."
    exit 1
fi

# Move to the root of the repository to ensure paths are correct.
cd "$(git rev-parse --show-toplevel)"

# Define the base branch (defaulting to main).
BASE_BRANCH=${1:-main}

# Check if BASE_BRANCH exists.
if ! git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
    # Try origin/main if main doesn't exist locally
    if git rev-parse --verify "origin/$BASE_BRANCH" >/dev/null 2>&1; then
        BASE_BRANCH="origin/$BASE_BRANCH"
    else
        echo "Base branch '$BASE_BRANCH' not found. Please provide a valid branch name as an argument."
        exit 1
    fi
fi

echo "Checking for new files against $BASE_BRANCH..."

# Get list of added files.
# git diff --name-only --diff-filter=A returns paths relative to repo root.
# We compare the working directory against the merge base of the current branch and the base branch.
FILES=$(git diff --name-only --diff-filter=A $(git merge-base "$BASE_BRANCH" HEAD))

if [ -z "$FILES" ]; then
    echo "No new files found."
    exit 0
fi

YEAR=$(date +%Y)

# Iterate over files
echo "$FILES" | while read -r file; do
    if [ -z "$file" ]; then continue; fi
    if [ ! -f "$file" ]; then continue; fi

    # Determine extension
    filename=$(basename -- "$file")
    ext="${filename##*.}"

    # Special case for CMakeLists.txt
    if [ "$filename" == "CMakeLists.txt" ]; then
        ext="cmake"
    fi

    prefix=""
    case "$ext" in
        c|cc|cpp|h|hpp|js|m|mm|swift)
            prefix="//"
            ;;
        cmake|py|rb|sh|yml|yaml)
            prefix="#"
            ;;
        *)
            continue
            ;;
    esac

    # Check if file already has copyright.
    if grep -q "Copyright.*Google" "$file"; then
        continue
    fi

    echo "Adding copyright to $file"

    # Create temporary file
    tmp_file=$(mktemp)

    # Read first line to check for shebang
    first_line=$(head -n 1 "$file")

    has_shebang=false
    # Check if first line starts with #!
    if [[ "$first_line" =~ ^#! ]]; then
        has_shebang=true
        echo "$first_line" > "$tmp_file"
        echo "" >> "$tmp_file"
    fi

    # Append license
    cat <<EOF >> "$tmp_file"
${prefix} Copyright ${YEAR} Google LLC
${prefix}
${prefix} Licensed under the Apache License, Version 2.0 (the "License");
${prefix} you may not use this file except in compliance with the License.
${prefix} You may obtain a copy of the License at
${prefix}
${prefix}      http://www.apache.org/licenses/LICENSE-2.0
${prefix}
${prefix} Unless required by applicable law or agreed to in writing, software
${prefix} distributed under the License is distributed on an "AS IS" BASIS,
${prefix} WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
${prefix} See the License for the specific language governing permissions and
${prefix} limitations under the License.

EOF

    # Append rest of file
    if [ "$has_shebang" = true ]; then
        tail -n +2 "$file" >> "$tmp_file"
    else
        cat "$file" >> "$tmp_file"
    fi

    mv "$tmp_file" "$file"
done
