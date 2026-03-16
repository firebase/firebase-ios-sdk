#!/usr/bin/env bash

# Copyright 2025 Google LLC
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

# USAGE: ./repo.sh <subcommand> [args...]
#
# EXAMPLE: ./repo.sh tests decrypt --json ./scripts/secrets/AI.json
#
# Wraps around the local "repo" swift package, and facilitates calls to it.
# The main purpose of this is to make calling "repo" easier, as you typically
# need to call "swift run" with the package path.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -eq 0 ]]; then
  cat 1>&2 <<EOF
OVERVIEW: Small script for running repo commands.

 Repo commands live under the scripts/repo swift package.

USAGE: $0 <subcommand> [args...]
EOF
  exit 1
fi

swift run --package-path "${ROOT}/repo" "$@"
