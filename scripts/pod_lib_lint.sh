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

# USAGE: pod_lib_lint.sh podspec [options]
#
# Runs pod lib lint for the given podspec

set -euo pipefail

if [[ $# -lt 1 ]]; then
  cat 1>&2 <<EOF
USAGE: $0 podspec [options]

podspec is the podspec to lint

options can be any options for pod spec lint

EOF
  exit 1
fi

command=(bundle exec pod lib lint "$@")

# CocoaPods 1.7.0 added the `--include-podspecs` option for `pod lib lint` to
# find dependencies locally instead of via a specs repo. This enables testing
# changes across multiple pods without needing to push the dependent pods to
# a staging repo.

if [[ $1 == "GoogleUtilities.podspec" ||
      $1 == "GoogleDataTransport.podspec" ]] ; then
  # No local dependencies.
  dep_string=''
else
  if [[ $1 == "GoogleDataTransportCCTSupport.podspec" ]]; then
    deps="GoogleDataTransport"
  elif [[ $1 == "FirebaseCore.podspec" ]]; then
    deps="GoogleUtilities"
  else
    # Most pods need GoogleUtilities and FirebaseCore.
    deps="GoogleUtilities,FirebaseCore"
    # Those listed below have additional local pod dependencies.
    if [[ $1 == "FirebaseInAppMessagingDisplay.podspec" ]]; then
      deps="$deps,FirebaseInAppMessaging"
    elif [[ $1 == "FirebaseMessaging.podspec" ]]; then
      deps="$deps,FirebaseInstanceID"
    fi
  fi
  dep_string="--include-podspecs={${deps}}.podspec"
fi

command+=("${dep_string}")

echo "${command[*]}"
"${command[@]}"; result=$?

exit $result
