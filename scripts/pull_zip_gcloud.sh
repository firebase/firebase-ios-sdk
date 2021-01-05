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

plist_secret="$1"
FRAMEWORK_ZIP="$2"
ZIP_DEST_DIR="$3"

# Install gcloud sdk
curl https://sdk.cloud.google.com > install.sh
bash install.sh --disable-prompts
echo "::add-path::${HOME}/google-cloud-sdk/bin/"
export PATH="${HOME}/google-cloud-sdk/bin/:${PATH}"

# Access gcloud storage bucket
scripts/decrypt_gha_secret.sh scripts/gha-encrypted/firebase-ios-testing.json.gpg firebase-ios-testing.json "$plist_secret"
gcloud auth activate-service-account --key-file firebase-ios-testing.json

# Get the latest zip file from GCS
scripts/get_latest_zip_from_gcs.sh "$FRAMEWORK_ZIP" "$ZIP_DEST_DIR"
