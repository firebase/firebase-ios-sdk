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

# Script to run in a CI `before_install` phase to setup a SPM-based
# quickstart repo so that it can be used for integration testing.

set -euo pipefail

if [[ -z "${1:-}" ]]; then
  cat <<EOF
Usage: $(basename "$0") <sample_name> [nightly_release_testing|prerelease_testing]

This script sets up a quickstart sample for SPM integration testing.

ARGUMENTS:
  <sample_name> The name of the quickstart sample directory (e.g., "authentication").

ENVIRONMENT VARIABLES:
  QUICKSTART_REPO: Optional. Path to a local clone of the quickstart-ios repo.
                   If not set, the script will clone it from GitHub.
                   Example: QUICKSTART_REPO=/path/to/quickstart-ios $(basename "$0") authentication

  GHA_WORKFLOW_SECRET: Optional. Set to "true" to bypass the CI secret check for local runs.
                       Example: GHA_WORKFLOW_SECRET=true $(basename "$0") authentication
EOF
  exit 1
fi

# Enable trace mode if DEBUG is set to 'true'
if [[ "${DEBUG:-false}" == "true" ]]; then
  set -x
fi

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
#                    QUICKSTART_REPO=/path/to/my/quickstart-ios ./scripts/setup_quickstart_spm.sh authentication
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
    QUICKSTART_DIR="quickstart-ios"
    if [[ -d "${QUICKSTART_DIR}" ]]; then
      echo "Quickstart repository already exists at ${QUICKSTART_DIR}"
    else
      echo "Cloning quickstart repository into '${QUICKSTART_DIR}' directory..."
      # Do a partial, sparse clone to speed up CI. See
      # https://github.blog/2020-12-21-get-up-to-speed-with-partial-clone-and-shallow-clone/
      git clone --filter=blob:none --sparse https://github.com/firebase/quickstart-ios.git "${QUICKSTART_DIR}"
    fi
    (
      cd "${QUICKSTART_DIR}"
      echo "Ensuring sparse checkout is set for ${SAMPLE}..."
      # Checkout the sample and config directories.
      git sparse-checkout set "${SAMPLE}" config
    )
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

  # NOTE: Uncomment below and replace `{BRANCH_NAME}` for testing a branch of
  # the quickstart repo.
  # (cd "$QUICKSTART_DIR"; git checkout {BRANCH_NAME})
  (cd "$QUICKSTART_DIR"; git checkout mc/spm)

  if [ "$RELEASE_TESTING" == "nightly_release_testing" ]; then
    # For release testing, find the latest CocoaPods tag.
    LATEST_TAG=$(git tag -l "CocoaPods-*" --sort=-v:refname | awk '/^CocoaPods-[0-9]+\.[0-9]+\.[0-9]+$/ { print; exit }')
    if [[ -z "$LATEST_TAG" ]]; then
      echo "Error: Could not find a 'CocoaPods-X.Y.Z' tag."
      exit 1
    fi
    echo "Setting SPM dependency to latest version: ${LATEST_TAG}"
    "$scripts_dir/update_firebase_spm_dependency.sh" "$ABSOLUTE_PROJECT_FILE" --branch "$LATEST_TAG"

  elif [ "$RELEASE_TESTING" == "prerelease_testing" ]; then
    # For prerelease testing, point to the tip of the main branch.
    echo "Setting SPM dependency to the tip of the main branch."
    "$scripts_dir/update_firebase_spm_dependency.sh" "$ABSOLUTE_PROJECT_FILE" --prerelease

  else
    # For PR testing, point to the current commit.
    CURRENT_REVISION=$(git rev-parse HEAD)
    echo "Setting SPM dependency to current revision: ${CURRENT_REVISION}"
    "$scripts_dir/update_firebase_spm_dependency.sh" "$ABSOLUTE_PROJECT_FILE" --revision "$CURRENT_REVISION"
  fi

else
  echo "Skipping quickstart setup: CI secrets are not available."
fi
