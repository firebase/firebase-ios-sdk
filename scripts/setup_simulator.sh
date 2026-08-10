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
      tail -1 |
      awk '{print $NF}' || true
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

main() {
  local platform="${1:-iOS}"

  local platform_clean
  platform_clean=$(
    echo "$platform" | awk '{print $1}' | tr '[:upper:]' '[:lower:]'
  )

  local dev_prefix="com.apple.CoreSimulator.SimDeviceType"
  local ios_dev="${dev_prefix}.iPhone-15-Pro"
  local watch_dev="${dev_prefix}.Apple-Watch-Ultra-2-49mm"
  local tv_dev="${dev_prefix}.Apple-TV-4K-2nd-generation-1080p"
  local vision_dev="${dev_prefix}.Apple-Vision-Pro"
  local vision_runtime
  vision_runtime=$(
    xcrun simctl list runtimes |
      grep -i -E "visionOS|xrOS" |
      grep -v 'unavailable' |
      tail -1 |
      awk '{print $NF}' || true
  )
  if [[ "$vision_runtime" =~ xrOS-26|visionOS-26 ]]; then
    vision_dev="${dev_prefix}.Apple-Vision-Pro-4K"
  fi

  case "$platform_clean" in
    ios|ipad)
      create_sim "iOS" "Firebase-iPhone-15-Pro" "$ios_dev"
      ;;
    watchos)
      create_sim "watchOS" "Firebase-Apple-Watch-Ultra-2" "$watch_dev"
      ;;
    tvos)
      create_sim "tvOS" "Firebase-Apple-TV-4K-Gen-2" "$tv_dev"
      ;;
    visionos|xros)
      create_sim "visionOS|xrOS" "Firebase-Apple-Vision-Pro" "$vision_dev"
      ;;
    all)
      create_sim "iOS" "Firebase-iPhone-15-Pro" "$ios_dev"
      create_sim "watchOS" "Firebase-Apple-Watch-Ultra-2" "$watch_dev"
      create_sim "tvOS" "Firebase-Apple-TV-4K-Gen-2" "$tv_dev"
      create_sim "visionOS|xrOS" "Firebase-Apple-Vision-Pro" "$vision_dev"
      ;;
    macos|catalyst|linux|ios-device)
      # No simulator creation needed
      ;;
    *)
      create_sim "iOS" "Firebase-iPhone-15-Pro" "$ios_dev"
      ;;
  esac
}

main "$@"
