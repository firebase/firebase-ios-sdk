#!/bin/bash

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

# Fail on spaces in file names, excluding the patterns listed below.

# A sed program that removes filename patterns that are allowed to have spaces
# in them.
function remove_valid_names() {
  sed '
    # Xcode-generated asset files
    /Assets.xcassets/ d

    # Files without spaces
    /^[^ ]*$/ d
  '
}

count=$(git ls-files | remove_valid_names | wc -l | xargs)

if [[ ${count} != 0 ]]; then
  echo 'ERROR: Spaces in filenames are not permitted in this repo. Please fix.'
  echo ''

  git ls-files | remove_valid_names
  exit 1
fi
