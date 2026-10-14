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

# Runs GeminiLanguageModel integration tests through google/test-server.
#
# Usage:
#   scripts/test-server.sh record <test-filter> [swift test options...]
#   scripts/test-server.sh replay <test-filter> [swift test options...]
#   scripts/test-server.sh diff <test-filter> [swift test options...]
#   scripts/test-server.sh audit [--fix]
#   scripts/test-server.sh start <record|replay>
#   scripts/test-server.sh stop
#
# `record` proxies requests to the live backends and saves them under
# Tests/TestServer/recordings. Failed tests are re-recorded with a freshly started
# server, up to TEST_SERVER_MAX_ATTEMPTS (default 3) attempts.
#
# `replay` serves the recordings with credentials removed from the environment.
# If tests fail, it re-runs them with request capture and explains each request
# that didn't match a recording (like `diff`).
#
# `diff` replays tests with request capture and explains unmatched requests.
#
# `audit` checks that recordings only contain headers allowed by
# Tests/TestServer/recording-policy.json. `--fix` strips noisy response headers.
# `record` runs `audit --fix` automatically.
#
# `start` and `stop` manage a background server for other runners, such as
# xcodebuild on an iOS Simulator.
#
# Set TEST_SERVER_BINARY to use a locally built test-server binary.

set -euo pipefail

readonly TEST_SERVER_VERSION="v0.2.9"
# SHA-256 checksums published in google/test-server's sdks/typescript/checksums.json.
readonly CHECKSUM_DARWIN_ARM64="04162efa8d1e1e4545661619b2e672a0460fd242c155ae5e5607697be53ccb83"
readonly CHECKSUM_DARWIN_X86_64="60bcbe15ffda3bcf9a0d7809d42c50af88e46d26b9dfd15b67d8dbc5bbfa1c00"
readonly CHECKSUM_LINUX_ARM64="6b5d3b1c4c665ddecf6abd165e46f564fc10f7406b926cede048c450a975e6ab"
readonly CHECKSUM_LINUX_X86_64="715e5ec7db9c35ee1c644c95f1911184c7f085596679c7d56670a98fc6f308ff"

PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PACKAGE_DIR
readonly CONFIG_FILE="$PACKAGE_DIR/Tests/TestServer/test-server.yml"
readonly RECORDINGS_DIR="$PACKAGE_DIR/Tests/TestServer/recordings"
readonly POLICY_FILE="$PACKAGE_DIR/Tests/TestServer/recording-policy.json"
readonly DIAGNOSTICS="$PACKAGE_DIR/scripts/test_server_diagnostics.py"
readonly WORK_DIR="$PACKAGE_DIR/.build/test-server"
readonly PID_FILE="$WORK_DIR/test-server.pid"
readonly PROXY_PID_FILE="$WORK_DIR/capture-proxy.pid"
readonly LOG_FILE="$WORK_DIR/test-server.log"
readonly CAPTURE_CONFIG_FILE="$WORK_DIR/test-server-capture.yml"
readonly CAPTURE_LOG_FILE="$WORK_DIR/captured-requests.jsonl"
readonly XUNIT_FILE="$WORK_DIR/xunit.xml"
# Ports the tests connect to; must match `TestServerConfiguration`.
readonly TEST_PORTS=(1443 1444)
# In capture mode, test-server listens on these ports behind the capture proxy.
readonly CAPTURE_UPSTREAM_PORTS=(11443 11444)
readonly HEALTH_URLS=(
  "http://localhost:1443/test-server/health"
  "http://localhost:1444/test-server/health"
)
readonly MAX_ATTEMPTS="${TEST_SERVER_MAX_ATTEMPTS:-3}"
# Credentials that are redacted from recordings and removed from the replay environment.
readonly CREDENTIAL_VARIABLES=(
  GEMINI_API_KEY
  GOOGLE_API_KEY
  FIREBASE_API_KEY
  FIREBASE_APP_ID
  FIREBASE_PROJECT_ID
  AppCheckDebugToken
  FIRAAppCheckDebugToken
)

log() {
  echo "[test-server.sh] $*" >&2
}

die() {
  log "error: $*"
  exit 1
}

usage() {
  awk 'NR >= 17 && /^#/ { sub(/^# ?/, ""); print; next } NR > 17 { exit }' \
    "${BASH_SOURCE[0]}" >&2
  exit 1
}

