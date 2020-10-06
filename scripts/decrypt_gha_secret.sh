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

# $1 is the file to decrypt
# $2 is the output file
# $3 is the passphrase

# Decrypt the file
# --batch to prevent interactive command --yes to assume "yes" for questions

file="$1"
output="$2"
passphrase="$3"
[ -z "$passphrase" ] || \
  gpg --quiet --batch --yes --decrypt --passphrase="$passphrase" --output $output "$file"
