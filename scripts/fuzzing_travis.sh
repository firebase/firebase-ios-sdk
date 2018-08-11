#!/usr/bin/env bash
##
# Copyright 2018 Google
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

# Run fuzz testing using xcodebuild. Given a total fuzzing duration, select
# a fuzzing target to run for half of the fuzzing duration. The remaining
# duration is split equally over the rest of the fuzzing targets. Must be run
# from the project root directory.

# Run fuzz testing only if executing on xcode >= 9 because fuzzing requires
# Clang that supports -fsanitize-coverage=trace-pc-guard.
xcode_version="$(xcodebuild -version | head -n 1)"
xcode_version="${xcode_version/Xcode /}"
xcode_major="${xcode_version/.*/}"

if [[ "${xcode_major}" -lt 9 ]]; then
  echo "Unsupported version of xcode."
  return 0;
fi

# Total time allowed for fuzzing in seconds (4 minutes for now).
ALLOWED_TIME=240

# Helper to run fuzz tests using xcodebuild. Takes the fuzzing target as the
# first argument and the fuzzing duration as the second argument.
function run_xcode_fuzzing() {
  xcodebuild \
    -workspace 'Firestore/Example/Firestore.xcworkspace' \
    -scheme 'Firestore_FuzzTests_iOS' \
    -sdk 'iphonesimulator' \
    -destination 'platform=iOS Simulator,name=iPhone 7' \
    FUZZING_TARGET="$1" \
    FUZZING_DURATION="$2" \
    test
}

# Run fuzz testing with an INVALID_TARGET and grep the response message line
# that contains 'Available targets'.
FUZZING_TARGETS_LINE="$(run_xcode_fuzzing "INVALID_TARGET" "0" \
    | grep "Available targets: {")"

# The FUZZING_TARGETS_LINE string contains { TARGET1 TARGET2 ... TARGETN }.
# The following command extracts the target and splits them into an array
# in the variable ALL_FUZZING_TARGETS.
read -r -a ALL_FUZZING_TARGETS <<< "$(echo ${FUZZING_TARGETS_LINE} \
    | cut -d "{" -f2 | cut -d "}" -f1)"

# Remove "NONE" from targets, if it exists.
for i in "${!ALL_FUZZING_TARGETS[@]}"; do
  if [[ "${ALL_FUZZING_TARGETS[${i}]}" = "NONE" ]]; then
    unset ALL_FUZZING_TARGETS[${i}]
  fi
done

# Count all targets.
FUZZING_TARGETS_COUNT="${#ALL_FUZZING_TARGETS[@]}"

# Get day of the year and use it to select a target.
DOY="$(date +%j)"
TARGET="$(( ${DOY} % ${FUZZING_TARGETS_COUNT} ))"

# Spend half of allowed time on the selected target and half on the remaining
# targets.
TARGET_TIME="$(( ${ALLOWED_TIME} / 2 ))"
REMAINING_TIME="$(( ${ALLOWED_TIME} / 2 / $(( ${FUZZING_TARGETS_COUNT} - 1)) ))"

# Return value; 0 is success and non-zero means fail.
SCRIPT_RETURN=0
for i in "${!ALL_FUZZING_TARGETS[@]}"; do
  FUZZING_DURATION="${REMAINING_TIME}"
  if [[ "${i}" -eq "${TARGET}" ]]; then
    FUZZING_DURATION="${TARGET_TIME}"
  fi
  FUZZING_TARGET="${ALL_FUZZING_TARGETS[${i}]}"

  echo "Running fuzzing target ${FUZZING_TARGET} for ${FUZZING_DURATION} seconds..."
  FUZZING_RESULTS="$(run_xcode_fuzzing "${FUZZING_TARGET}" "${FUZZING_DURATION}")"
  # Get the last line of the fuzzing results.
  FUZZING_RESULTS_LAST_LINE="$(echo "${FUZZING_RESULTS}" | tail -n1)"
  # If fuzzing succeeded, the last line will start with "Done"; otherwise,
  # print all fuzzing results.
  if [[ "${FUZZING_RESULTS_LAST_LINE}" == Done* ]]; then
    echo "Fuzz testing for target ${FUZZING_TARGET} succeeded. Disregard the ** TEST FAILED ** message."
  else
    echo "Error: Fuzz testing for target ${FUZZING_TARGET} failed."
    SCRIPT_RETURN=-1
    echo "Fuzzing logs:"
    echo "${FUZZING_RESULTS}"
  fi
done

exit ${SCRIPT_RETURN}
