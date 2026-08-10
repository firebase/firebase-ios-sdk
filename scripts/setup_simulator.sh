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

set -euo pipefail

platform="${1:-iOS}"

create_sim() {
  local platform_search="$1"
  local sim_name="$2"
  local device_type="$3"

  local runtime
  runtime=$(xcrun simctl list runtimes | grep -i -E "$platform_search" | grep -v 'unavailable' | tail -1 | awk '{print $NF}')

  if [[ -z "$runtime" ]]; then
    echo "Warning: Could not find available runtime for platform search '$platform_search'." >&2
    return 0
  fi

  if ! xcrun simctl list devices | grep -q "$sim_name"; then
    echo "Creating simulator '$sim_name' ($device_type) with runtime '$runtime'..."
    xcrun simctl create "$sim_name" "$device_type" "$runtime" > /dev/null 2>&1 || true
  else
    echo "Simulator '$sim_name' already exists."
  fi
}

case "$platform" in
  iOS|iPad)
    create_sim "iOS" "Firebase-iPhone-15-Pro" "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"
    ;;
  watchOS)
    create_sim "watchOS" "Firebase-Apple-Watch-Ultra-2" "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Ultra-2-49mm"
    ;;
  tvOS)
    create_sim "tvOS" "Firebase-Apple-TV-4K-Gen-2" "com.apple.CoreSimulator.SimDeviceType.Apple-TV-4K-2nd-generation-1080p"
    ;;
  visionOS)
    create_sim "visionOS|xrOS" "Firebase-Apple-Vision-Pro" "com.apple.CoreSimulator.SimDeviceType.Apple-Vision-Pro"
    ;;
  all)
    create_sim "iOS" "Firebase-iPhone-15-Pro" "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"
    create_sim "watchOS" "Firebase-Apple-Watch-Ultra-2" "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Ultra-2-49mm"
    create_sim "tvOS" "Firebase-Apple-TV-4K-Gen-2" "com.apple.CoreSimulator.SimDeviceType.Apple-TV-4K-2nd-generation-1080p"
    create_sim "visionOS|xrOS" "Firebase-Apple-Vision-Pro" "com.apple.CoreSimulator.SimDeviceType.Apple-Vision-Pro"
    ;;
  macOS|catalyst|Linux)
    # No simulator creation needed
    ;;
  *)
    create_sim "$platform" "Firebase-iPhone-15-Pro" "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"
    ;;
esac
