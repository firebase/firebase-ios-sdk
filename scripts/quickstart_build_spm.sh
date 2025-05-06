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

set -xeuo pipefail

SAMPLE=$1

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$scripts_dir/setup_bundler.sh"

gem install xcpretty

git clone https://github.com/firebase/quickstart-ios.git

cd quickstart-ios

source "$scripts_dir/quickstart_spm_xcodeproj.sh" "$SAMPLE"

# Placeholder GoogleService-Info.plist good enough for build only testing.
cp ./mock-GoogleService-Info.plist ./firebaseai/GoogleService-Info.plist

SAMPLE=$1 DIR=$1 SPM="true" TEST="false" ./scripts/test.sh
