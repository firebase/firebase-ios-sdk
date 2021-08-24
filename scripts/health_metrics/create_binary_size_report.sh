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

set -ex

BINARY_SIZE_SDK=()
if $FirebaseABTesting == 'true'; then
  BINARY_SIZE_SDK+=('FirebaseABTesting')
fi
if $FirebaseAuth == 'true'; then
  BINARY_SIZE_SDK+=('FirebaseAuth')
fi
if $FirebaseDatabase == 'true'; then
  BINARY_SIZE_SDK+=('FirebaseDatabase')
fi
if $FirebaseDynamicLinks == 'true'; then
  BINARY_SIZE_SDK+=('FirebaseDynamicLinks')
fi
if $FirebaseFirestore == 'true'; then
  BINARY_SIZE_SDK+=('FirebaseFirestore')
fi
if $FirebaseFunctions == 'true'; then
  BINARY_SIZE_SDK+=('FirebaseFunctions')
fi
if $FirebaseInAppMessaging == 'true'; then
  BINARY_SIZE_SDK+=('FirebaseInAppMessaging')
fi
if $FirebaseMessaging == 'true'; then
  BINARY_SIZE_SDK+=('FirebaseMessaging')
fi
if $FirebasePerformance == 'true'; then
  BINARY_SIZE_SDK+=('FirebasePerformance');
fi
if $FirebaseRemoteConfig == 'true'; then
  BINARY_SIZE_SDK+=('FirebaseRemoteConfig')
fi
if $FirebaseStorage == 'true'; then
  BINARY_SIZE_SDK+=('FirebaseStorage')
fi
if [ -n "$BINARY_SIZE_SDK" ]; then
  cd scripts/health_metrics/generate_code_coverage_report/
  git clone https://github.com/google/cocoapods-size
  swift build
  if [[ "${POSTSUBMIT}" == true ]]; then
    .build/debug/BinarySizeReportGenerator --binary-size-tool-dir cocoapods-size/  --sdk-repo-dir "${GITHUB_WORKSPACE}" --sdk ${BINARY_SIZE_SDK[@]} --merge "firebase/firebase-ios-sdk" --head-commit "${GITHUB_SHA}" --token $(gcloud auth print-identity-token) --log-link "https://github.com/firebase/firebase-ios-sdk/actions/runs/${GITHUB_RUN_ID}" --source-branch "${SOURCE_BRANCH}"
  else
    .build/debug/BinarySizeReportGenerator --binary-size-tool-dir cocoapods-size/  --sdk-repo-dir "${GITHUB_WORKSPACE}" --sdk ${BINARY_SIZE_SDK[@]} --presubmit "firebase/firebase-ios-sdk" --head-commit "${GITHUB_SHA}" --token $(gcloud auth print-identity-token) --log-link "https://github.com/firebase/firebase-ios-sdk/actions/runs/${GITHUB_RUN_ID}" --pull-request-num "${PULL_REQUEST_NUM}" --base-commit "${BASE_COMMIT}"
  fi
fi
