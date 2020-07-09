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

# This script generates access tokens that are needed to make admin API
# calls to the Firebase Console. The script takes a single argument
# `output` which represents the location for where the outputted access
# token will be stored. This script uses Google's Swift Auth Client Library.
#
# Visit the repo: https://github.com/googleapis/google-auth-library-swift
#
# Generated tokens are `JSON` in the form:
# {
#     "token_type":"Bearer",
#     "expires_in":3599,
#     "access_token":"1234567890ABCDEFG"
# }

output="$1"

if [[ ! -f $output ]]; then
    echo ERROR: Cannot find $output, aborting.
    exit 1
fi

# The access token is generated using a downloaded Service Account from a Firebase Project.
# This can be downloaded from Firebase console under 'Project Settings'.
# Store the downloaded .json file in `$HOME/.credentials/` and point the env var to it.
#export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.credentials/ServiceAccount.json"

git clone https://github.com/googleapis/google-auth-library-swift.git
cd google-auth-library-swift
git checkout --quiet 7b1c9cd4ffd8cb784bcd8b7fd599794b69a810cf # Working main branch as of 7/9/20.
make -f Makefile

# Prepend output path with ../ since we cd'd into `google-auth-library-swift`
swift run TokenSource > ../$output

if grep -q "access_token" ../$output; then
   echo Token successfully generated and placed at $output
else
   echo ERROR: "$(cat ../$output)"
   exit 1
fi
