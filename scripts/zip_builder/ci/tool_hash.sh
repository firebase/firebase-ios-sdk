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

# Prints the hash that names CI's framework cache directory for a build of zip-builder.
#
# Usage: tool_hash.sh [commit]   (default: HEAD)
#
# Fingerprints don't cover the tool's own code, so CI keeps a cache directory per tool build. Only
# the code that can change a built framework without changing its fingerprint counts: generating
# and building the project (Building/), how the model is written into it (Model/), and the
# XcodeProj version (Package.resolved). Everything else is already covered:
# - planning and customizing produce the plan, which every fingerprint hashes;
# - FrameworkCache.swift computes the fingerprints, so changing it changes the keys;
# - Layout.swift, packaging, verify, diff and the commands run after the cache.
# When code outside these paths starts to shape built frameworks, add it here.

set -euo pipefail

git ls-tree -r "${1:-HEAD}" -- \
  scripts/zip_builder/Package.resolved \
  scripts/zip_builder/Sources/ZipBuilder/Building \
  scripts/zip_builder/Sources/ZipBuilder/Model \
  | grep -v -e '/FrameworkCache\.swift$' -e '/Layout\.swift$' \
  | git hash-object --stdin | cut -c1-12
