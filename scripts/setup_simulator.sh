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

# Creates a simulator with the target runtime for a given platform, trying each
# candidate device type in order until creation succeeds.
# Arguments:
#   $1 - Platform search string for simctl (e.g. "iOS", "watchOS")
#   $2 - Desired simulator device name (e.g. "Firebase-iPhone-15-Pro")
#   $3... - One or more candidate simulator device type IDs to try in order
#           (e.g. "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro")
create_sim() {
  local platform_search="$1"
  local sim_name="$2"
  shift 2
  local device_types=("$@")

  local runtime
  runtime=$(get_runtime "$platform_search")

  if [[ -z "$runtime" ]]; then
    echo "Error: Could not find runtime for platform '$platform_search'." >&2
    exit 1
  fi

  if xcrun simctl list devices available | grep -Fq "${sim_name} ("; then
    echo "Simulator '$sim_name' already exists and is available."
    return 0
  fi

  # Clean up any existing (but unavailable) simulators with the same name to avoid duplicates.
  xcrun simctl list devices | grep -F "${sim_name} (" | grep -oE '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' | while read -r uuid; do
    echo "Removing existing/unavailable simulator $uuid..."
    xcrun simctl delete "$uuid" || true
  done || true

  local device_type
  for device_type in "${device_types[@]}"; do
    echo "Creating simulator '$sim_name' ($device_type) with runtime '$runtime'..."
    if xcrun simctl create "$sim_name" "$device_type" "$runtime" > /dev/null; then
      return 0
    fi
    echo "Warning: Failed to create '$sim_name' with device type" \
      "'$device_type' and runtime '$runtime'; trying next fallback if" \
      "available..." >&2
  done

  echo "Error: Could not create simulator '$sim_name' with runtime '$runtime'" \
    "using any candidate device type: ${device_types[*]}" >&2
  exit 1
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
  local ios_devices=(
    "${device_prefix}.iPhone-15-Pro"
    "${device_prefix}.iPhone-16-Pro"
    "${device_prefix}.iPhone-17-Pro"
    "${device_prefix}.iPhone-Duo"
  )
  local ipad_device="${device_prefix}.iPad-Pro--11-inch---2nd-generation-"
  local watch_devices=(
    "${device_prefix}.Apple-Watch-Ultra-2-49mm"
    "${device_prefix}.Apple-Watch-Ultra-3-49mm"
    "${device_prefix}.Apple-Watch-Ultra-4-49mm"
    "${device_prefix}.Apple-Watch-SE-3-44mm"
  )
  local tv_devices=(
    "${device_prefix}.Apple-TV-4K-2nd-generation-1080p"
    "${device_prefix}.Apple-TV-4K-3rd-generation-1080p"
  )
  local vision_device

  case "$platform_clean" in
    ios)
      create_sim "iOS" "Firebase-iPhone-15-Pro" "${ios_devices[@]}"
      ;;
    ipad)
      create_sim "iOS" "Firebase-iPad-Pro-11-inch" "$ipad_device"
      ;;
    watchos)
      create_sim "watchOS" "Firebase-Apple-Watch-Ultra-2" "${watch_devices[@]}"
      ;;
    tvos)
      create_sim "tvOS" "Firebase-Apple-TV-4K-Gen-2" "${tv_devices[@]}"
      ;;
    visionos|xros)
      vision_device=$(get_vision_device "$device_prefix")
      create_sim "visionOS|xrOS" "Firebase-Apple-Vision-Pro" "$vision_device"
      ;;
    all)
      vision_device=$(get_vision_device "$device_prefix")
      create_sim "iOS" "Firebase-iPhone-15-Pro" "${ios_devices[@]}"
      create_sim "iOS" "Firebase-iPad-Pro-11-inch" "$ipad_device"
      create_sim "watchOS" "Firebase-Apple-Watch-Ultra-2" "${watch_devices[@]}"
      create_sim "tvOS" "Firebase-Apple-TV-4K-Gen-2" "${tv_devices[@]}"
      create_sim "visionOS|xrOS" "Firebase-Apple-Vision-Pro" "$vision_device"
      ;;
    macos|catalyst|linux|ios-device)
      # No simulator creation needed
      ;;
    *)
      create_sim "iOS" "Firebase-iPhone-15-Pro" "${ios_devices[@]}"
      ;;
  esac
}

main "$@"
