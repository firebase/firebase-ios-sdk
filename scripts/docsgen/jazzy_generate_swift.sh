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

if [[ "$#" != 3 ]]
then
  echo -e "Usage: ./jazzy_generate.sh output_dir xcworkspace_path module_name"
  exit 1
fi

output_dir=$1
workspace_path=$2
module_name=$3

SWIFT_VERSION="$(xcrun swift -version | cut -d " " -f 4)"

jazzy \
  --clean \
  --author "Firebase" \
  --swift-version "${SWIFT_VERSION}" \
  --sdk iphonesimulator \
  --build-tool-arguments -workspace,"$workspace_path",-scheme,"$module_name" \
  --module "$module_name" \
  --output "$output_dir" \
  --swift-build-tool xcodebuild
