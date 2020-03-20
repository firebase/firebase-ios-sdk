# Copyright 2019 Google
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

if check_secrets; then
  SAMPLE=$1

  # Specify repo so the Firebase module and header can be found in a
  # development pod install. This is needed for the `pod install` command.
  export FIREBASE_POD_REPO_FOR_DEV_POD=`pwd`

  git clone https://github.com/firebase/quickstart-ios.git
  $scripts_dir/localize_podfile.swift quickstart-ios/"$SAMPLE"/Podfile
  cd quickstart-ios/"$SAMPLE"

  # To test a branch, uncomment the following line
  # git checkout {BRANCH_NAME}

  bundle update --bundler
  bundle install
  bundle exec pod install
  ../scripts/install_prereqs/"$SAMPLE".sh

  # Secrets are repo specific, so we need to override with the firebase-ios-sdk
  # version. GHA manages the secrets in its action script.
  if [[ -n "${TRAVIS_PULL_REQUEST:-}" ]]; then
    cp $root_dir/Secrets/quickstart-ios/"$SAMPLE"/GoogleService-Info.plist ./
    cp $root_dir/Secrets/quickstart-ios/TestUtils/FIREGSignInInfo.h ../TestUtils/
  fi
  cd -
fi
