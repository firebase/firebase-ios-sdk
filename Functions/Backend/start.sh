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
cd "${TEMP_DIR}"
npm install

# Start the server.
FUNCTIONS_BIN="./node_modules/.bin/functions"
"${FUNCTIONS_BIN}" config set projectId functions-integration-test <<-!
  myproject
!
"${FUNCTIONS_BIN}" config set supervisorPort 5005
"${FUNCTIONS_BIN}" config set region us-central1
"${FUNCTIONS_BIN}" config set verbose true
"${FUNCTIONS_BIN}" restart
"${FUNCTIONS_BIN}" deploy dataTest --trigger-http
"${FUNCTIONS_BIN}" deploy scalarTest --trigger-http
"${FUNCTIONS_BIN}" deploy tokenTest --trigger-http
"${FUNCTIONS_BIN}" deploy FCMTokenTest --trigger-http
"${FUNCTIONS_BIN}" deploy nullTest --trigger-http
"${FUNCTIONS_BIN}" deploy missingResultTest --trigger-http
"${FUNCTIONS_BIN}" deploy unhandledErrorTest --trigger-http
"${FUNCTIONS_BIN}" deploy unknownErrorTest --trigger-http
"${FUNCTIONS_BIN}" deploy explicitErrorTest --trigger-http
"${FUNCTIONS_BIN}" deploy httpErrorTest --trigger-http
"${FUNCTIONS_BIN}" deploy timeoutTest --trigger-http

if [ "$1" != "synchronous" ]; then
  # Wait for the user to tell us to stop the server.
  echo "Functions emulator now running in ${TEMP_DIR}."
  read -n 1 -p "*** Press any key to stop the server. ***"
  echo "\nStopping the emulator..."
  "${FUNCTIONS_BIN}" stop
fi
