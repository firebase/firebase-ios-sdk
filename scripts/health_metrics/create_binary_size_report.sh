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

# USAGE: git diff -U0 [base_commit] HEAD | get_diff_lines.sh
#
# This will generate a JSON output of changed files and their newly added
# lines.

BINARY_SIZE_SDK=()
BINARY_SIZE_SDK+=('FirebaseABTesting')
BINARY_SIZE_SDK+=('FirebaseAuth')
BINARY_SIZE_SDK+=('FirebaseFirestore')
BINARY_SIZE_SDK+=('FirebaseFunctions')
BINARY_SIZE_SDK+=('FirebaseInAppMessaging')
BINARY_SIZE_SDK+=('FirebaseMessaging')
BINARY_SIZE_SDK+=('FirebasePerformance');
BINARY_SIZE_SDK+=('FirebaseRemoteConfig')
BINARY_SIZE_SDK+=('FirebaseStorage')
if [ -n "$BINARY_SIZE_SDK" ]; then
  cd scripts/health_metrics/generate_code_coverage_report/
  git clone https://github.com/google/cocoapods-size
  swift build
  .build/debug/BinarySizeReportGenerator --binary-size-tool-dir cocoapods-size/  --sdk-repo-dir "${GITHUB_WORKSPACE}" --sdk ${BINARY_SIZE_SDK[@]} --log-path "https://github.com/firebase/firebase-ios-sdk/actions/runs/${GITHUB_RUN_ID}"
fi
