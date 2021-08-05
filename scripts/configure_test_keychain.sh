#!/usr/bin/env bash

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

set -euo pipefail
set -o xtrace

TEST_KEYCHAIN_NAME="temp.keychain"
TEST_KEYCHAIN_PASSWORD="temp.keychain.password"

# Print list of existing keychains.
security list-keychains

# Print current default keychain.
security default-keychain

# Remove test keychain form previous runs if exists.
if security delete-keychain "$TEST_KEYCHAIN_NAME"; then
  echo "Old test keychain was removed."
else
  echo "All good, no old test keychain found."
fi

# Create a test keychain.
security create-keychain -p "$TEST_KEYCHAIN_PASSWORD" "$TEST_KEYCHAIN_NAME"

# Disable auto-locking.
security set-keychain-settings "$TEST_KEYCHAIN_NAME"

# Unlock the test keychain.
security unlock-keychain -p "$TEST_KEYCHAIN_PASSWORD" "$TEST_KEYCHAIN_NAME"

# Set the test keychain as default to be used during macOS tests.
security default-keychain -s "$TEST_KEYCHAIN_NAME"
