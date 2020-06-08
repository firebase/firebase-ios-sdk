#!/usr/bin/env bash

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


# Build the quickstart. If we're running on the main repo (not a fork), we
# also run the tests along with the decoded GoogleService-Info.plist files.

set -eo pipefail

set -x

EXIT_STATUS=0

# Set have_secrets to true or false.
../scripts/check_secrets.sh

cd "${SAMPLE}"

if [[ "$have_secrets" == true ]]; then
    (
		xcodebuild \
		-project ${SAMPLE}Example.xcodeproj \
		-scheme  ${SAMPLE}Example${SWIFT_SUFFIX} \
		-destination 'platform=iOS Simulator,name=iPhone 11 Pro' "OTHER_LDFLAGS=\$(OTHER_LDFLAGS) -ObjC" "FRAMEWORK_SEARCH_PATHS= \$(PROJECT_DIR)/Firebase/" HEADER_SEARCH_PATHS='$(PROJECT_DIR)/Firebase' \
      build \
      test \
    ) || EXIT_STATUS=$?
else
    # Skip running tests if GoogleService-Info.plist's weren't decoded.
    (
		xcodebuild \
		-project ${SAMPLE}Example.xcodeproj \
		-scheme  ${SAMPLE}Example${SWIFT_SUFFIX} \
		-destination 'platform=iOS Simulator,name=iPhone 11 Pro' "OTHER_LDFLAGS=\$(OTHER_LDFLAGS) -ObjC" "FRAMEWORK_SEARCH_PATHS= \$(PROJECT_DIR)/Firebase/" HEADER_SEARCH_PATHS='$(PROJECT_DIR)/Firebase' \
      build
    ) || EXIT_STATUS=$?
fi

  exit $EXIT_STATUS
