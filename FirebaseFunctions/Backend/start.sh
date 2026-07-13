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

# Sets up a project with the functions CLI and starts a backend to run
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
cd "${TEMP_DIR}"
npm install

# Start the server.
nohup npx firebase emulators:start --only functions --project functions-integration-test > firebase-emulator.log 2>&1 &
EMULATOR_PID=$!

# Wait for the emulator to be ready.
echo "Waiting for emulator to start..."
timeout=30
while [ $timeout -gt 0 ]; do
  if curl -s http://localhost:5005 > /dev/null; then
    echo "Emulator is ready!"
    break
  fi
  sleep 1
  timeout=$((timeout - 1))
done

if [ $timeout -eq 0 ]; then
  echo "Emulator failed to start within 30 seconds."
  cat firebase-emulator.log
  exit 1
fi

if [ "$1" != "synchronous" ]; then
  # Wait for the user to tell us to stop the server.
  echo "Functions emulator now running in ${TEMP_DIR}."
  read -n 1 -p "*** Press any key to stop the server. ***"
  echo -e "\nStopping the emulator..."
  kill $EMULATOR_PID 2>/dev/null || true
else
  disown $EMULATOR_PID
fi
