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

# Modify a .xcodeproj to use a specific branch, version, or commit for the
# firebase-ios-sdk SPM dependency.

set -euo pipefail

# --- Helper functions ---
usage() {
  echo "Usage: $0 <path_to.xcodeproj> [--version <version> | --revision <revision> | --prerelease]"
  echo "Example: $0 path/to/MyProject.xcodeproj --version 10.24.0"
  exit 1
}

# --- Argument parsing ---
if [[ $# -lt 2 ]]; then
  usage
fi

XCODEPROJ_PATH="$1"
shift
MODE="$1"
shift

# Validate Xcode project path
if [[ ! -d "$XCODEPROJ_PATH" || ! "$XCODEPROJ_PATH" == *.xcodeproj ]]; then
    echo "Error: Invalid Xcode project path provided: $XCODEPROJ_PATH"
    exit 1
fi
PBXPROJ_PATH="${XCODEPROJ_PATH}/project.pbxproj"
if [[ ! -f "$PBXPROJ_PATH" ]]; then
    echo "Error: project.pbxproj not found at ${PBXPROJ_PATH}"
    exit 1
fi

case "$MODE" in
  --version)
    if [[ $# -lt 1 ]]; then usage; fi
    VERSION="$1"
    # Release testing: Point to CocoaPods-{VERSION} tag (as a branch)
    export REPLACEMENT_VALUE
    REPLACEMENT_VALUE=$(printf '{\n\t\t\t\tkind = branch;\n\t\t\t\tbranch = "%s";\n\t\t\t}' "$VERSION")
    ;;
  --prerelease)
    # Prerelease testing: Point to the tip of the main branch
    COMMIT_HASH=$(git ls-remote https://github.com/firebase/firebase-ios-sdk.git main | cut -f1)
    if [[ -z "$COMMIT_HASH" ]]; then
        echo "Error: Failed to get remote revision for main branch."
        exit 1
    fi
    export REPLACEMENT_VALUE
    REPLACEMENT_VALUE=$(printf '{\n\t\t\t\tkind = revision;\n\t\t\t\trevision = "%s";\n\t\t\t}' "$COMMIT_HASH")
    ;;
  --revision)
    if [[ $# -lt 1 ]]; then usage; fi
    REVISION="$1"
    # PR testing: Point to the specific commit hash of the current branch
    export REPLACEMENT_VALUE
    REPLACEMENT_VALUE=$(printf '{\n\t\t\t\tkind = revision;\n\t\t\t\trevision = "%s";\n\t\t\t}' "$REVISION")
    ;;
  *)
    usage
    ;;
esac

# Read the original content to check for changes later.
ORIGINAL_CONTENT=$(<"$PBXPROJ_PATH")

# Use perl to perform the replacement.
# -0777: Slurp the whole file into one string.
# -i: Edit in-place.
# -p: Loop over the input.
# -e: Execute the script.
# The `e` flag in `s/.../.../ge` evaluates the replacement as a Perl expression.
# This allows us to use an environment variable for the replacement string,
# avoiding quoting issues with shell variables.
perl -0777 -i -pe 's#(repositoryURL = "https://github.com/firebase/firebase-ios-sdk\.git";\s*requirement = )\{[^\}]+\};#$1 . $ENV{"REPLACEMENT_VALUE"} . ";"#ge' "$PBXPROJ_PATH" || {
  echo "Failed to update the Xcode project's SPM dependency."
  exit 1
}

# Verify that the file was changed.
UPDATED_CONTENT=$(<"$PBXPROJ_PATH")
if [[ "$ORIGINAL_CONTENT" == "$UPDATED_CONTENT" ]]; then
  echo "Failed to find and replace the firebase-ios-sdk dependency. Check the regex pattern and project file structure."
  exit 1
}

echo "Successfully updated SPM dependency in $PBXPROJ_PATH"

# Point SPM CI to the tip of `main` of
# https://github.com/google/GoogleAppMeasurement so that the release process
# can defer publishing the `GoogleAppMeasurement` tag until after testing.
export FIREBASECI_USE_LATEST_GOOGLEAPPMEASUREMENT=1
