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
# calls to the Firebase Console.
#
# The script takes three arguments:
# - GHA_SECRET: The password for decrypting GitHub secrets.
# - SERVICE_ACCOUNT: The path to the encrypted service account secret.
# - OUTPUT: The path to file where generated access token will be stored.
#
# This script uses Google's Swift Auth Client Library.
# - https://github.com/googleapis/google-auth-library-swift
#
# Generated tokens are `JSON` in the form:
# {
#     "token_type":"Bearer",
#     "expires_in":3599,
#     "access_token":"1234567890ABCDEFG"
# }

GHA_SECRET="$1" # Pass in `local_dev` if the SERVICE_ACCOUNT does not to be decrypted.
SERVICE_ACCOUNT="$2"
OUTPUT="$3"

echo "GHA_SECRET: ***"
echo "SERVICE_ACCOUNT: ${SERVICE_ACCOUNT}"
echo "OUTPUT: ${OUTPUT}"

if [[ ! -f $SERVICE_ACCOUNT ]]; then
    echo ERROR: Cannot find encrypted secret at $SERVICE_ACCOUNT, aborting.
    exit 1
fi

if [[ ! -f $OUTPUT ]]; then
    echo ERROR: Cannot find $OUTPUT, aborting.
    exit 1
fi

# The access token is generated using a downloaded Service Account JSON file from a
# Firebase Project. This can be downloaded from Firebase console under 'Project Settings'.
#
# The following stores the decrypted service account JSON file in `$HOME/.credentials/` and points
# the GOOGLE_APPLICATION_CREDENTIALS env var to it.
SERVICE_ACCOUNT_FILE=$(basename $SERVICE_ACCOUNT .gpg)

echo "Creating ~/.credentials/ directory"
mkdir -p ~/.credentials/

if [[ $GHA_SECRET == "local_dev" ]]; then
    echo "Local Development Mode"
    echo "Copying ${SERVICE_ACCOUNT_FILE} to ~/.credentials/"
    cp $SERVICE_ACCOUNT ~/.credentials/
else
    echo "Decrypting ${SERVICE_ACCOUNT_FILE}.gpg"
    scripts/decrypt_gha_secret.sh $SERVICE_ACCOUNT ~/.credentials/$SERVICE_ACCOUNT_FILE "$GHA_SECRET"
fi

echo "GOOGLE_APPLICATION_CREDENTIALS=${HOME}/.credentials/${SERVICE_ACCOUNT_FILE}" >> $GITHUB_ENV
export GOOGLE_APPLICATION_CREDENTIALS="${HOME}/.credentials/${SERVICE_ACCOUNT_FILE}"

# Clone Google's Swift Auth Client Library and use it to generate a token.
# The generated token is piped to the specified OUTPUT file.
git clone https://github.com/googleapis/google-auth-library-swift.git
cd google-auth-library-swift
make -f Makefile

# Prepend OUTPUT path with ../ since we cd'd into `google-auth-library-swift`.
swift run TokenSource > ../$OUTPUT

# Remove cloned Swift Auth Client Library.
cd ..
rm -rf google-auth-library-swift

if grep -q "access_token" $OUTPUT; then
   echo "Token successfully generated and placed at ${OUTPUT}"
else
   echo "ERROR: $(cat $OUTPUT)"
   exit 1
fi
