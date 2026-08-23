#!/usr/bin/env bash

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

# Sets up a project with firebase-tools and starts a backend to run
# integration tests against.

# Adding the "synchronous" parameter will cause the script to exit
# with the server still running so that other scripts can invoke this
# script followed by subsequent dependent commands.

set -e

# Get the absolute path to the directory containing this script.
SCRIPT_DIR="$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)"
TEMP_DIR="$(mktemp -d -t firebase-functions)"
echo "Creating functions in ${TEMP_DIR}"

# Set up the functions directory.
cp "${SCRIPT_DIR}/index.js" "${TEMP_DIR}/"
cp "${SCRIPT_DIR}/package.json" "${TEMP_DIR}/"
cp "${SCRIPT_DIR}/firebase.json" "${TEMP_DIR}/"
cp "${SCRIPT_DIR}/.firebaserc" "${TEMP_DIR}/"
cd "${TEMP_DIR}"
npm install --no-audit --no-fund

FIREBASE_BIN="./node_modules/.bin/firebase"

if [ "$1" == "synchronous" ]; then
  echo "Starting Firebase Functions Emulator in background..."
  nohup "${FIREBASE_BIN}" emulators:start --only functions > "${TEMP_DIR}/emulator.log" 2>&1 &
  EMULATOR_PID=$!
  echo "Emulator PID: ${EMULATOR_PID}"

  # Wait until the emulator is ready on port 5005
  echo "Waiting for functions emulator to be ready..."
  COUNTER=0
  MAX_TRIES=60
  until grep -q "All emulators ready" "${TEMP_DIR}/emulator.log" 2>/dev/null || [ $COUNTER -eq $MAX_TRIES ]; do
    if ! kill -0 "${EMULATOR_PID}" 2>/dev/null; then
      echo "Emulator process died unexpectedly."
      cat "${TEMP_DIR}/emulator.log"
      exit 1
    fi
    sleep 1
    COUNTER=$((COUNTER + 1))
  done

  if [ $COUNTER -eq $MAX_TRIES ]; then
    echo "Timed out waiting for Firebase Functions Emulator to start."
    cat "${TEMP_DIR}/emulator.log"
    exit 1
  fi

  cat "${TEMP_DIR}/emulator.log"
  echo "Firebase Functions Emulator ready on port 5005."
else
  echo "Functions emulator running in ${TEMP_DIR}."
  "${FIREBASE_BIN}" emulators:start --only functions
fi
