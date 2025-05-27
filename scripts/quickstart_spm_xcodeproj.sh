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

set -xeuo pipefail

SAMPLE=$1
SAMPLE_DIR=$(echo "$SAMPLE" | perl -ne 'print lc')
XCODEPROJ=${SAMPLE_DIR}/${SAMPLE}Example.xcodeproj/project.pbxproj

# Regex matches SemVer `firebase-ios-sdk` dependency in project.pbxproj:
# {
#   isa = XCRemoteSwiftPackageReference;
#	  repositoryURL = "https://github.com/firebase/firebase-ios-sdk.git";
#   requirement = {
#     kind = upToNextMajorVersion;
#	    minimumVersion = xx.yy.zz;
#	  };
# };
REQUIREMENT_REGEX='({'\
'\s*isa = XCRemoteSwiftPackageReference;'\
'\s*repositoryURL = "https://github\.com/firebase/firebase-ios-sdk\.git";'\
'\s*requirement = {\s*)kind = upToNextMajorVersion;'\
'\s*minimumVersion = \d+\.\d+\.\d+;'\
'(\s*};'\
'\s*};)'

# Replaces the minimumVersion requirement with a branch requirement.
REPLACEMENT_REGEX="\1branch = $BRANCH_NAME;\n\t\t\t\tkind = branch;\2"

# Performs the replacement using Perl.
#
# -0777 Enables reading all input in one go (slurp), rather than line-by-line.
# -p Causes Perl to loop through the input line by line.
# -i Edits the file in place.
# -e Provides the expression to execute.
perl -0777 -i -pe "s#$REQUIREMENT_REGEX#$REPLACEMENT_REGEX#g" "$XCODEPROJ" || {
  echo "Failed to update quickstart's Xcode project to the branch: $BRANCH_NAME"
  exit 1
}

# Point SPM CI to the tip of `main` of
# https://github.com/google/GoogleAppMeasurement so that the release process
# can defer publishing the `GoogleAppMeasurement` tag until after testing.
export FIREBASECI_USE_LATEST_GOOGLEAPPMEASUREMENT=1
