#!/bin/bash

# Copyright 2018 Google
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
#

# From https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within

# USAGE: generate_project.sh [platform]
# platform is ios, macos, or tvos

platform="ios"
if [[ $# -gt 0 ]]; then
  platform="$1"
fi

echo $platform

readonly DIR="$(git rev-parse --show-toplevel)"

"$DIR/GoogleDataTransport/ProtoSupport/generate_cct_protos.sh" || echo "Something went wrong generating protos.";

pod gen "$DIR/GoogleDataTransport.podspec" --auto-open --local-sources=./ --gen-directory="$DIR/gen" --platforms=${platform} --clean
