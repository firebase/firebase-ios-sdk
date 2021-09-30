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


# To test another version of Xcode for all of CI:
# - Add any edit, like a blank line, to Gemfile.
# - Uncomment the following line and choose the alternative Xcode version.
#sudo xcode-select -s /Applications/Xcode_13.0.app/Contents/Developer

# TODO(paulb777): Remove once Xcode 13 becomes the default version in macOS 11.
# https://github.com/actions/virtual-environments/blob/main/images/macos/macos-11-Readme.md#xcode
sudo xcode-select -s /Applications/Xcode_13.0.app/Contents/Developer

bundle update --bundler # ensure bundler version is high enough for Gemfile.lock
bundle install
bundle --version
bundle exec pod --version
