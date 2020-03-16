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
# Builds and run tests for Catalyst since it's not yet supported by `pod lib lint`
# The second argument should be "build" or "test". "test" indicates both build and test.

set -xeuo pipefail
pod="$1"
build_mode="$2"

if [[ $# -gt 2 ]]; then
  scheme="$3"
else
  scheme="$pod"
fi

bundle exec pod gen --local-sources=./ --sources=https://cdn.cocoapods.org/ "$pod".podspec --platforms=ios
xcodebuild $build_mode -configuration Debug -workspace "gen/$pod/$pod.xcworkspace"  -scheme "$pod"\
 ARCHS=x86_64h VALID_ARCHS=x86_64h ONLY_ACTIVE_ARCH=NO  SUPPORTS_MACCATALYST=YES  -sdk macosx \
 CODE_SIGN_IDENTITY=- SUPPORTS_UIKITFORMAC=YES CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
 -destination platform="OS X" TARGETED_DEVICE_FAMILY=2 | xcpretty
