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
# from the project root directory. The script is intended to execute on travis
# cron jobs, but can run locally (on a macOS) from the project root.

# Total time allowed for fuzzing in seconds (25 minutes for now).
readonly ALLOWED_TIME=1500

# An invalid target that is used to retrieve the list of available targets in
# the returned error message.
readonly INVALID_TARGET="INVALID_TARGET"
# The NONE target that does not perform fuzzing. It is valid but useless.
readonly NONE_TARGET="NONE"

# Script exit codes.
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1

# Get day of the year to use it when selecting a main target.
readonly DOY="$(date +%j)"

# How many last lines of the log to output for a failing job. This is to avoid
# exceeding Travis log size limit (4 Mb).
readonly LINES_TO_OUTPUT=500

# Run fuzz testing only if executing on xcode >= 9 because fuzzing requires
# Clang that supports -fsanitize-coverage=trace-pc-guard.
xcode_version="$(xcodebuild -version | head -n 1)"
xcode_version="${xcode_version/Xcode /}"
xcode_major="${xcode_version/.*/}"

if [[ "${xcode_major}" -lt 9 ]]; then
  echo "Unsupported version of xcode."
  exit ${EXIT_SUCCESS}
fi

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
# that contains the string 'Available targets: {'.
fuzzing_targets_line="$(run_xcode_fuzzing ${INVALID_TARGET} "0" \
    | grep "Available targets: {")"

# The fuzzing_targets_line string contains { TARGET1 TARGET2 ... TARGETN }.
# The following command extracts the targets and splits them into an array
# in the variable all_fuzzing_targets.
read -r -a all_fuzzing_targets <<< "$(echo ${fuzzing_targets_line} \
    | cut -d "{" -f2 | cut -d "}" -f1)"

# Remove the NONE target, if it exists.
for i in "${!all_fuzzing_targets[@]}"; do
  if [[ "${all_fuzzing_targets[${i}]}" == ${NONE_TARGET} ]]; then
    unset all_fuzzing_targets[${i}]
  fi
done

# Count all targets.
readonly fuzzing_targets_count="${#all_fuzzing_targets[@]}"

# Select a primary target to fuzz test for longer. Changes daily. The variable
# todays_primary_target contains the index of the target selected as primary.
todays_primary_target="$(( ${DOY} % ${fuzzing_targets_count} ))"

# Spend half of allowed time on the selected primary target and half on the
# remaining targets.
primary_target_time="$(( ${ALLOWED_TIME} / 2 ))"
other_targets_time="$(( ${ALLOWED_TIME} / 2 / $(( ${fuzzing_targets_count} - 1)) ))"

script_return=${EXIT_SUCCESS}
for i in "${!all_fuzzing_targets[@]}"; do
  fuzzing_duration="${other_targets_time}"
  if [[ "${i}" -eq "${todays_primary_target}" ]]; then
    fuzzing_duration="${primary_target_time}"
  fi
  fuzzing_target="${all_fuzzing_targets[${i}]}"

  echo "Running fuzzing target ${fuzzing_target} for ${fuzzing_duration} seconds..."
  fuzzing_results="$(run_xcode_fuzzing "${fuzzing_target}" "${fuzzing_duration}")"
  # Get the last line of the fuzzing results.
  fuzzing_results_last_line="$(echo "${fuzzing_results}" | tail -n1)"
  # If fuzzing succeeded, the last line will start with "Done"; otherwise,
  # print all fuzzing results.
  if [[ "${fuzzing_results_last_line}" == Done* ]]; then
    echo "Fuzz testing for target ${fuzzing_target} succeeded. Ignore the ** TEST FAILED ** message."
  else
    echo "Error: Fuzz testing for target ${fuzzing_target} failed."
    script_return=${EXIT_FAILURE}
    echo "Fuzzing logs:"
    echo "${fuzzing_results}" | tail -n${LINES_TO_OUTPUT}
    echo "End fuzzing logs"
  fi
done

exit ${script_return}
