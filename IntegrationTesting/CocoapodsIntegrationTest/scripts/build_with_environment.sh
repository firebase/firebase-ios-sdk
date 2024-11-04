#!/usr/bin/env bash

# Copyright 2019 Google
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

# The script uses combination of Gemfile/Podfile to validate Firebase
# compatibility with Cocoapods versions and settings.
# See `printUsage` for usage.

set -euo pipefail

source scripts/buildcache.sh
#
function runXcodebuild() {
  parameters=(
    -workspace 'CocoapodsIntegrationTest.xcworkspace'
    -scheme 'CocoapodsIntegrationTest'
    -sdk 'iphonesimulator'
    -destination 'platform=iOS Simulator,name=iPhone 14'
    CODE_SIGNING_REQUIRED=NO
    clean
    build
  )

  parameters=("${buildcache_xcb_flags[@]}" "${parameters[@]}")

  echo xcodebuild "${parameters[@]}"
  xcodebuild "${parameters[@]}" | xcpretty; result=$?
}

# Configures bundler environment using Gemfile at the specified path.
function prepareBundle() {
  cp -f "$@" ./Gemfile

  # Travis sets this variable. We should unset it otherwise `bundle exec` will
  # use the Gemfile by the path from the variable.
  unset BUNDLE_GEMFILE

  bundle update
}

# Updates Cocoapods using Podfile at the specified path.
function prepareCocoapods() {
  cp -f "$@" ./Podfile
  echo "Cocoapods version: $(bundle exec pod --version)"
  bundle exec pod deintegrate
  bundle exec pod update
}

function printUsage() {
  echo "USAGE: build_with_environment.sh --gemfile=<path_to_gemfile> --podfile=<path_to_podfile>"
}

for i in "$@"
do
  case $i in
    --gemfile=*)
      GEMFILE="${i#*=}"
      shift
      ;;
    --podfile=*)
      PODFILE="${i#*=}"
      shift
      ;;
    *)
      printUsage
      exit -1
      ;;
  esac
done

if [ -z ${GEMFILE+x} ]; then
  echo "--gemfile=<path_to_gemfile> is a required parameter"
  exit -1
fi

if [ -z ${PODFILE+x} ]; then
  echo "--podfile=<path_to_podfile> is a required parameter"
  exit -1
fi

# Convert path to absolute one in case the script is run from another directory.
RESOLVED_GEMFILE="$(realpath ${GEMFILE})"
RESOLVED_PODFILE="$(realpath ${PODFILE})"

echo "Gemfile  = ${RESOLVED_GEMFILE}"
echo "Podfile     = ${RESOLVED_PODFILE}"

# Make sure we build from the project root dir.
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
pushd "${scriptDir}/.."

prepareBundle "${RESOLVED_GEMFILE}"
prepareCocoapods "${RESOLVED_PODFILE}"
runXcodebuild

# Recover original directory just in case
popd
