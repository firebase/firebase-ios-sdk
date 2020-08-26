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


# USAGE: test_archiving.sh pod outputPath
#
# Generates the project for the given CocoaPod and attempts to archive it to the provided
# path.

set -xeuo pipefail
pod="$1"
outputPath="$2"

bundle exec pod gen --local-sources=./ --sources=https://github.com/firebase/SpecsStaging.git,https://cdn.cocoapods.org/ \
  "$pod".podspec --platforms=ios

args=(
  # Run the `archive` command.
  "archive"
  # The generated workspace.
  "-workspace" "gen/$pod/$pod.xcworkspace"
  # Specify the generated App scheme.
  "-scheme" "App-iOS"
  # Disable signing.
  "CODE_SIGN_IDENTITY=-" "CODE_SIGNING_REQUIRED=NO" "CODE_SIGNING_ALLOWED=NO"
  # Write the archive to a given path.
  "-archivePath \"$outputPath\""
)

xcodebuild -version
xcodebuild "${args[@]}" | xcpretty
