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

# Runs the Clang static analyzer on a Swift Package Manager scheme and fails if
# it reports warnings in the given repository paths.
#
# This replaces the `--analyze` step of `pod lib lint`: like it, the scheme is
# analyzed in the Release configuration, and remote package dependencies aren't
# analyzed. `xcodebuild analyze` exits with 0 even when the analyzer reports
# issues, so scripts/check_analyzer_results.py reads them from the result
# bundle and sets the exit code.
#
# Usage:
#   scripts/spm_analyze.sh SCHEME PLATFORM [PATH_PREFIX ...]
#
# SCHEME is a library product scheme (for example `FirebaseMessaging`) or a
# test scheme from scripts/spm_test_schemes whose build action analyzes the
# library. PLATFORM is one of iOS, tvOS, macOS, watchOS, catalyst, visionOS.
# PATH_PREFIX limits reported warnings to those repository paths, for example
# `FirebaseMessaging/Sources`. Without it, warnings anywhere in the repository
# are reported.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 SCHEME PLATFORM [PATH_PREFIX ...]" 1>&2
  exit 2
fi

scheme="$1"
platform="$2"
shift 2

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$platform" in
  iOS)
    destination='generic/platform=iOS Simulator'
    ;;
  tvOS)
    destination='generic/platform=tvOS Simulator'
    ;;
  watchOS)
    destination='generic/platform=watchOS Simulator'
    ;;
  visionOS)
    destination='generic/platform=visionOS Simulator'
    ;;
  macOS)
    destination='generic/platform=macOS'
    ;;
  catalyst)
    destination='generic/platform=macOS,variant=Mac Catalyst'
    ;;
  *)
    echo "Unknown platform '$platform'" 1>&2
    exit 2
    ;;
esac

# Match the deployment targets that scripts/build.sh uses for SPM.
xcode_major=$(xcodebuild -version | sed -nE 's/^Xcode ([0-9]+).*/\1/p')
if [[ -z "$xcode_major" ]]; then
  echo "Couldn't determine the Xcode version from 'xcodebuild -version'." 1>&2
  exit 1
fi
if [[ "$xcode_major" -ge 27 ]]; then
  macosx_deployment_target="12.0"
  watchos_deployment_target="9.0"
else
  macosx_deployment_target="11.0"
  watchos_deployment_target="8.0"
fi

timestamp=$(date +%s)
result_bundle="xcresults/analyze-${scheme}-${platform}-${timestamp}.xcresult"
log_file="xcodebuild-analyze-${scheme}-${platform}.log"
mkdir -p xcresults

xcodebuild -version
echo "Analyzing $scheme for $platform"

# Don't pass CLANG_ANALYZER_OUTPUT=html: with it, analyzer results are written
# to HTML files only and are missing from the result bundle.
# There's no `clean` action, unlike `pod lib lint`: `xcodebuild clean` fails
# with a generic destination for test schemes such as ABTestingUnit, whose
# targets aren't built for running. CI always starts from a fresh checkout.
# Locally, delete the DerivedData folder to force a full re-analysis.
xcodebuild_status=0
xcodebuild analyze \
  -scheme "$scheme" \
  -destination "$destination" \
  -configuration Release \
  -resultBundlePath "$result_bundle" \
  IPHONEOS_DEPLOYMENT_TARGET=15.0 \
  TVOS_DEPLOYMENT_TARGET=15.0 \
  MACOSX_DEPLOYMENT_TARGET="$macosx_deployment_target" \
  WATCHOS_DEPLOYMENT_TARGET="$watchos_deployment_target" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  > "$log_file" 2>&1 || xcodebuild_status=$?

if [[ $xcodebuild_status -ne 0 ]]; then
  tail -n 100 "$log_file"
  echo "xcodebuild analyze exited with $xcodebuild_status" 1>&2
  exit "$xcodebuild_status"
fi

python3 "${scripts_dir}/check_analyzer_results.py" "$result_bundle" "$@"
