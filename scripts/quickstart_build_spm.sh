#!/usr/bin/env bash

# Copyright 2025 Google LLC
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

# Verifies changes to firebase-ios-sdk repo can continue to build the
# product's SPM quickstart.

set -euo pipefail

if [[ "${DEBUG:-false}" == "true" ]]; then
  set -x
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: ${0} <sample_name>" >&2
  exit 1
fi

sample="${1}"
branch_name="${BRANCH_NAME:-main}"

sample_dir="$(echo "${sample}" | tr '[:upper:]' '[:lower:]')"
sample_xcodeproj="${sample_dir}/${sample}Example.xcodeproj"

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${scripts_dir}/setup_bundler.sh"

if ! command -v xcpretty >/dev/null 2>&1; then
  gem install --no-document xcpretty
fi

if [[ ! -d "quickstart-ios" ]]; then
  git clone --depth 1 https://github.com/firebase/quickstart-ios.git
fi

cd quickstart-ios

if [[ ! -d "${sample_xcodeproj}" ]]; then
  echo "Error: Project ${sample_xcodeproj} does not exist in quickstart-ios." \
    >&2
  exit 1
fi

# Execute updater script rather than sourcing to isolate state
"${scripts_dir}/update_firebase_spm_dependency.sh" \
  "${sample_xcodeproj}" \
  --branch "${branch_name}"

# Placeholder GoogleService-Info.plist good enough for build-only testing.
cp ./mock-GoogleService-Info.plist "./${sample_dir}/GoogleService-Info.plist"
if [[ -d "./${sample_dir}/${sample}Example" ]]; then
  cp ./mock-GoogleService-Info.plist \
    "./${sample_dir}/${sample}Example/GoogleService-Info.plist"
fi

FIREBASECI_USE_LATEST_GOOGLEAPPMEASUREMENT=1 \
SAMPLE="${sample}" \
DIR="${sample_dir}" \
SPM="true" \
TEST="false" \
./scripts/test.sh
