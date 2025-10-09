#!/usr/bin/env bash

# Copyright 2025 Google
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

# USAGE: ./decrypt_secrests.sh
#
# Decrypts the secret files used for integration tests with the
# FirebaseAI sample app.
#
# Expects the environment variable "secrets_passphrase" to be set.
# This should be set to gpg password for encrypting/decrypting the files.

if [[ ! "$secrets_passphrase" ]]; then
  echo "Missing environment variable (secrets_passphrase) to decrypt the files with."
  exit 1
fi

decrypt () {
    local source=$1
    local dest=$2

    scripts/decrypt_gha_secret.sh $1 $2 "$secrets_passphrase"
    echo "$source => $dest"
}

echo "Decrypting files"

decrypt scripts/gha-encrypted/FirebaseAI/TestApp-GoogleService-Info.plist.gpg \
    FirebaseAI/Tests/TestApp/Resources/GoogleService-Info.plist

decrypt scripts/gha-encrypted/FirebaseAI/TestApp-GoogleService-Info-Spark.plist.gpg \
    FirebaseAI/Tests/TestApp/Resources/GoogleService-Info-Spark.plist

decrypt scripts/gha-encrypted/FirebaseAI/TestApp-Credentials.swift.gpg \
    FirebaseAI/Tests/TestApp/Tests/Integration/Credentials.swift

echo "Files decrypted"
