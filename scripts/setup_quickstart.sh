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

if [[ "$TRAVIS_PULL_REQUEST" == "false" ||
      "$TRAVIS_PULL_REQUEST_SLUG" == "$TRAVIS_REPO_SLUG" ]]; then
  SAMPLE=$1

  # Specify repo so the Firebase module and header can be found in a
  # development pod install. This is needed for the `pod install` command.
  export FIREBASE_POD_REPO_FOR_DEV_POD=`pwd`

  git clone https://github.com/firebase/quickstart-ios.git
  ./scripts/localize_podfile.swift quickstart-ios/"$SAMPLE"/Podfile
  # Print resulting Podfile to help with debugging.
  cat quickstart-ios/"$SAMPLE"/Podfile
  cd quickstart-ios/"$SAMPLE"

  # To test a branch, uncomment the following line
  # git checkout {BRANCH_NAME}

  bundle exec pod install
  cat "Pods/Local Podspecs/Firebase.podspec.json"
  echo "AAAAA"
  echo $FIREBASE_POD_REPO_FOR_DEV_POD
  echo "ZZZZZ"
  TRAVIS_PULL_REQUEST="$TRAVIS_PULL_REQUEST" TRAVIS_PULL_REQUEST_SLUG=$"TRAVIS_PULL_REQUEST_SLUG" \
    ../scripts/install_prereqs/"$SAMPLE.sh"
  # Secrets are repo specific, so we need to override with the firebase-ios-sdk
  # version.
  cp ../../Secrets/quickstart-ios/"$SAMPLE"/GoogleService-Info.plist ./
  cd -
fi
