# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -ex

# Loop through arguments and process them
for arg in "$@"
do
  case $arg in
    --sdk=*)
      SDK="${arg#*=}"
      shift # Remove --sdk= from processing
      ;;
    --platform=*)
      PLATFORM="${arg#*=}"
      shift
      ;;
    --test_spec=*)
      TEST_SPEC="${arg#*=}"
      shift
      ;;
    --output_path=*)
      OUTPUT_PATH="${arg#*=}"
      shift
      ;;
  esac
done
DEFAULT_OUTPUT_PATH="/Users/runner/${SDK}-${PLATFORM}.xcresult"
DEFAULT_TEST_SPEC="unit"
OUTPUT_PATH="${OUTPUT_PATH:-${DEFAULT_OUTPUT_PATH}}"
TEST_SPEC="${TEST_SPEC:-${DEFAULT_TEST_SPEC}}"

[[ -z "$SDK" ]] && { echo "Parameter --sdk should be specified, e.g. --sdk=FirebaseStorage" ; exit 1; }
[[ -z "$PLATFORM" ]] && { echo "Parameter --platform should be specified, e.g. --platform=ios" ; exit 1; }

echo "SDK: ${SDK}"
echo "PLATFORM: ${PLATFORM}"
echo "OUTPUT_PATH: ${OUTPUT_PATH}"
echo "TEST_SPEC: ${TEST_SPEC}"

if [ -d "/Users/runner/Library/Developer/Xcode/DerivedData" ]; then
  rm -r /Users/runner/Library/Developer/Xcode/DerivedData/*
fi

# Setup for pod unit tests
if [ $SDK == "FirebasePerformance" ]; then
  scripts/setup_bundler.sh
  scripts/third_party/travis/retry.sh scripts/build.sh Performance ${PLATFORM} unit
elif [ $SDK == "FirebaseFirestore" ]; then
  scripts/install_prereqs.sh Firestore ${PLATFORM} xcodebuild
  scripts/third_party/travis/retry.sh scripts/build.sh Firestore ${PLATFORM} xcodebuild
else
  # Run unit tests of pods and put xcresult bundles into OUTPUT_PATH, which
  # should be a targeted dir of actions/upload-artifact in workflows.
  # In code coverage workflow, files under OUTPUT_PATH will be uploaded to
  # Github Actions.
  scripts/third_party/travis/retry.sh scripts/pod_lib_lint.rb "${SDK}".podspec --platforms="$(tr '[:upper:]' '[:lower:]'<<<${PLATFORM})" --test-specs="${TEST_SPEC}"
fi

find /Users/runner/Library/Developer/Xcode/DerivedData -type d -regex ".*/.*\.xcresult" -execdir cp -R '{}' "${OUTPUT_PATH}" \;
