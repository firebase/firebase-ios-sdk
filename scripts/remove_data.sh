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

set -xe

SDK="$1"

if [[ -z "$SDK" ]]; then
  echo "Error: SDK name not provided." >&2
  echo "Usage: $0 <SDKName>" >&2
  exit 1
fi

DIR="${SDK}"

TARGET_DIR="quickstart-ios/${DIR}"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: Directory '$TARGET_DIR' not found." >&2
  echo "Please provide a valid SDK name." >&2
  exit 1
fi

rm -f "${TARGET_DIR}"/GoogleService-Info.plist
