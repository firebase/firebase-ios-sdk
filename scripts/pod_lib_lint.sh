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

if [[ $# -lt 1 ]]; then
  cat 1>&2 <<EOF
USAGE: $0 podspec [options]

podspec is the podspec to lint

options can be any options for pod spec lint

Optionally, ALT_SOURCES can be set in the script to add extra repos to the
search path. This is useful when API's to core dependencies like FirebaseCore
or GoogleUtilities and the public podspecs are not yet updated.
EOF
  exit 1
fi

# Set ALT_SOURCES like the following to continue lint testing until release when Utilities
# or Core APIs change. GoogleUtilities.podspec and FirebaseCore.podspec should be
# manually pushed to a temporary Specs repo. See
# https://guides.cocoapods.org/making/private-cocoapods.
ALT_SOURCES="--sources=https://github.com/paulb777/Specs.git,https://github.com/CocoaPods/Specs.git"

podspec="$1"
if [[ $# -gt 1 ]]; then
  options="${@:2}"
else
  options=
fi

command="bundle exec pod lib lint $podspec $options $ALT_SOURCES"
echo $command

$command ; result=$?

if [[ $result != 0 ]]; then
  # retry because of occasional network flakiness
  $command ; result=$?
fi
exit $result
