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

# Creates a simulator with the latest installed runtime for a given platform.
# Arguments:
#   $1 - Platform search string for simctl (e.g. "iOS", "watchOS")
#   $2 - Desired simulator device name (e.g. "Firebase-iPhone-15-Pro")
#   $3 - Simulator device type ID
#        (e.g. "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro")
create_sim() {
  local platform_search="$1"
  local sim_name="$2"
  local device_type="$3"

  local runtime
  runtime=$(
    xcrun simctl list runtimes |
      grep -i -E "$platform_search" |
      grep -v 'unavailable' |
      grep -o -E 'com\.apple\.CoreSimulator\.SimRuntime\.[a-zA-Z0-9.-]+' |
      tail -1 || true
  )

  if [[ -z "$runtime" ]]; then
    echo "Error: Could not find runtime for platform '$platform_search'." >&2
    exit 1
  fi

  if ! xcrun simctl list devices | grep -q "$sim_name"; then
    echo "Creating simulator '$sim_name' ($device_type)..."
    xcrun simctl create "$sim_name" "$device_type" "$runtime" > /dev/null
  else
    echo "Simulator '$sim_name' already exists."
  fi
}

# Returns Vision Pro device type for the installed visionOS runtime.
# Arguments:
#   $1 - Device type prefix string
get_vision_device() {
  local device_prefix="$1"
  local vision_runtime
  vision_runtime=$(
    xcrun simctl list runtimes |
      grep -i -E "visionOS|xrOS" |
      grep -v 'unavailable' |
      grep -o -E 'com\.apple\.CoreSimulator\.SimRuntime\.[a-zA-Z0-9.-]+' |
      tail -1 || true
  )
  if [[ "$vision_runtime" =~ xrOS-26|visionOS-26 ]]; then
    echo "${device_prefix}.Apple-Vision-Pro-4K"
  else
    echo "${device_prefix}.Apple-Vision-Pro"
  fi
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
  local vision_device

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
      vision_device=$(get_vision_device "$device_prefix")
      create_sim "visionOS|xrOS" "Firebase-Apple-Vision-Pro" "$vision_device"
      ;;
    all)
      vision_device=$(get_vision_device "$device_prefix")
      create_sim "iOS" "Firebase-iPhone-15-Pro" "$ios_device"
      create_sim "iOS" "Firebase-iPad-Pro-11-inch" "$ipad_device"
      create_sim "watchOS" "Firebase-Apple-Watch-Ultra-2" "$watch_device"
      create_sim "tvOS" "Firebase-Apple-TV-4K-Gen-2" "$tv_device"
      create_sim "visionOS|xrOS" "Firebase-Apple-Vision-Pro" "$vision_device"
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
