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

# scripts/ai-infra/export_repo_skills.sh
#
# Exports AI skills from this repository to your global ~/.gemini/config/skills directory.
# This allows core team members to use repo-specific workflows across other projects.
#
# Usage:
#   ./scripts/ai-infra/export_repo_skills.sh [skill_name]
#
#   If [skill_name] is provided, only that specific skill is exported.
#   Otherwise, all skills in .agents/skills/ are exported.

set -e

GLOBAL_SKILLS_DIR="$HOME/.gemini/config/skills"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_SKILLS_DIR="$REPO_ROOT/.agents/skills"

if [ ! -d "$REPO_SKILLS_DIR" ]; then
  echo "Error: Could not find skills directory at $REPO_SKILLS_DIR"
  exit 1
fi

mkdir -p "$GLOBAL_SKILLS_DIR"

if [ -n "$1" ]; then
  # Selective export
  SKILL_NAME="$1"
  if [ ! -d "$REPO_SKILLS_DIR/$SKILL_NAME" ]; then
    echo "Error: Skill '$SKILL_NAME' not found in $REPO_SKILLS_DIR"
    exit 1
  fi

  echo "Exporting '$SKILL_NAME' to global skills directory..."
      rm -rf "${GLOBAL_SKILLS_DIR:?}/${SKILL_NAME:?}"
  cp -R "$REPO_SKILLS_DIR/$SKILL_NAME" "$GLOBAL_SKILLS_DIR/"
  echo "Successfully exported $SKILL_NAME."
else
  # Export all
  echo "Exporting all repo skills to global skills directory..."
  for SKILL_PATH in "$REPO_SKILLS_DIR"/*; do
    if [ -d "$SKILL_PATH" ]; then
      SKILL_NAME="$(basename "$SKILL_PATH")"
      echo "  -> Exporting $SKILL_NAME"
          rm -rf "${GLOBAL_SKILLS_DIR:?}/${SKILL_NAME:?}"
      cp -R "$SKILL_PATH" "$GLOBAL_SKILLS_DIR/"
    fi
  done
  echo "Successfully exported all skills."
fi

# Clean up the old skills.json inheritance file if it exists,
# as we have shifted to a direct copy model for reliable re-exports.
if [ -f "$HOME/.gemini/config/skills.json" ]; then
  rm -f "$HOME/.gemini/config/skills.json"
fi
