#!/bin/bash

# Copyright 2024 Google LLC
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

# Script to re-encrypt stored secrets with a new cryptographic key.
#
# Usage:
#   rotate_secrets.sh <current_secret_key> <new_secret_key> <secrets_directory>
#
# Arguments:
#   <current_secret_key>: The current secret key.
#   <new_secret_key>: The new secret key.
#   <directory>: The directory to rotate encrypted files in.
#
# Note:
#   A new cryptographic key can be generated with `openssl rand -base64 32`.
#

if [[ $# -ne 3 ]]; then
  cat 1>&2 <<EOF
Error: Expected exactly 3 arguments.
USAGE: *** [current_secret_key]
USAGE: *** [new_secret_key]
USAGE: $3 [secrets_directory]
EOF
  exit 1
fi

current_secret_key=$1
new_secret_key=$2
secrets_directory=$3

if [[ ! -d "$secrets_directory" ]]; then
  echo "Error: The given directory does not exist."
  exit 1
fi

# Search for encrypted files in the given directory.
files=$(find "$secrets_directory" -name "*.gpg")

# For each file, decrypt the encrypted contents and re-encrypt with the new
# secret.
for encrypted_file in $files; do
  echo "Decrypting $encrypted_file"
  scripts_dir=$(dirname "$0")
  # The decrypted file's path will match the encrypted file's path, minus the
  #  trailing `.gpg` extension.
  decrypted_file=${encrypted_file%.*}
  source "$scripts_dir/decrypt_gha_secret.sh" \
    "$encrypted_file" "$decrypted_file" "$current_secret_key"
  if [ ! -f "$decrypted_file" ]; then
    echo "Error: The file could not be decrypted: $encrypted_file"
    exit 1
  fi

  # Remove current encrypted file or else re-encryption will fail due to the
  # gpg file already existing. The below script invocation will re-encrypt
  # the file to the `encrypted_file` path.
  rm "$encrypted_file"

  echo "Encrypting with new secret to $encrypted_file"

  source "$scripts_dir/encrypt_gha_secret.sh" "$decrypted_file" "$new_secret_key"
  if [ ! -f "$encrypted_file" ]; then
    echo "Error: The file could not be encrypted: $decrypted_file"
    exit 1
  fi

  # Cleanup the decrypted file now that it's been re-encrypted.
  rm "$decrypted_file"
done
