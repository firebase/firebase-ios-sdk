#!/bin/bash

# Copyright 2020 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -x
GITHUB_HASH="$1"
FRAMEWORK_DIR="$2"
if [[ "${FRAMEWORK_DIR}" == "Fail" ]]
then
  echo "Zip build or gcloud setup might be failed."
  echo "The last zip workflow failed. Commit hash: ${GITHUB_HASH}" > latest_commit_hash.txt
  gsutil cp latest_commit_hash.txt "gs://ios-framework-zip/latest_commit_hash.txt"
else
  echo "Commit Hash: ${GITHUB_HASH}"
  zip -r Firebase-actions-dir.zip "${FRAMEWORK_DIR}"
  gsutil cp Firebase-actions-dir.zip "gs://ios-framework-zip/Firebase-actions-dir-${GITHUB_HASH}.zip"
  # Keep the commit hash, and so SDK testing can load latest zip based on the commit hash.
  touch latest_commit_hash.txt
  echo "${GITHUB_HASH}" > latest_commit_hash.txt
  gsutil cp latest_commit_hash.txt "gs://ios-framework-zip/latest_commit_hash.txt"
fi
