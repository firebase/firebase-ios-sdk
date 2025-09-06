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

# Define testing mode constants.
readonly NIGHTLY_RELEASE_TESTING="nightly_release_testing"
readonly PRERELEASE_TESTING="prerelease_testing"

# All script logic is contained in functions. The main function is called at the end.
# Global variables:
#   - readonly constants are defined at the top.
#   - scripts_dir and root_dir are set after constants.

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(dirname "$scripts_dir")"

print_usage() {
  cat <<EOF
Usage: $(basename "$0") <sample_name> [testing_mode]

This script sets up a quickstart sample for SPM integration testing.

ARGUMENTS:
  <sample_name>   The name of the quickstart sample directory (e.g., "authentication").
  [testing_mode]  Optional. Specifies the testing mode. Can be one of:
                  - "${NIGHTLY_RELEASE_TESTING}": Points SPM to the latest CocoaPods tag.
                  - "${PRERELEASE_TESTING}": Points SPM to the tip of the main branch.
                  - (default): Points SPM to the current commit for PR testing.

ENVIRONMENT VARIABLES:
  QUICKSTART_REPO: Optional. Path to a local clone of the quickstart-ios repo.
                   If not set, the script will clone it from GitHub.
                   Example: QUICKSTART_REPO=/path/to/quickstart-ios $(basename "$0") authentication

  BYPASS_SECRET_CHECK: Optional. Set to "true" to bypass the CI secret check for local runs.
                       Example: BYPASS_SECRET_CHECK=true $(basename "$0") authentication
EOF
}

# Clones or locates the quickstart repo.
#
# Globals:
#   - QUICKSTART_REPO (read-only)
# Arguments:
#   - $1: The name of the sample.
# Outputs:
#   - Echoes the absolute path to the quickstart directory.
setup_quickstart_repo() {
  local sample_name="$1"
  local quickstart_dir

  # If QUICKSTART_REPO is set, use it. Otherwise, clone the repo.
  if [[ -n "${QUICKSTART_REPO:-}" ]]; then
    # If the user provided a path, it must be a valid directory.
    if [[ ! -d "${QUICKSTART_REPO}" ]]; then
      echo "Error: QUICKSTART_REPO is set to '${QUICKSTART_REPO}', but this is not a valid directory." >&2
      exit 1
    fi
    echo "Using local quickstart repository at ${QUICKSTART_REPO}" >&2
    quickstart_dir="${QUICKSTART_REPO}"
  else
    # QUICKSTART_REPO is not set, so clone it.
    quickstart_dir="quickstart-ios"
    if [[ -d "${quickstart_dir}" ]]; then
      echo "Quickstart repository already exists at ${quickstart_dir}" >&2
    else
      echo "Cloning quickstart repository into '${quickstart_dir}' directory..." >&2
      # Do a partial, sparse clone to speed up CI. See
      # https://github.blog/2020-12-21-get-up-to-speed-with-partial-clone-and-shallow-clone/
      git clone --filter=blob:none --sparse https://github.com/firebase/quickstart-ios.git "${quickstart_dir}"
    fi
    (
      cd "${quickstart_dir}"
      echo "Ensuring sparse checkout is set for ${sample_name}..." >&2
      # Checkout the sample and config directories.
      git sparse-checkout set "${sample_name}" config
    )
  fi
  # Return the absolute path to the quickstart directory.
  (cd "$quickstart_dir" && pwd)
}

