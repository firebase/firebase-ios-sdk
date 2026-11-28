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

# Runs FirebaseCore's Swift unit tests (CoreSwiftUnit) on macOS with
# ThreadSanitizer, through xcodebuild like the other Core CI jobs. Fails if a
# test fails or ThreadSanitizer reports a problem.
#
# Usage: run_tsan.sh [--derived-data-path PATH]
#                    [--cloned-source-packages-path PATH]
#                    [extra xcodebuild arguments...]
#
# `swift build --target CoreSwiftUnit` doesn't link the test bundle with
# SwiftPM's native build system, and `swift test` would build every test
# target in the package, so this uses xcodebuild and the CoreSwiftUnit scheme.

set -euo pipefail

cd "$(dirname "$0")/../.."

derived_data_path=".build/core-tsan"
xcodebuild_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --derived-data-path)
      derived_data_path="$2"
      shift 2
      ;;
    --cloned-source-packages-path)
      xcodebuild_args+=(-clonedSourcePackagesDirPath "$2")
      shift 2
      ;;
    *)
      xcodebuild_args+=("$1")
      shift
      ;;
  esac
done

# xcodebuild needs the CoreSwiftUnit scheme, which is kept out of .swiftpm (see
# scripts/setup_spm_tests.sh). Copy it if needed, and remove the copy after.
schemes=".swiftpm/xcode/xcshareddata/xcschemes"
scheme="${schemes}/CoreSwiftUnit.xcscheme"
if [[ ! -f "${scheme}" ]]; then
  mkdir -p "${schemes}"
  cp scripts/spm_test_schemes/CoreSwiftUnit.xcscheme "${scheme}"
  # rmdir only removes the directories if they're empty.
  trap 'rm -f "${scheme}"; rmdir "${schemes}" "${schemes%/*}" 2>/dev/null' EXIT
fi

log="$(mktemp -t core-tsan)"
status=0
xcodebuild test \
  -scheme CoreSwiftUnit \
  -destination platform=macOS \
  -enableThreadSanitizer YES \
  -derivedDataPath "${derived_data_path}" \
  -collect-test-diagnostics never \
  "${xcodebuild_args[@]+"${xcodebuild_args[@]}"}" 2>&1 | tee "${log}" ||
  status=$?

# A ThreadSanitizer report ends the test process, which xcodebuild reports as a
# failure. Check the log too, in case a report doesn't change the exit status.
if grep -qE '(WARNING|ERROR): ThreadSanitizer' "${log}"; then
  echo "error: ThreadSanitizer reported a problem:" >&2
  grep -E 'SUMMARY: ThreadSanitizer' "${log}" >&2 || true
  status=1
fi
rm -f "${log}"
exit "${status}"
