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

# USAGE: ./run.sh [Xcode] [target]
#
# EXAMPLE: ./run.sh Xcode_16.4 iOS
#
# Runs the integration tests for the FirebaseAI sample app.
#
# ARGUMENTS:
#   - [Xcode]: The version of Xcode to use. Defaults to searching for Xcode under `/Applications`.
#   - [target]: The platform target to test for (eg; iOS or macOS). Defaults to "iOS".
#
# ENVIRONMENT VARIABLES:
#   - <TEST_RUNNER_FIRAAppCheckDebugToken>: The app check debug token to use. This is required.
#   - <secrets_passphrase>: The gpg secret that the secret files were encrypted with.
#       This is semi-required. If this is not present, then the decrypted secret files
#       must already be present (ie; you manually added them).
#
# ADDITIONAL NOTES:
# If you provide a value for "secrets_passphrase", then the secret files will be decrypted
# on the fly, and will be deleted after the tests run. Even if the tests fail, the
# secret files will be deleted before the error propogates up. If you do NOT pass
# a value for "secrets_passphrase", and instead manually added the decrypted secret
# files, then the decrypted files will NOT be deleted after the script runs.
#
# If you don't specify an Xcode version, the script will attempt to search for an install
# under `/Applications`. If no installs or found, an error will be thrown. If multiple
# installs are found, they will be listed, and the script will prompt you to rerun it,
# while manually specifying the Xcode version to use.

shopt -s nullglob
set -eo pipefail

xcode=$1

# Look for Xcode installations if a version wasn't provided explicitly
if [[ -n "${xcode}" ]]; then
    apps=(/Applications/Xcode*.app)
    names=()
    for p in "${apps[@]}"; do
        names+=("$(basename "${p%.app}")")
    done

    case ${#names[@]} in
        0)
            echo "No Xcode installs found in /Applications" >&2
            exit 1
            ;;
        1)
            xcode="${names[0]}"
            echo "Using Xcode version: ${xcode}"
            ;;
        *)
            echo "Multiple Xcode installs found:"
            printf '  %s\n' "${names[@]}"
            echo "Manually specify an Xcode version instead"
            echo "USAGE: $0 [Xcode] [target]"
            exit 1
            ;;
    esac
fi

target="iOS"
if [[ $# -gt 1 ]]; then
  target="$2"
fi

if [[ -n "${TEST_RUNNER_FIRAAppCheckDebugToken}" ]]; then
    echo "Missing required environment variable for app check debug token (TEST_RUNNER_FIRAAppCheckDebugToken)"
    exit 1
fi

# Files used in integration tests. These are usually encrypted under /scripts/gha-encrypted/FirebaseAI
secret_files=(
    "FirebaseAI/Tests/TestApp/Resources/GoogleService-Info.plist"
    "FirebaseAI/Tests/TestApp/Resources/GoogleService-Info-Spark.plist"
    "FirebaseAI/Tests/TestApp/Tests/Integration/Credentials.swift"
)

# Checks if any of the secret files are absent, throwing an error if so.
check_for_secret_files () {
    for file in "${secret_files[@]}"; do
        if [[ ! -f "${file}" ]]; then
            echo "Missing required decrypted secret file: ${file}"
            exit 1
        fi
    done
}

cleanup () {
    # We only delete the decrypted secret files if we were the ones to decrypt them.
    if [[ -n "${delete_secrets}" ]]; then
        echo "Removing secret files"
        for file in "${secret_files[@]}"; do
            rm -f "${file}"
        done
        echo "Secret files removed"
    fi
}

# always run cleanup last, even on errors
trap 'exit_code=$?; cleanup; exit "$exit_code"' ERR
trap 'cleanup' EXIT

if [[ -n "${secrets_passphrase}" ]]; then
    echo "Environment variable 'secrets_passphrase' wasn't set. Checking if files are already present"
    check_for_secret_files
    echo "Files are present, moving forward"
    delete_secrets=true
else
  scripts/tests/ai/decrypt_secrets.sh
fi

echo "Selecting Xcode version: ${xcode}"
sudo xcode-select -s /Applications/"${xcode}".app/Contents/Developer
echo "Running integration tests for target: ${target}"
scripts/build.sh FirebaseAIIntegration "${target}"