# Updates the SPM dependency in the Xcode project based on the testing mode.
#
# Globals:
#   - NIGHTLY_RELEASE_TESTING (read-only)
#   - PRERELEASE_TESTING (read-only)
#   - scripts_dir (read-only)
#   - root_dir (read-only)
# Arguments:
#   - $1: The testing mode.
#   - $2: The absolute path to the .xcodeproj file.
update_spm_dependency() {
  local release_testing_mode="$1"
  local absolute_project_file="$2"

  case "$release_testing_mode" in
    "${NIGHTLY_RELEASE_TESTING}")
      # For release testing, find the latest CocoaPods tag.
      local latest_tag
      latest_tag=$(git -C "$root_dir" tag -l "CocoaPods-*" --sort=-v:refname | awk '/^CocoaPods-[0-9]+\.[0-9]+\.[0-9]+$/ { print; exit }')
      if [[ -z "$latest_tag" ]]; then
        echo "Error: Could not find a 'CocoaPods-X.Y.Z' tag." >&2
        exit 1
      fi
      echo "Setting SPM dependency to latest version: ${latest_tag}"
      "$scripts_dir/update_firebase_spm_dependency.sh" "$absolute_project_file" --version "$latest_tag"
      ;;

    "${PRERELEASE_TESTING}")
      # For prerelease testing, point to the tip of the main branch.
      echo "Setting SPM dependency to the tip of the main branch."
      "$scripts_dir/update_firebase_spm_dependency.sh" "$absolute_project_file" --prerelease
      ;;

    *)
      # For PR testing, point to the current commit.
      local current_revision
      current_revision=$(git -C "$root_dir" rev-parse HEAD)
      echo "Setting SPM dependency to current revision: ${current_revision}"
      "$scripts_dir/update_firebase_spm_dependency.sh" "$absolute_project_file" --revision "$current_revision"
      ;;
  esac
}

main() {
  # --- Argument Parsing ---
  if [[ -z "${1:-}" ]]; then
    print_usage
    exit 1
  fi

  local sample="$1"
  local release_testing="${2-}"

  # Validate release_testing argument.
  case "$release_testing" in
    "" | "${NIGHTLY_RELEASE_TESTING}" | "${PRERELEASE_TESTING}")
      # This is a valid value (or empty), so do nothing.
      ;;
    *)
      # This is an invalid value.
      echo "Error: Invalid testing_mode: '${release_testing}'" >&2
      print_usage
      exit 1
      ;;
  esac

  # --- Environment Setup and Validation ---
  # Enable trace mode if DEBUG is set to 'true'
  if [[ "${DEBUG:-false}" == "true" ]]; then
    set -x
  fi

  # Source function to check if CI secrets are available.
  source "$scripts_dir/check_secrets.sh"

  # Some quickstarts may not need a real GoogleService-Info.plist for their tests.
  # When QUICKSTART_REPO is set, we are running locally and should skip the secrets check.
  if [[ -z "${QUICKSTART_REPO:-}" ]] && \
     [[ "${BYPASS_SECRET_CHECK:-}" != "true" ]] && \
     ! check_secrets && \
     [[ "${sample}" != "installations" ]]; then
    echo "Skipping quickstart setup: CI secrets are not available."
    exit 0
  fi

  # --- Main Logic ---
  local quickstart_dir
  quickstart_dir=$(setup_quickstart_repo "$sample")

  local quickstart_project_dir="${quickstart_dir}/${sample}"

  if [[ ! -d "${quickstart_project_dir}" ]]; then
    echo "Error: Sample directory not found at '${quickstart_project_dir}'" >&2
    exit 1
  fi

  # Find the .xcodeproj file within the sample directory.
  # Fail if there isn't exactly one.
  # Enable nullglob to ensure the glob expands to an empty list if no files are found.
  shopt -s nullglob
  local project_files=("${quickstart_project_dir}"/*.xcodeproj)
  # Restore default globbing behavior.
  shopt -u nullglob
  if [[ ${#project_files[@]} -ne 1 ]]; then
    echo "Error: Expected 1 .xcodeproj file in '${quickstart_project_dir}', but found ${#project_files[@]}." >&2
    exit 1
  fi
  local project_file="${project_files[0]}"

  # NOTE: Uncomment below and replace `{BRANCH_NAME}` for testing a branch of
  # the quickstart repo.
  # (cd "$quickstart_dir"; git checkout {BRANCH_NAME})

  update_spm_dependency "$release_testing" "$project_file"
}

# Run the main function with all provided arguments.
main "$@"