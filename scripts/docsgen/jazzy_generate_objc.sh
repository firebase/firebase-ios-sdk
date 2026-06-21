#!/bin/bash

# Copyright 2024 Google LLC
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

set -ex

if [[ "$#" != 4 ]]
then
  echo -e "Usage: ./jazzy_generate.sh output_dir xcworkspace_path umbrella_header_path module_name"
  exit 1
fi

output_dir=$1
workspace_path=$2
umbrella_header_path=$3
module_name=$4

SWIFT_VERSION="$(xcrun swift -version | cut -d " " -f 4)"

# Generate temporary sourcekitten files.
mkdir -p "$output_dir"
sourcekitten \
  doc --objc "$umbrella_header_path" \
  -- -x objective-c  -isysroot "$(xcrun --show-sdk-path --sdk iphonesimulator)" \
  -I "$workspace_path" -fmodules > "$output_dir"/objcDoc.json

# Generates reference docs using jazzy
jazzy \
  --author "Firebase" \
  --module "$module_name" \
  --output "$output_dir" \
  --sourcekitten-sourcefile "$output_dir"/objcDoc.json
