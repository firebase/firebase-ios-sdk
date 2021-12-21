#!/usr/bin/env bash

# Copyright 2020 Google LLC
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


# USAGE: test_catalyst.sh pod build_mode [scheme]
#
# Builds and run tests for Catalyst since it's not yet supported by
# `pod lib lint`.
# The second argument should be "build" or "test". "test" indicates both build
# and test.

# TODO - Determine why test specs that include `requires_app_host` fail to
# launch tests. Locally, they will pass if the only Objective C unit test scheme
# is specified. However, on GHA, they fail to launch both from the test scheme
# and the app scheme.

set -xeuo pipefail
pod="$1"
build_mode="$2"

if [[ $# -gt 2 ]]; then
  scheme="$3"
else
  scheme="$pod"
fi

bundle exec pod gen --local-sources=./ --sources=https://github.com/firebase/SpecsDev.git,https://github.com/firebase/SpecsStaging.git,https://cdn.cocoapods.org/ \
  "$pod".podspec --platforms=ios

args=(
  # Build or test.
  "$build_mode"
  # Tests that require NSAssert's to fire need Debug.
  "-configuration" "Debug"
  # The generated workspace.
  "-workspace" "gen/$pod/$pod.xcworkspace"
  # Specify the app if all test should run. Otherwise, specify the test scheme.
  "-scheme" "$scheme"
  # Specify Catalyst.
  "ARCHS=x86_64" "VALID_ARCHS=x86_64" "SUPPORTS_MACCATALYST=YES"
  # Run on macOS.
  "-sdk" "macosx" "-destination platform=\"OS X\"" "TARGETED_DEVICE_FAMILY=2"
  # Disable signing.
  "CODE_SIGN_IDENTITY=-" "CODE_SIGNING_REQUIRED=NO" "CODE_SIGNING_ALLOWED=NO"
  # GHA is still running 10.15.
  "MACOSX_DEPLOYMENT_TARGET=10.15"
)

source scripts/buildcache.sh
args=("${args[@]}" "${buildcache_xcb_flags[@]}")

xcodebuild -version
xcodebuild "${args[@]}" | xcpretty
