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

# Returns the simulator runtime ID for a given platform search string,
# preferring the latest installed runtime matching the active Xcode's SDK
# major version (so it aligns with xcodebuild's implicit OS:latest resolution).
# Arguments:
#   $1 - Platform search string for simctl (e.g. "iOS", "watchOS")
get_runtime() {
  local platform_search="$1"

  local sdk_name=""
  case "$platform_search" in
    iOS) sdk_name="iphonesimulator" ;;
    watchOS) sdk_name="watchsimulator" ;;
    tvOS) sdk_name="appletvsimulator" ;;
    *visionOS*|*xrOS*) sdk_name="xrsimulator" ;;
  esac

  local sdk_version=""
  if [[ -n "$sdk_name" ]]; then
    sdk_version=$(xcrun --sdk "$sdk_name" --show-sdk-version 2>/dev/null || true)
  fi

  local available_runtimes
  available_runtimes=$(
    xcrun simctl list runtimes |
      grep -i -E "$platform_search" |
      grep -v 'unavailable' |
      grep -o -E 'com\.apple\.CoreSimulator\.SimRuntime\.[a-zA-Z0-9.-]+' || true
  )

  local runtime=""
  if [[ -n "$sdk_version" && -n "$available_runtimes" ]]; then
    local sdk_major="${sdk_version%%.*}"
    runtime=$(
      echo "$available_runtimes" |
        grep -E -- "-${sdk_major}-" |
        tail -1 || true
    )
  fi

  # Fallback to the latest available runtime if a matching SDK runtime is not found.
  if [[ -z "$runtime" && -n "$available_runtimes" ]]; then
    runtime=$(echo "$available_runtimes" | tail -1 || true)
  fi

  echo "$runtime"
}

# Creates a simulator with the target runtime for a given platform.
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
  runtime=$(get_runtime "$platform_search")

  if [[ -z "$runtime" ]]; then
    echo "Error: Could not find runtime for platform '$platform_search'." >&2
    exit 1
  fi

  if ! xcrun simctl list devices | grep -q "$sim_name"; then
    echo "Creating simulator '$sim_name' ($device_type) with runtime '$runtime'..."
    xcrun simctl create "$sim_name" "$device_type" "$runtime" > /dev/null
  else
    echo "Simulator '$sim_name' already exists."
  fi
}

# Returns iPhone device type for the target iOS runtime.
# Arguments:
#   $1 - Device type prefix string
get_ios_device() {
  local device_prefix="$1"
  local ios_runtime
  ios_runtime=$(get_runtime "iOS")
  if [[ "$ios_runtime" =~ iOS-27-[1-9] ]]; then
    echo "${device_prefix}.iPhone-Duo"
  else
    echo "${device_prefix}.iPhone-15-Pro"
  fi
}

# Returns Vision Pro device type for the target visionOS runtime.
# Arguments:
#   $1 - Device type prefix string
get_vision_device() {
  local device_prefix="$1"
  local vision_runtime
  vision_runtime=$(get_runtime "visionOS|xrOS")
  if [[ "$vision_runtime" =~ (xrOS|visionOS)-[12]- ]]; then
    echo "${device_prefix}.Apple-Vision-Pro"
  else
    echo "${device_prefix}.Apple-Vision-Pro-4K"
  fi
}

main() {
  local platform="${1:-iOS}"

  local platform_clean
  platform_clean=$(
    echo "$platform" | awk '{print $1}' | tr '[:upper:]' '[:lower:]'
  )

  local device_prefix="com.apple.CoreSimulator.SimDeviceType"
  local ios_device
  local ipad_device="${device_prefix}.iPad-Pro--11-inch---2nd-generation-"
  local watch_device="${device_prefix}.Apple-Watch-Ultra-2-49mm"
  local tv_device="${device_prefix}.Apple-TV-4K-2nd-generation-1080p"
  local vision_device

  case "$platform_clean" in
    ios)
      ios_device=$(get_ios_device "$device_prefix")
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
      ios_device=$(get_ios_device "$device_prefix")
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
      ios_device=$(get_ios_device "$device_prefix")
      create_sim "iOS" "Firebase-iPhone-15-Pro" "$ios_device"
      ;;
  esac
}

main "$@"
