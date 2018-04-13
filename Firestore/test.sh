#!/usr/bin/env bash

# Copyright 2017 Google
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

FIRESTORE_DIR=$(dirname "${BASH_SOURCE[0]}")

test_iOS() {
  xcodebuild \
    -workspace "$FIRESTORE_DIR/Example/Firestore.xcworkspace" \
    -scheme Firestore_Tests \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 7' \
    build \
    test \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_REQUIRED=NO \
    | xcpretty

  xcodebuild \
    -workspace "$FIRESTORE_DIR/Example/Firestore.xcworkspace" \
    -scheme SwiftBuildTest \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 7' \
    build \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_REQUIRED=NO \
    | xcpretty
}

test_iOS; RESULT=$?
if [[ $RESULT == 65 ]]; then
  echo "xcodebuild exited with 65, retrying"
  sleep 5

  test_iOS; RESULT=$?
fi

exit $RESULT
