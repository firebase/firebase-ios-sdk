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

if [[ "${DEBUG:-false}" == "true" ]]; then
  set -x
fi

usage() {
  cat <<EOF >&2
Modify a .xcodeproj to use a specific branch, version, or commit for the
firebase-ios-sdk SPM dependency.

Usage: ${0} <path_to.xcodeproj>
       [--version <version> | --revision <revision> | --prerelease | --branch <branch>]
EOF
  exit 1
}

# State tracked for cleanup trap
temp_file=""
pbxproj_path=""
backup_successful=false

cleanup() {
  local status=$?
  if [[ ${status} -ne 0 && "${backup_successful}" == "true" \
        && -n "${temp_file}" && -f "${temp_file}" ]]; then
    echo "Error occurred. Restoring backup of project.pbxproj..." >&2
    mv "${temp_file}" "${pbxproj_path}" 2>/dev/null || true
  fi
  if [[ -n "${temp_file}" ]]; then
    rm -f "${temp_file}"
  fi
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP

main() {
  if [[ $# -lt 2 ]]; then
    usage
  fi

  local xcodeproj_path="${1}"
  shift
  local mode="${1}"
  shift

  pbxproj_path="${xcodeproj_path}/project.pbxproj"
  if [[ ! -f "${pbxproj_path}" ]]; then
    echo "Error: Project file not found: ${pbxproj_path}" >&2
    exit 1
  fi

  local kind=""
  local key=""
  local value=""

  case "${mode}" in
    --version)
      if [[ $# -lt 1 ]]; then
        echo "Error: Missing version for --version" >&2
        exit 1
      fi
      kind="exactVersion"
      key="version"
      value="${1}"
      ;;
    --prerelease)
      local commit_hash
      commit_hash="$(
        git ls-remote \
          https://github.com/firebase/firebase-ios-sdk.git refs/heads/main \
          | cut -f1
      )"
      if [[ -z "${commit_hash}" ]]; then
        echo "Error: Failed to get remote revision for main branch." >&2
        exit 1
      fi
      kind="revision"
      key="revision"
      value="${commit_hash}"
      ;;
    --revision)
      if [[ $# -lt 1 ]]; then
        echo "Error: Missing revision for --revision" >&2
        exit 1
      fi
      kind="revision"
      key="revision"
      value="${1}"
      ;;
    --branch)
      if [[ $# -lt 1 ]]; then
        echo "Error: Missing branch name for --branch" >&2
        exit 1
      fi
      kind="branch"
      key="branch"
      value="${1}"
      ;;
    *)
      echo "Invalid mode: ${mode}" >&2
      usage
      ;;
  esac

  temp_file="$(mktemp "${TMPDIR:-/tmp}/pbxproj_backup.XXXXXX")"
  cp "${pbxproj_path}" "${temp_file}"
  backup_successful=true

  # Pass variables through the environment to avoid regex delimiter injection
  # and Perl variable interpolation collisions.
  KIND="${kind}" KEY="${key}" VALUE="${value}" perl -0777 -i -pe '
    my $repo =
      qr#repositoryURL\s*=\s*"https?://github\.com/firebase/firebase-ios-sdk(?:\.git)?";#;
    my $isa = qr#isa\s*=\s*XCRemoteSwiftPackageReference;#;
    my $header = qr#(?:${isa}\s*${repo}|${repo}\s*${isa})#;
    my $pattern = qr#${header}\s*\Krequirement\s*=\s*\{[^}]*\};#;

    my $kind = $ENV{"KIND"};
    my $key  = $ENV{"KEY"};
    my $val  = $ENV{"VALUE"};
    my $replacement = "requirement = {\n" .
                      "\t\t\t\tkind = ${kind};\n" .
                      "\t\t\t\t${key} = \"${val}\";\n" .
                      "\t\t\t};";

    if (!s/$pattern/$replacement/) {
      die "Failed to find and replace the firebase-ios-sdk dependency. " .
          "Check the regex pattern and project file structure.\n";
    }
  ' "${pbxproj_path}" || {
    echo "Failed to update the Xcode project's SPM dependency." >&2
    exit 1
  }

  echo "Successfully updated SPM dependency in ${pbxproj_path}"
}

main "$@"
