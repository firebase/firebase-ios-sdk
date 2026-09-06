#!/bin/bash

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

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="${1:-replay}"
CONFIG_FILE="${TEST_SERVER_CONFIG:-${SCRIPT_DIR}/test_server_config.yaml}"
RECORDING_DIR="${TEST_SERVER_RECORDING_DIR:-${SCRIPT_DIR}/recordings}"

# Locate test-server executable
TEST_SERVER_BIN="${TEST_SERVER_BIN:-}"
if [[ -z "${TEST_SERVER_BIN}" ]]; then
  if command -v test-server &> /dev/null; then
    TEST_SERVER_BIN="$(command -v test-server)"
  elif [[ -x "${HOME}/go/bin/test-server" ]]; then
    TEST_SERVER_BIN="${HOME}/go/bin/test-server"
  elif command -v go &> /dev/null && [[ -x "$(go env GOPATH 2>/dev/null)/bin/test-server" ]]; then
    TEST_SERVER_BIN="$(go env GOPATH)/bin/test-server"
  fi
fi

if [[ -z "${TEST_SERVER_BIN}" || ! -x "${TEST_SERVER_BIN}" ]]; then
  echo "Error: test-server executable not found." >&2
  echo "" >&2
  echo "To install google/test-server, run:" >&2
  echo "  go install github.com/google/test-server@latest" >&2
  echo "" >&2
  echo "Or download a pre-built binary from:" >&2
  echo "  https://github.com/google/test-server/releases" >&2
  echo "" >&2
  echo "Or set the TEST_SERVER_BIN environment variable to the path of your test-server binary." >&2
  exit 1
fi

case "${MODE}" in
  record|replay)
    ;;
  *)
    echo "Usage: $0 [record|replay]" >&2
    exit 1
    ;;
esac

mkdir -p "${RECORDING_DIR}"

# Auto-populate TEST_SERVER_SECRETS from environment variables if not explicitly provided
if [[ -z "${TEST_SERVER_SECRETS:-}" ]]; then
  SECRETS=()
  [[ -n "${FIREBASE_PROJECT_ID:-}" ]] && SECRETS+=("${FIREBASE_PROJECT_ID}")
  [[ -n "${GOOGLE_CLOUD_PROJECT:-}" ]] && SECRETS+=("${GOOGLE_CLOUD_PROJECT}")
  [[ -n "${GCLOUD_PROJECT:-}" ]] && SECRETS+=("${GCLOUD_PROJECT}")
  [[ -n "${FIREBASE_API_KEY:-}" ]] && SECRETS+=("${FIREBASE_API_KEY}")
  [[ -n "${GEMINI_API_KEY:-}" ]] && SECRETS+=("${GEMINI_API_KEY}")
  [[ -n "${GOOGLE_API_KEY:-}" ]] && SECRETS+=("${GOOGLE_API_KEY}")
  if [[ ${#SECRETS[@]} -gt 0 ]]; then
    TEST_SERVER_SECRETS=$(IFS=,; echo "${SECRETS[*]}")
    export TEST_SERVER_SECRETS
  fi
fi

echo "Starting test-server in ${MODE} mode..."
echo "  Binary:        ${TEST_SERVER_BIN}"
echo "  Configuration: ${CONFIG_FILE}"
echo "  Recordings:    ${RECORDING_DIR}"

exec "${TEST_SERVER_BIN}" "${MODE}" --config "${CONFIG_FILE}" --recording-dir "${RECORDING_DIR}"
