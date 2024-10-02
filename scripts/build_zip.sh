#!/bin/bash

# Copyright 2020 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -x
REPO=`pwd`

if [[ $# -ne 4 ]]; then
  cat 2>&2 <<EOF
USAGE: $1 [output_directory]
USAGE: $2 [custom-spec-repos]
USAGE: $3 [`build-release` or `build-head`]
USAGE: $4 [`static` or `dynamic`]
EOF
  exit 1
fi

# The release build won't generate Carthage distro if the current
# PackageManifest version has already been released.
carthage_version_check="--enable-carthage-version-check"

# The first and only argument to this script should be the name of the
# output directory.
OUTPUT_DIR="$REPO/$1"
CUSTOM_SPEC_REPOS="$2"
BUILD_MODE="$3"
LINKING_TYPE="$4"

if [[ "$BUILD_MODE" == "build-head" ]]; then
  echo "Building zip from head."
  build_head_option="--local-podspec-path"
  build_head_value="$REPO"
  carthage_version_check="--disable-carthage-version-check"
elif [[ "$BUILD_MODE" == "build-release" ]]; then
  echo "Building zip from release tag."
else
  echo "Defaulting to `build_release`."
fi

if [[ "$LINKING_TYPE" == "dynamic" ]]; then
  linking_mode="--dynamic"
elif [[ "$LINKING_TYPE" == "static" ]]; then
  linking_mode="--no-dynamic"
else
  echo "Defaulting to `static`."
  linking_mode="--no-dynamic"
fi

source_repo=()
IFS=','
read -a specrepo <<< "${CUSTOM_SPEC_REPOS}"

cd ReleaseTooling
swift run zip-builder --keep-build-artifacts --update-pod-repo \
    ${linking_mode} ${build_head_option} ${build_head_value} \
    --output-dir "${OUTPUT_DIR}" \
    "${carthage_version_check}" \
    --custom-spec-repos  "${specrepo[@]}"