# Prints the path to a verified test-server binary, downloading it if needed.
install_binary() {
  if [[ -n "${TEST_SERVER_BINARY:-}" ]]; then
    echo "$TEST_SERVER_BINARY"
    return
  fi

  local os arch checksum
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os-$arch" in
    Darwin-arm64) checksum="$CHECKSUM_DARWIN_ARM64" ;;
    Darwin-x86_64) checksum="$CHECKSUM_DARWIN_X86_64" ;;
    Linux-aarch64 | Linux-arm64)
      arch="arm64"
      checksum="$CHECKSUM_LINUX_ARM64"
      ;;
    Linux-x86_64) checksum="$CHECKSUM_LINUX_X86_64" ;;
    *) die "unsupported platform: $os $arch" ;;
  esac

  local install_dir="$WORK_DIR/$TEST_SERVER_VERSION"
  local binary="$install_dir/test-server"
  if [[ -x "$binary" ]]; then
    echo "$binary"
    return
  fi

  local archive="test-server_${os}_${arch}.tar.gz"
  local url="https://github.com/google/test-server/releases/download/$TEST_SERVER_VERSION/$archive"
  mkdir -p "$install_dir"
  log "Downloading $url"
  curl --fail --silent --show-error --location --output "$install_dir/$archive" "$url"

  local actual_checksum
  actual_checksum="$(shasum -a 256 "$install_dir/$archive" | cut -d ' ' -f 1)"
  if [[ "$actual_checksum" != "$checksum" ]]; then
    rm -f "$install_dir/$archive"
    die "checksum mismatch for $archive (got $actual_checksum)"
  fi
  tar -xzf "$install_dir/$archive" -C "$install_dir" test-server
  rm -f "$install_dir/$archive"
  echo "$binary"
}

# Prints a comma-separated list of credential values for TEST_SERVER_SECRETS.
collect_secrets() {
  local secrets="" name value
  for name in "${CREDENTIAL_VARIABLES[@]}"; do
    value="${!name:-}"
    if [[ -n "$value" ]]; then
      secrets="${secrets:+$secrets,}$value"
    fi
  done
  if [[ -n "${FIREBASE_PLIST_PATH:-}" && -f "$FIREBASE_PLIST_PATH" ]]; then
    for name in PROJECT_ID GOOGLE_APP_ID API_KEY; do
      value="$(/usr/libexec/PlistBuddy -c "Print :$name" "$FIREBASE_PLIST_PATH" 2>/dev/null || true)"
      if [[ -n "$value" ]]; then
        secrets="${secrets:+$secrets,}$value"
      fi
    done
  fi
  printf '%s' "$secrets"
}

