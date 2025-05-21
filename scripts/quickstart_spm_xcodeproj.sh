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


# Modify a .xcodeproj to use a specific branch.
# TODO: Update to transform from a release, as well as from `main`.

set -xeuo pipefail

SAMPLE=$1
XCODEPROJ=${SAMPLE}/${SAMPLE}Example.xcodeproj/project.pbxproj

REQUIREMENT_REGEX='({\s*isa = XCRemoteSwiftPackageReference;\s*repositoryURL = "https://github\.com/firebase/firebase-ios-sdk\.git";\s*requirement = {\s*)kind = upToNextMajorVersion;\s*minimumVersion = 11.13.0;(\s*};\s*};)'
REPLACEMENT_REGEX="\1branch = $BRANCH_NAME;\n\t\t\t\tkind = branch;\2"
perl -0777 -pe "s#$REQUIREMENT_REGEX#$REPLACEMENT_REGEX#s" "$XCODEPROJ"

# Point SPM CI to the tip of `main` of
# https://github.com/google/GoogleAppMeasurement so that the release process
# can defer publishing the `GoogleAppMeasurement` tag until after testing.
export FIREBASECI_USE_LATEST_GOOGLEAPPMEASUREMENT=1
