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

# Builds FirebaseCore's Swift unit tests (CoreSwiftUnit) with ThreadSanitizer
# and runs them on macOS. Fails if a test fails or ThreadSanitizer reports a
# data race. Extra arguments are passed to `swift build`.
#
# `swift test --sanitize=thread` would build every test target in the
# package, so this builds only CoreSwiftUnit and runs it with xctest.

set -euo pipefail

cd "$(dirname "$0")/../.."

swift build --target CoreSwiftUnit --sanitize=thread "$@"
bin_path="$(swift build --target CoreSwiftUnit --sanitize=thread \
  --show-bin-path "$@" | tail -n 1)"
bundle="${bin_path}/CoreSwiftUnit.xctest"

# The test bundle doesn't load the ThreadSanitizer runtime early enough by
# itself, so insert it. SwiftPM may copy it into the bundle; otherwise use the
# toolchain's copy.
runtime="$(find "${bundle}" -name 'libclang_rt.tsan_osx_dynamic.dylib' \
  -print -quit)"
if [[ -z "${runtime}" ]]; then
  toolchain_lib="$(dirname "$(xcrun --find clang)")/../lib/clang"
  runtime="$(find "${toolchain_lib}" \
    -name 'libclang_rt.tsan_osx_dynamic.dylib' -print -quit)"
fi
if [[ -z "${runtime}" ]]; then
  echo "error: can't find the ThreadSanitizer runtime." >&2
  exit 1
fi

# Call xctest directly: the xcrun shim drops DYLD_* variables.
DYLD_INSERT_LIBRARIES="${runtime}" "$(xcrun --find xctest)" "${bundle}"
