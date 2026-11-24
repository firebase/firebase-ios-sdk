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

# Fails if loading the Swift package graph reports warnings for this package,
# such as "found N file(s) which are unhandled; explicitly declare them as
# resources or exclude from the target".
#
# SwiftPM reports these warnings when it loads the package graph, so
# `swift build` can show them in apps that depend on this package (#16012).
# The xcodebuild-based SPM CI jobs don't show them, so without this check they
# reach main unnoticed. See #9144.
#
# This check reports what SwiftPM reports, no more. For example, SwiftPM
# doesn't report unhandled files in C-family (Objective-C) targets.
#
# `swift build --print-manifest-job-graph` loads the whole package graph,
# including test targets, without compiling anything. It takes a few seconds
# once dependencies are resolved, so run it after `swift package resolve`.
#
# Usage: scripts/check_spm_warnings.sh

set -euo pipefail

top_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$top_dir"

# SwiftPM names the root package after its directory, in lowercase. Only fail
# on warnings about this package, not about its dependencies.
package_identity="$(basename "$top_dir" | tr '[:upper:]' '[:lower:]')"

log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

if ! swift build --print-manifest-job-graph > /dev/null 2> "$log_file"; then
  cat "$log_file" 1>&2
  echo "error: failed to load the Swift package graph." 1>&2
  exit 1
fi

# Matches package warnings, which are printed as "warning: '<package>': ...",
# and compiler warnings from Package.swift. Indented lines that follow a
# warning list the affected files.
warnings="$(
  awk -v prefix="warning: '${package_identity}':" '
    index($0, prefix) == 1 || /Package\.swift:[0-9]+:[0-9]+: warning:/ {
      printing = 1
      print
      next
    }
    printing && /^[[:space:]]/ { print; next }
    { printing = 0 }
  ' "$log_file"
)"

if [[ -n "$warnings" ]]; then
  echo "$warnings" 1>&2
  echo 1>&2
  echo "error: Swift Package Manager reported the warnings above for" \
    "'${package_identity}'." 1>&2
  echo "Fix them, usually by adding the files to the target's 'exclude' or" \
    "'resources' in Package.swift." 1>&2
  exit 1
fi

echo "No Swift Package Manager warnings for '${package_identity}'."
