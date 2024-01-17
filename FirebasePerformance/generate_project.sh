#!/bin/bash

# Copyright 2020 Google LLC
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
#

# From https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within

# USAGE: generate_project.sh

helpFunction()
{
  echo ""
  echo "Usage: $0 -e (prod/autopush*) -p (platform)"
  echo -e "\tEvent upload environment - prod (or) autopush. Default: autopush"
  echo -c "\tRecreate the Xcode project from scratch. Default: Reuse same Xcode project"
  exit 1 # Exit script after printing help
}

while getopts "e:p:c" opt
do
  case "$opt" in
    e ) env="$OPTARG" ;;
    c ) clean="clean" ;;
    p ) platform="$OPTARG" ;;
    ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
  esac
done

if [ -z "$env" ] || [ "prod" != "$env" ]
then
  env="autopush"
fi

if [ -z "$platform" ]
then
  platform="ios"
fi

readonly DIR="$(git rev-parse --show-toplevel)"

# Enable Unswizzling in the development time (This is for unit test purposes).
export FPR_UNSWIZZLE_AVAILABLE="1"

# Enable AUTOPUSH to enable test App sending data to Autopush.
# To enable sending data to Prod, remove the following line and regenerate the project.
if [ "autopush" == "$env" ]
then
  export FPR_AUTOPUSH_ENV="1"
else
  export FPR_AUTOPUSH_ENV="0"
fi

echo "\nGenerating Fireperf Xcode project for $env environment..."
if [ -z "$clean" ]
then
  pod gen "$DIR/FirebasePerformance.podspec" --local-sources="$DIR/" --auto-open --gen-directory="$DIR/gen" --platforms="$platform"
else
  echo "\nCreating a fresh Fireperf Xcode project."
  rm -f "$DIR/FirebasePerformance/ProtoSupport/*.[hm]"
  protoc --proto_path="$DIR/FirebasePerformance/ProtoSupport/" --objc_out="$DIR/FirebasePerformance/ProtoSupport/" "$DIR/FirebasePerformance/ProtoSupport/perf_metric.proto"
  pod gen "$DIR/FirebasePerformance.podspec" --local-sources="$DIR/" --auto-open --gen-directory="$DIR/gen" --platforms="$platform" --clean
fi
