#!/bin/bash

# Copyright 2020 Google LLC
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

# USAGE: run_database_emulator.sh { run | start | stop }
#
# Downloads and runs the Firebase Realtime Database emulator

set -euo pipefail

VERSION='4.12.0'
FILENAME="firebase-database-emulator-v${VERSION}.jar"
URL="https://storage.googleapis.com/firebase-preview-drop/emulator/${FILENAME}"

cache_dir="${HOME}/.cache/firebase/emulators"
jar="${cache_dir}/${FILENAME}"

cd $(git rev-parse --show-toplevel)
pid_file="firebase-database-emulator.pid"
log_file="firebase-database-emulator.log"

function help() {
  cat 1>&2 <<EOF
run_database_emulator.sh {run|start|stop}
EOF
}

# Downloads the emulator jar if it doesn't already exist
function ensure_exists() {
  if [[ ! -f "$jar" ]]; then
    echo "Downloading Firebase Realtime Database emulator" 1>&2
    mkdir -p "${cache_dir}"
    curl -s -o "${jar}" "${URL}"
  fi
}

# Runs the emulator synchronously
function run() {
  exec java -jar "$jar" "$@"
}

# Verifies the emulator isn't already running at the PID in the pid_file
function check_not_running() {
  if [[ -f "${pid_file}" ]]; then
    pid=$(cat "${pid_file}")
    if kill -0 "${pid}" >& /dev/null; then
      echo "Firebase Realtime Database emulator already running as PID ${pid}" 1>&2
      return 1
    fi

    echo "Removing stale PID file" 1>&2
    rm "${pid_file}"
  fi
}

# Starts the emulator in the background
function start() {
  check_not_running

  run "$@" >& "${log_file}" &
  pid="$!"
  echo "$pid" > "${pid_file}"
  echo "Firebase Realtime Database emulator running as PID ${pid}" 1>&2
}

# Stops the emulator if it's running
function stop() {
  if [[ -f "${pid_file}" ]]; then
    pid=$(cat "${pid_file}")
    kill "${pid}" || true
    rm "${pid_file}"
  fi
}

command=run
if [[ $# -gt 0 ]]; then
  command="$1"
  shift
fi

case "${command}" in
  run)
    ensure_exists
    run "$@"
    ;;

  start)
    ensure_exists
    start
    ;;

  stop)
    stop
    ;;

  download)
    ensure_exists
    ;;

  *)
    help
    exit 1
    ;;
esac
