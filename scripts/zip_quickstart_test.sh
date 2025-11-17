#!/usr/bin/env bash

# Copyright 2022 Google LLC
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

cd "${SAMPLE}"

if [[ ! -z "$LEGACY" ]]; then
  cd "Legacy${SAMPLE}Quickstart"
fi

xcode_version=$(xcodebuild -version | grep Xcode)
xcode_version="${xcode_version/Xcode /}"
xcode_major="${xcode_version/.*/}"

if [[ "$xcode_major" -lt 15 ]]; then
  device_name="iPhone 14"
elif [[ "$xcode_major" -lt 16 ]]; then
  device_name="iPhone 15"
else
  device_name="iPhone 16"
fi

# Define project and scheme names
PROJECT_NAME="${SAMPLE}Example.xcodeproj"
SCHEME_NAME="${SAMPLE}Example${SWIFT_SUFFIX}"

# Check if the scheme exists before attempting to build.
# The `awk` command prints all lines from "Schemes:" to the end of the output.
if ! xcodebuild -list -project "${PROJECT_NAME}" | awk '/Schemes:/,0' | grep -q "^\s*${SCHEME_NAME}"$; then
    echo "Error: Scheme '${SCHEME_NAME}' not found in project '${PROJECT_NAME}'."
    echo "Available schemes from '${PROJECT_NAME}':"
    xcodebuild -list -project "${PROJECT_NAME}"
    exit 65
fi

(
xcodebuild \
-project ${PROJECT_NAME} \
-scheme  ${SCHEME_NAME} \
-destination "platform=iOS Simulator,name=$device_name" "SWIFT_VERSION=5.3" "OTHER_LDFLAGS=\$(OTHER_LDFLAGS) -ObjC" "FRAMEWORK_SEARCH_PATHS= \$(PROJECT_DIR)/Firebase/" HEADER_SEARCH_PATHS='$(inherited) $(PROJECT_DIR)/Firebase' \
build \
) || EXIT_STATUS=$?

exit $EXIT_STATUS
