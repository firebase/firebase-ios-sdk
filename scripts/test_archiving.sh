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


# USAGE: test_archiving.sh pod platform outputPath
#
# Generates the project for the given CocoaPod and attempts to archive it to the provided
# path.

set -xeuo pipefail

pod="$1"
platform="$2"
output_path="$3"

# watchOS is unsupported - `pod gen` can't generate the test schemes.
case "$platform" in
  ios)
  scheme_name="App-iOS"
  ;;

  macos)
  scheme_name="App-macOS"
  ;;

  tvos)
  scheme_name="App-tvOS"
  ;;

  # Fail for anything else, invalid input.
  *)
  exit 1;
  ;;
esac

bundle exec pod gen --local-sources=./ --sources=https://github.com/firebase/SpecsDev.git,https://github.com/firebase/SpecsStaging.git,https://cdn.cocoapods.org/ \
  "$pod".podspec --platforms="$platform"

args=(
  # Run the `archive` command.
  "archive"
  # Write the archive to a given path.
  "-archivePath" "$output_path"
  # The generated workspace.
  "-workspace" "gen/$pod/$pod.xcworkspace"
  # Specify the generated App scheme.
  "-scheme" "$scheme_name"
  # Disable signing.
  "CODE_SIGN_IDENTITY=-" "CODE_SIGNING_REQUIRED=NO" "CODE_SIGNING_ALLOWED=NO"
)

source scripts/buildcache.sh
args=("${args[@]}" "${buildcache_xcb_flags[@]}")

xcodebuild -version
xcodebuild "${args[@]}" | xcpretty

# Print the size if the Xcode build was successful.
if [ $? -eq 0 ]; then
  echo "Size of archive:"
  # Use `du` to print the file size of all .apps found. The `k` argument prints in KB.
  du -sk $(find "$output_path" -name "*.app")
fi
