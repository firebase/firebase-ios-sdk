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

# This is to generate pod size report and send to the Metrics Service.
# The Metrics Service will either
# 1. save binary size data into the databasae when POSTSUBMIT is true, or
# 2. post a report in a PR when POSTSUBMIT is not true.

set -ex

BINARY_SIZE_SDK=()

# In presubmits, `check` job in the health_metrics.yml workflow will turn on SDK flags if a corresponding
# file path, in `scripts/health_metrics/code_coverage_file_list.json` is updated.
# In postsubmits, all SDKs should be measured, so binary size data of all SDKs should be uploaded to a
# merged commit. Next time a new PR can compare the head of the PR to a commit on the base branch.
if [[ "${POSTSUBMIT}" == true || "${FirebaseABTesting}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebaseABTesting')
fi
if [[ "${POSTSUBMIT}" == true || "${FirebaseAnalytics}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebaseAnalytics')
fi
if [[ "${POSTSUBMIT}" == true || "${FirebaseAppCheck}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebaseAppCheck')
fi
if [[ "${POSTSUBMIT}" == true || "${FirebaseAppDistribution}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebaseAppDistribution')
fi
if [[ "${POSTSUBMIT}" == true || "${FirebaseAuth}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebaseAuth')
fi
if [[ "${POSTSUBMIT}" == true || "${FirebaseCrashlytics}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebaseCrashlytics')
fi
if [[ "${POSTSUBMIT}" == true || "${FirebaseDatabase}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebaseDatabase')
fi
if [[ "${POSTSUBMIT}" == true || "${FirebaseDynamicLinks}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebaseDynamicLinks')
fi
if [[ "${POSTSUBMIT}" == true || "${FirebaseFirestore}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebaseFirestore')
fi
if [[ "${POSTSUBMIT}" == true || "${FirebaseFunctions}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebaseFunctions')
fi
if [[ "${POSTSUBMIT}" == true || "${FirebaseInAppMessaging}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebaseInAppMessaging')
fi
if [[ "${POSTSUBMIT}" == true || "${FirebaseInstallations}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebaseInstallations')
fi
if [[ "${POSTSUBMIT}" == true || "${FirebaseMessaging}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebaseMessaging')
fi
if [[ "${POSTSUBMIT}" == true || "${FirebasePerformance}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebasePerformance');
fi
if [[ "${POSTSUBMIT}" == true || "${FirebaseRemoteConfig}" == 'true' ]]; then
  BINARY_SIZE_SDK+=('FirebaseRemoteConfig')
fi
if [[ "${POSTSUBMIT}" == true || "${FirebaseStorage}" == 'true' ]]; then
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
