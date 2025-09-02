# Copyright 2025 Google
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

# Script to run in a CI `before_install` phase to setup a SPM-based
# quickstart repo so that it can be used for integration testing.

set -xeuo pipefail

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(dirname "$scripts_dir")"

# Source function to check if CI secrets are available.
source $scripts_dir/check_secrets.sh

# Arguments:
#   SAMPLE: The name of the quickstart sample directory.
#   RELEASE_TESTING: Optional. Can be "nightly_release_testing" or "prerelease_testing".
#
# Environment Variable:
#   QUICKSTART_REPO: Optional. Path to a local clone of the quickstart-ios repo.
#                    If not set, the script will clone it from GitHub.
#                    Example:
#                    QUICKSTART_REPO=/path/to/my/quickstart-ios ./scripts/setup_quickstart_spm.sh AppName
SAMPLE=$1
RELEASE_TESTING=${2-}

QUICKSTART_PROJECT_DIR="quickstart-ios/${SAMPLE}"

# TODO: Investigate moving this to a shared prereq script.
if ! gem list -i xcpretty > /dev/null; then
  gem install xcpretty
fi

# Some quickstarts may not need a real GoogleService-Info.plist for their tests.
# When QUICKSTART_REPO is set, we are running locally and should skip the secrets check.
if [[ -n "${QUICKSTART_REPO:-}" ]] || check_secrets || [[ ${SAMPLE} == "installations" ]]; then

  # Use local quickstart repo if QUICKSTART_REPO is set, otherwise clone it.
  if [[ -n "${QUICKSTART_REPO:-}" && -d "${QUICKSTART_REPO}" ]]; then
    echo "Using local quickstart repository at ${QUICKSTART_REPO}"
    QUICKSTART_DIR="${QUICKSTART_REPO}"
  else
    echo "Cloning quickstart repository into 'quickstart-ios' directory..."
    git clone https://github.com/firebase/quickstart-ios.git
    QUICKSTART_DIR="quickstart-ios"
  fi

  QUICKSTART_PROJECT_DIR="${QUICKSTART_DIR}/${SAMPLE}"

  # Find the .xcodeproj file within the sample directory.
  # Note: This assumes there is only one .xcodeproj file.
  PROJECT_FILE=$(find "$QUICKSTART_PROJECT_DIR" -maxdepth 1 -name "*.xcodeproj" | head -n 1)
  if [[ -z "$PROJECT_FILE" ]]; then
    echo "Error: Could not find .xcodeproj file in ${QUICKSTART_PROJECT_DIR}"
    exit 1
  fi

  # The localization script needs an absolute path to the project file.
  # If QUICKSTART_REPO was provided, PROJECT_FILE is already an absolute or user-provided path.
  # Otherwise, it's relative to the firebase-ios-sdk root.
  if [[ -n "${QUICKSTART_REPO:-}" && -d "${QUICKSTART_REPO}" ]]; then
    ABSOLUTE_PROJECT_FILE="$PROJECT_FILE"
  else
    ABSOLUTE_PROJECT_FILE="$root_dir/$PROJECT_FILE"
  fi

  # (cd "$QUICKSTART_DIR"; git checkout {BRANCH_NAME})

  if [ "$RELEASE_TESTING" == "nightly_release_testing" ]; then
    # For release testing, find the latest CocoaPods tag and extract the version.
    LATEST_TAG=$(git tag -l "CocoaPods-*" --sort=-v:refname | awk '/^CocoaPods-[0-9]+\.[0-9]+\.[0-9]+$/ { print; exit }')
    if [[ -z "$LATEST_TAG" ]]; then
      echo "Error: Could not find a 'CocoaPods-X.Y.Z' tag."
      exit 1
    fi
    VERSION=$(echo "$LATEST_TAG" | sed 's/CocoaPods-//')
    echo "Setting SPM dependency to latest version: ${VERSION}"
    swift run --package-path "$scripts_dir/spm-localizer" SPMLocalize "$ABSOLUTE_PROJECT_FILE" --version "$VERSION"

  elif [ "$RELEASE_TESTING" == "prerelease_testing" ]; then
    # For prerelease testing, point to the tip of the main branch.
    echo "Setting SPM dependency to the tip of the main branch."
    swift run --package-path "$scripts_dir/spm-localizer" SPMLocalize "$ABSOLUTE_PROJECT_FILE" --prerelease

  else
    # For PR testing, point to the current commit.
    CURRENT_REVISION=$(git rev-parse HEAD)
    echo "Setting SPM dependency to current revision: ${CURRENT_REVISION}"
    swift run --package-path "$scripts_dir/spm-localizer" SPMLocalize "$ABSOLUTE_PROJECT_FILE" --revision "$CURRENT_REVISION"
  fi

else
  echo "Skipping quickstart setup: CI secrets are not available."
fi
