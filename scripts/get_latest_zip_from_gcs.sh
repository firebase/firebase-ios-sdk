#!/bin/bash

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

set -x
set -eo pipefail

FRAMEWORK_ZIP="$1"
OUTPUT_DIR="$2"

gsutil cp "gs://ios-framework-zip/latest_commit_hash.txt" latest_commit_hash.txt
commit_hash="$(cat 'latest_commit_hash.txt')"
gsutil cp "gs://ios-framework-zip/Firebase-actions-dir-${commit_hash}.zip" "${FRAMEWORK_ZIP}"
mkdir "${OUTPUT_DIR}"
unzip "${FRAMEWORK_ZIP}" -d "${OUTPUT_DIR}"
find "${OUTPUT_DIR}" -name "*.zip" -maxdepth 3 -exec unzip -d "${OUTPUT_DIR}" {} +
