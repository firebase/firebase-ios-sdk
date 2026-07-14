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

# scripts/ai-infra/format_markdown.sh
#
# Removes trailing whitespace and checks 80-character limits.
# STRICTLY operates on the files passed as arguments to prevent PR scope creep.

FILES=("$@")
if [ ${#FILES[@]} -eq 0 ]; then
    echo "No files provided. Skipping markdown format."
    exit 0
fi

# Filter for existing .md files
MD_FILES=()
for file in "${FILES[@]}"; do
    if [[ "$file" == *.md && -f "$file" ]]; then
        MD_FILES+=("$file")
    fi
done

if [ ${#MD_FILES[@]} -eq 0 ]; then
    echo "No markdown files modified. Skipping."
    exit 0
fi

echo "Formatting markdown files (removing trailing whitespace)..."
for file in "${MD_FILES[@]}"; do
  perl -pi -e 's/[ \t]+$//' "$file"
done

echo "Checking for markdown lines exceeding 80 characters..."

# Native Python script to validate line lengths (ignoring code blocks, frontmatter, and links)
if ! python3 -c '
import sys, re

def check_file(filepath):
    has_error = False
    in_code_block = False
    in_frontmatter = False
    try:
        with open(filepath, "r", encoding="utf-8-sig") as f:
            for i, line in enumerate(f):
                line = line.rstrip()

                # Handle frontmatter
                if i == 0 and line == "---":
                    in_frontmatter = True
                    continue
                if in_frontmatter and line == "---":
                    in_frontmatter = False
                    continue
                if in_frontmatter:
                    continue

                if line.startswith("```"):
                    in_code_block = not in_code_block
                    continue
                if in_code_block:
                    continue

                # Ignore lines that are headers, contain http links, or are long paths
                if len(line) > 80 and not line.startswith("#") and not re.search(r"https?://|file://", line) and not line.startswith("[") and "|" not in line:
                    print(f"  {filepath}:{i+1}: Line exceeds 80 characters ({len(line)} chars)")
                    has_error = True
    except Exception as e:
        print(f"Could not read {filepath}: {e}")
        has_error = True
    return has_error

failed = False
for filepath in sys.argv[1:]:
    if check_file(filepath):
        failed = True

sys.exit(1 if failed else 0)
' "${MD_FILES[@]}"; then
    echo "Warning: Markdown files contain lines exceeding 80 characters."
    echo "This is just a warning, but please consider wrapping them."
fi

echo "Markdown checks passed."
