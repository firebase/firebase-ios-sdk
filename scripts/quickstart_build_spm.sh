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


# Script to run in a CI `before_install` phase to setup the quickstart repo
# so that it can be used for integration testing.

set -xeuo pipefail

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(dirname "$scripts_dir")"

$scripts_dir/setup_bundler.sh

# Source function to check if CI secrets are available.
source $scripts_dir/check_secrets.sh

#WORKSPACE_DIR="quickstart-ios/${SAMPLE}"

gem install xcpretty

git clone https://github.com/firebase/quickstart-ios.git

cd quickstart-ios

# Placeholder GoogleService-Info.plist good enough for build only testing.
cp ./mock-GoogleService-Info.plist ./firebaseai/GoogleService-Info.plist

SAMPLE=$1 DIR=$1 SPM="true" TEST="false" ./scripts/test.sh