is_running() {
  local pid_file="${1:-$PID_FILE}"
  [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null
}

wait_for_health() {
  local url attempt
  for url in "${HEALTH_URLS[@]}"; do
    for attempt in $(seq 1 40); do
      is_running || die "test-server exited during startup; see $LOG_FILE"
      if curl --fail --silent --output /dev/null "$url"; then
        continue 2
      fi
      sleep 0.25
    done
    die "test-server did not become healthy at $url; see $LOG_FILE"
  done
}

# Starts test-server in `record` or `replay` mode. With `capture`, test-server listens on
# shifted ports behind a proxy that logs each request for `test_server_diagnostics.py explain`.
start_server() {
  local mode="$1" capture="${2:-}" binary secrets="" config="$CONFIG_FILE"
  binary="$(install_binary)"
  stop_server
  mkdir -p "$WORK_DIR" "$RECORDINGS_DIR"

  if [[ "$mode" == "record" ]]; then
    secrets="$(collect_secrets)"
    [[ -n "$secrets" ]] || die "record mode requires credentials in the environment"
  fi

  echo "=== $(date -u '+%Y-%m-%dT%H:%M:%SZ') $mode $capture ===" >>"$LOG_FILE"
  if [[ "$capture" == "capture" ]]; then
    config="$CAPTURE_CONFIG_FILE"
    local sed_args=() listen_args=() index
    for index in "${!TEST_PORTS[@]}"; do
      sed_args+=(-e "s/source_port: ${TEST_PORTS[index]}\$/source_port: ${CAPTURE_UPSTREAM_PORTS[index]}/")
      listen_args+=(--listen "${TEST_PORTS[index]}:${CAPTURE_UPSTREAM_PORTS[index]}")
    done
    sed "${sed_args[@]}" "$CONFIG_FILE" >"$config"
    : >"$CAPTURE_LOG_FILE"
    python3 "$DIAGNOSTICS" proxy "${listen_args[@]}" --log "$CAPTURE_LOG_FILE" \
      >>"$LOG_FILE" 2>&1 &
    echo $! >"$PROXY_PID_FILE"
    disown
  fi

  TEST_SERVER_SECRETS="$secrets" "$binary" "$mode" \
    --config "$config" \
    --recording-dir "$RECORDINGS_DIR" \
    >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  # Detach from job control so stopping the server doesn't print "Terminated".
  disown
  wait_for_health
  log "Started test-server $TEST_SERVER_VERSION in $mode mode${capture:+ with request capture}" \
    "(log: $LOG_FILE)"
}

stop_process() {
  local pid_file="$1"
  if is_running "$pid_file"; then
    local pid
    pid="$(cat "$pid_file")"
    kill "$pid"
    while kill -0 "$pid" 2>/dev/null; do
      sleep 0.1
    done
  fi
  rm -f "$pid_file"
}

# Stops the server and capture proxy. Restarting clears test-server's in-memory recording
# state, which is required before re-recording a test.
stop_server() {
  stop_process "$PROXY_PID_FILE"
  stop_process "$PID_FILE"
}

# Runs `swift test` serially. test-server tracks request order per endpoint, so tests
# that share a server must not run concurrently.
run_tests() {
  local mode="$1"
  shift
  (
    cd "$PACKAGE_DIR"
    if [[ "$mode" == "replay" ]]; then
      for name in "${CREDENTIAL_VARIABLES[@]}" FIREBASE_PLIST_PATH; do
        unset "$name"
      done
    fi
    INTEGRATION_TEST_MODE="$mode" swift test --no-parallel "$@"
  )
}

# Prints `Suite/function` filters for test cases that failed in the given xUnit files.
failed_tests() {
  python3 - "$@" <<'EOF'
import sys
import xml.etree.ElementTree as ElementTree

failed = set()
for path in sys.argv[1:]:
    try:
        root = ElementTree.parse(path).getroot()
    except (OSError, ElementTree.ParseError):
        continue
    for case in root.iter("testcase"):
        if case.find("failure") is None and case.find("error") is None:
            continue
        suite = case.get("classname", "").split(".")[-1]
        function = case.get("name", "").split("(")[0]
        if suite and function:
            failed.add(f"{suite}/{function}")
print("\n".join(sorted(failed)))
EOF
}

# Sets FILTER_ARGS to `--filter` arguments for newline-separated test filters.
set_filter_args() {
  local test
  FILTER_ARGS=()
  while IFS= read -r test; do
    FILTER_ARGS+=(--filter "$test")
  done <<<"$1"
}

# Replays tests with request capture, then explains requests that didn't match a recording.
explain_mismatches() {
  start_server replay capture
  run_tests replay "$@" >/dev/null 2>&1 || true
  stop_server
  python3 "$DIAGNOSTICS" explain \
    --log "$CAPTURE_LOG_FILE" \
    --recordings "$RECORDINGS_DIR" \
    --config "$CONFIG_FILE"
}

# Checks recorded headers against the recording policy. Pass `--fix` to strip noisy
# response headers first.
audit_recordings() {
  python3 "$DIAGNOSTICS" audit --recordings "$RECORDINGS_DIR" --policy "$POLICY_FILE" "$@"
}

record() {
  local filter="$1"
  shift
  local filters=(--filter "$filter")
  local attempt=1 status failed

  trap stop_server EXIT
  while true; do
    rm -f "$WORK_DIR"/xunit*.xml
    start_server record
    status=0
    run_tests record "${filters[@]}" --xunit-output "$XUNIT_FILE" "$@" || status=$?
    stop_server

    if ((status == 0)); then
      log "Recording succeeded on attempt $attempt."
      audit_recordings --fix
      return
    fi
    if ((attempt >= MAX_ATTEMPTS)); then
      log "Recording failed after $attempt attempts."
      audit_recordings --fix || true
      return "$status"
    fi

    failed="$(failed_tests "$WORK_DIR"/xunit*.xml)"
    if [[ -z "$failed" ]]; then
      log "No failed tests found in xUnit output; not retrying."
      return "$status"
    fi
    set_filter_args "$failed"
    filters=("${FILTER_ARGS[@]}")
    attempt=$((attempt + 1))
    log "Re-recording failed tests (attempt $attempt of $MAX_ATTEMPTS): ${failed//$'\n'/, }"
  done
}

replay() {
  local filter="$1"
  shift
  local status=0 failed

  trap stop_server EXIT
  rm -f "$WORK_DIR"/xunit*.xml
  start_server replay
  run_tests replay --filter "$filter" --xunit-output "$XUNIT_FILE" "$@" || status=$?
  stop_server
  if ((status == 0)); then
    return 0
  fi

  failed="$(failed_tests "$WORK_DIR"/xunit*.xml)"
  if [[ -n "$failed" ]]; then
    log "Explaining unmatched requests for: ${failed//$'\n'/, }"
    set_filter_args "$failed"
    explain_mismatches "${FILTER_ARGS[@]}" "$@"
  fi
  return "$status"
}

diff_requests() {
  local filter="$1"
  shift
  trap stop_server EXIT
  explain_mismatches --filter "$filter" "$@"
}

main() {
  [[ $# -ge 1 ]] || usage
  local command="$1"
  shift
  case "$command" in
    record | replay)
      [[ $# -ge 1 ]] || usage
      "$command" "$@"
      ;;
    diff)
      [[ $# -ge 1 ]] || usage
      diff_requests "$@"
      ;;
    start)
      [[ $# -eq 1 && ("$1" == "record" || "$1" == "replay") ]] || usage
      start_server "$1"
      ;;
    audit) audit_recordings "$@" ;;
    stop) stop_server ;;
    *) usage ;;
  esac
}

main "$@"
