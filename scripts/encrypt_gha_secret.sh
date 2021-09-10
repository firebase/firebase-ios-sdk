#!/bin/bash

# Copyright 2021 Google LLC
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

# $1 is the file to encrypt
# $2 is the passphrase

# Encrypt the file
# See https://docs.github.com/en/actions/reference/encrypted-secrets for more details.
# --batch to prevent interactive command

file="$1"
passphrase="$2"
[ -z "$passphrase" ] || \
  gpg --batch --passphrase="$passphrase" --symmetric --cipher-algo AES256 $file
