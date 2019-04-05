#!/usr/bin/env bash

# Copyright 2018 Google
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

set -euo pipefail

# 
function runXcodebuild() {
  parameters=(
    -workspace 'CocoapodsIntegrationTest.xcworkspace'
    -scheme 'CocoapodsIntegrationTest'
    -sdk 'iphonesimulator'
    -destination 'platform=iOS Simulator,name=iPhone 7'
    CODE_SIGNING_REQUIRED=NO
    clean
    build
  )

  echo xcodebuild "${parameters[@]}"
  xcodebuild "${parameters[@]}" | xcpretty; result=$?

  exit $result
}

# Accepts path to Gemfile
function prepareBundle() {
  cp -f "$@" ./_Gemfile
  bundle install --no-deployment --gemfile=_Gemfile
}

# 
function prepareCocoapods() {
  cp -f "$@" ./Podfile
  bundle exec pod deintegrate
  bundle exec pod update
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
      echo "Unknown option ${i}"
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

# Convert path to absolute one in case the script is run from another directory
RESOLVED_GEMFILE="$(realpath ${GEMFILE})"
RESLOVED_PODFILE="$(realpath ${PODFILE})"

echo "Gemfile  = ${RESOLVED_GEMFILE}"
echo "Podfile     = ${RESLOVED_PODFILE}"

pushd "$(dirname "$0")"

prepareBundle "${RESOLVED_GEMFILE}"
prepareCocoapods "${RESLOVED_PODFILE}"

popd
