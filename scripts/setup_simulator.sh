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

# Dynamically creates Apple simulator devices using installed runtimes.

set -euo pipefail

# Directory containing this script and its helpers.
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_DIR

# Creates a simulator, unless an available simulator with the same name exists,
# using the newest available runtime for a given platform that supports any of
# the requested device types.
# Globals:
#   SCRIPTS_DIR
# Arguments:
#   $1 - Platform name, or `|`-separated alternatives
#        (e.g. "iOS", "visionOS|xrOS")
#   $2 - Desired simulator device name (e.g. "Firebase-iPhone-15-Pro")
#   $3 - Simulator device type ID, or `|`-separated fallbacks in preference
#        order (e.g. "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro")
# Outputs:
#   Writes progress to stdout and diagnostics to stderr.
create_sim() {
  local platform_search="$1"
  local sim_name="$2"
  local device_types="$3"

  # Capture the device list before searching it: `simctl ... | grep -q` can
  # fail with SIGPIPE under `pipefail` when grep exits early, which would read
  # as "not found" and create a duplicate simulator.
  local devices
  devices=$(xcrun simctl list devices available) || return

  if grep -qF -- "    ${sim_name} (" <<< "$devices"; then
    echo "Simulator '$sim_name' already exists."
    return 0
  fi

  # Select the newest available runtime that supports any requested device
  # type. On failure, the helper prints the available runtimes and the function
  # returns non-zero.
  local selection
  selection=$(
    python3 "${SCRIPTS_DIR}/select_simulator_runtime.py" \
      --platform "$platform_search" \
      --device-type "$device_types"
  ) || return

  local device_type runtime
  read -r device_type runtime <<< "$selection"

  echo "Creating simulator '$sim_name' ($device_type, $runtime)..."
  xcrun simctl create "$sim_name" "$device_type" "$runtime" > /dev/null
}

main() {
  local platform="${1:-iOS}"

  local platform_clean
  platform_clean=$(
    echo "$platform" | awk '{print $1}' | tr '[:upper:]' '[:lower:]'
  )

  local device_prefix="com.apple.CoreSimulator.SimDeviceType"
  local ios_device="${device_prefix}.iPhone-15-Pro"
  local ipad_device="${device_prefix}.iPad-Pro--11-inch---2nd-generation-"
  local watch_device="${device_prefix}.Apple-Watch-Ultra-2-49mm"
  local tv_device="${device_prefix}.Apple-TV-4K-2nd-generation-1080p"
  local vision_devices
  vision_devices="${device_prefix}.Apple-Vision-Pro-4K"
  vision_devices+="|${device_prefix}.Apple-Vision-Pro"

  case "$platform_clean" in
    ios)
      create_sim "iOS" "Firebase-iPhone-15-Pro" "$ios_device"
      ;;
    ipad)
      create_sim "iOS" "Firebase-iPad-Pro-11-inch" "$ipad_device"
      ;;
    watchos)
      create_sim "watchOS" "Firebase-Apple-Watch-Ultra-2" "$watch_device"
      ;;
    tvos)
      create_sim "tvOS" "Firebase-Apple-TV-4K-Gen-2" "$tv_device"
      ;;
    visionos|xros)
      create_sim "visionOS|xrOS" "Firebase-Apple-Vision-Pro" "$vision_devices"
      ;;
    all)
      create_sim "iOS" "Firebase-iPhone-15-Pro" "$ios_device"
      create_sim "iOS" "Firebase-iPad-Pro-11-inch" "$ipad_device"
      create_sim "watchOS" "Firebase-Apple-Watch-Ultra-2" "$watch_device"
      create_sim "tvOS" "Firebase-Apple-TV-4K-Gen-2" "$tv_device"
      create_sim "visionOS|xrOS" "Firebase-Apple-Vision-Pro" "$vision_devices"
      ;;
    macos|catalyst|linux|ios-device)
      # No simulator creation needed
      ;;
    *)
      create_sim "iOS" "Firebase-iPhone-15-Pro" "$ios_device"
      ;;
  esac
}

main "$@"
