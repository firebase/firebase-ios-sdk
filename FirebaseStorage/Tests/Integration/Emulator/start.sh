#!/usr/bin/env bash

# Copyright 2026 Google LLC
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

# Starts the Storage and Auth emulators for the Storage integration tests, with
# the rules that the tests need, on the ports in firebase.json.

# With the "synchronous" argument, the script starts the emulators in the
# background and exits once they're ready, so that later commands can run the
# tests. Otherwise, the emulators run in the foreground.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="$(mktemp -d -t firebase-storage-emulator)"
echo "Setting up the emulators in ${TEMP_DIR}"

cp "${SCRIPT_DIR}/firebase.json" "${SCRIPT_DIR}/storage.rules" \
  "${SCRIPT_DIR}/package.json" "${TEMP_DIR}/"
cd "${TEMP_DIR}"
npm install --no-audit --no-fund

FIREBASE_BIN="./node_modules/.bin/firebase"
# A demo- project ID keeps the emulators from using any real project.
EMULATORS_START=(emulators:start --only auth,storage --project demo-storage-tests)

if [[ "${1:-}" == "synchronous" ]]; then
  echo "Starting the Storage and Auth emulators in the background..."
  nohup "${FIREBASE_BIN}" "${EMULATORS_START[@]}" > "${TEMP_DIR}/emulator.log" 2>&1 &
  EMULATOR_PID=$!
  echo "Emulator PID: ${EMULATOR_PID}"

  # The first start downloads the Storage rules runtime.
  COUNTER=0
  MAX_TRIES=180
  until grep -q "All emulators ready" "${TEMP_DIR}/emulator.log" 2>/dev/null; do
    if ! kill -0 "${EMULATOR_PID}" 2>/dev/null; then
      echo "The emulators exited unexpectedly."
      cat "${TEMP_DIR}/emulator.log"
      exit 1
    fi
    if [[ ${COUNTER} -eq ${MAX_TRIES} ]]; then
      echo "Timed out waiting for the emulators to start."
      cat "${TEMP_DIR}/emulator.log"
      exit 1
    fi
    sleep 1
    COUNTER=$((COUNTER + 1))
  done

  cat "${TEMP_DIR}/emulator.log"
  echo "The Storage and Auth emulators are ready on ports 9199 and 9099."
else
  "${FIREBASE_BIN}" "${EMULATORS_START[@]}"
fi
