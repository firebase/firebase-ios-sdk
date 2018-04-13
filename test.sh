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

set -eo pipefail

test_iOS() {
  xcodebuild \
    -workspace Example/Firebase.xcworkspace \
    -scheme AllUnitTests_iOS \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 7' \
    build \
    test \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_REQUIRED=NO \
    | xcpretty
}

test_macOS() {
  xcodebuild \
    -workspace Example/Firebase.xcworkspace \
    -scheme AllUnitTests_macOS \
    -sdk macosx \
    -destination 'platform=OS X,arch=x86_64' \
    build \
    test \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_REQUIRED=NO \
    | xcpretty
}

test_tvOS() {
  xcodebuild \
    -workspace Example/Firebase.xcworkspace \
    -scheme AllUnitTests_tvOS \
    -sdk appletvsimulator \
    -destination 'platform=tvOS Simulator,name=Apple TV' \
    build \
    test \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_REQUIRED=NO \
    | xcpretty
}

test_iOS; RESULT=$?

if [ $RESULT != 0 ]; then exit $RESULT; fi

test_macOS; RESULT=$?

if [ $RESULT == 65 ]; then
  echo "xcodebuild exited with 65, retrying"
  sleep 5

  test_macOS; RESULT=$?
fi

if [ $RESULT != 0 ]; then exit $RESULT; fi

test_tvOS; RESULT=$?

if [ $RESULT != 0 ]; then exit $RESULT; fi

# Also test Firestore
Firestore/test.sh
