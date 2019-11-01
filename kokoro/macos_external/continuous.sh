#!/bin/bash

# Copyright 2019 Google
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Fail on any error.
set -e
# Display commands being run.
set -x

# Placeholder script to test GitHub webhooks. Eventually this script
# should be replaced by one job per test target.

# Here's an example of one build target in travis manually migrated
# to kokoro with no shared components:

cd ${KOKORO_ARTIFACTS_DIR}/github/firebase-ios-sdk

export PROJECT="Firestore"
export PLATFORM="iOS"
export METHOD="xcodebuild"

# before_install:
./kokoro/shared/before_install.sh

# Install prerequisites
./scripts/install_prereqs.sh

# Force xcpretty to use UTF8
export LC_CTYPE=en_US.UTF-8

./scripts/build.sh $PROJECT $PLATFORM $METHOD
