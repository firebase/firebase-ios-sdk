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

# Enable trace mode if DEBUG is set to 'true'
if [[ "${DEBUG:-false}" == "true" ]]; then
  set -x
fi

# --- Argument parsing ---
if [[ $# -lt 2 ]]; then
  echo "Modify a .xcodeproj to use a specific branch, version, or commit for the"
  echo "firebase-ios-sdk SPM dependency."
  echo ""
  echo "Usage: $0 <path_to.xcodeproj> [--version <version> | --revision <revision> | --prerelease | --branch <branch>]"
  exit 1
fi

XCODEPROJ_PATH="$1"
shift
MODE="$1"
shift

PBXPROJ_PATH="${XCODEPROJ_PATH}/project.pbxproj"

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
'\s*repositoryURL = "https://github\.com/firebase/firebase-ios-sdk(?:\.git)?";'\
'\s*requirement = {\s*)kind = upToNextMajorVersion;'\
'\s*minimumVersion = \d+\.\d+\.\d+;'\
'(\s*};'\
'\s*};)'

# Define the replacement requirement based on the selected mode. The new
# requirement is a kind (branch or revision) plus its value.
case "$MODE" in
  --version)
    if [[ $# -lt 1 ]]; then echo "Error: Missing version for --version"; exit 1; fi
    SPM_KIND="branch"
    SPM_VALUE="$1"
    ;;
  --prerelease)
    COMMIT_HASH=$(git ls-remote https://github.com/firebase/firebase-ios-sdk.git refs/heads/main | cut -f1)
    if [[ -z "$COMMIT_HASH" ]]; then
        echo "Error: Failed to get remote revision for main branch."
        exit 1
    fi
    SPM_KIND="revision"
    SPM_VALUE="$COMMIT_HASH"
    ;;
  --revision)
    if [[ $# -lt 1 ]]; then echo "Error: Missing revision for --revision"; exit 1; fi
    SPM_KIND="revision"
    SPM_VALUE="$1"
    ;;
  --branch)
    if [[ $# -lt 1 ]]; then echo "Error: Missing branch name for --branch"; exit 1; fi
    SPM_KIND="branch"
    SPM_VALUE="$1"
    ;;
  *)
    echo "Invalid mode: $MODE"
    exit 1
    ;;
esac

# The kind and value reach Perl through the environment rather than being
# interpolated into the expression's source text, so characters that are
# special to Perl (such as the `#` delimiter, which can appear in branch
# names) cannot break the substitution. Single quotes keep `$ENV{...}` and
# `${1}` for Perl rather than the shell.
export SPM_KIND SPM_VALUE
REPLACEMENT='${1}kind = $ENV{SPM_KIND};\n\t\t\t\t$ENV{SPM_KIND} = "$ENV{SPM_VALUE}";${2}'

# Make a temporary backup of the original file.
# This will be used to check if any changes were made.
TEMP_FILE=$(mktemp)
cp "$PBXPROJ_PATH" "$TEMP_FILE"

# Performs the replacement using Perl.
#
# -0777 Enables reading all input in one go (slurp), rather than line-by-line.
# -p Causes Perl to loop through the input line by line.
# -i Edits the file in place.
# -e Provides the expression to execute.
perl -0777 -i -pe "s#$REQUIREMENT_REGEX#$REPLACEMENT#g" "$PBXPROJ_PATH" || {
  echo "Failed to update the Xcode project's SPM dependency."
  exit 1
}

# Silently compare the modified file with the temporary backup.
# If they are the same, cmp will return 0 (success), and the 'if' block will run.
if cmp -s "$PBXPROJ_PATH" "$TEMP_FILE"; then
  echo "Failed to find and replace the firebase-ios-sdk dependency. Check the regex pattern and project file structure."
  # Restore the original file from the backup
  mv "$TEMP_FILE" "$PBXPROJ_PATH"
  exit 1
fi

echo "Successfully updated SPM dependency in $PBXPROJ_PATH"

# Point SPM CI to the tip of `main` of
# https://github.com/google/GoogleAppMeasurement so that the release process
# can defer publishing the `GoogleAppMeasurement` tag until after testing.
export FIREBASECI_USE_LATEST_GOOGLEAPPMEASUREMENT=1
