#!/usr/bin/env bash

set -eo pipefail

EXIT_STATUS=0

(xcodebuild \
  -workspace Example/Firebase.xcworkspace \
  -scheme AllTests \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 7' \
  build \
  test \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_REQUIRED=NO \
  | xcpretty) || EXIT_STATUS=$?

