#!/usr/bin/env bash

# Copyright 2020 Google
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


# USAGE: test_catalyst.sh pod
#
# Builds and run tests for Catalyst since it's not yet supported by `pod lib lint`
# The second argument should be "build" or "test". "Test" indicates both build and test.

set -x
bundle exec pod gen --local-sources=./ --sources=https://cdn.cocoapods.org/ "$1".podspec --platforms=ios
xcodebuild $2 -configuration Debug -workspace "gen/$1/$1.xcworkspace"  -scheme "$1-Unit-unit"\
 ARCHS=x86_64h VALID_ARCHS=x86_64h ONLY_ACTIVE_ARCH=NO  SUPPORTS_MACCATALYST=YES  -sdk macosx \
 CODE_SIGN_IDENTITY=- SUPPORTS_UIKITFORMAC=YES CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO | xcpretty
