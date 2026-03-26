#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status,
# treat unset variables as an error, and catch pipeline failures.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "USAGE: $0 <platform>"
  exit 1
fi

PLATFORM_INPUT="$1"

# macOS and Catalyst run natively and do not need simulator runtimes downloaded
if [[ "$PLATFORM_INPUT" == "macOS" ]] || [[ "$PLATFORM_INPUT" == "catalyst" ]]; then
  echo "Platform is '$PLATFORM_INPUT'. No simulator download required."
  exit 0
fi

# Handle the 'all' case directly
if [[ "$PLATFORM_INPUT" == "all" ]]; then
  echo "Downloading all simulator platforms..."
  xcodebuild -downloadAllPlatforms
  exit 0
fi

# Clean up the platform input to get the core OS name
# (e.g., strips '-device' from 'iOS-device' to just search for 'iOS')
OS_KEY="${PLATFORM_INPUT%%-*}"
if [[ "$OS_KEY" == "iPad" ]]; then
  OS_KEY="iOS"
fi

echo "Checking for existing $OS_KEY simulator runtimes..."

# Count how many available runtimes match the target OS
HAS_SIM=$(xcrun simctl list devices available -j | jq -r --arg os "$OS_KEY" '
  .devices |
  to_entries |
  map(select(.key | contains($os))) |
  length
')

if [[ "$HAS_SIM" -gt 0 ]]; then
  echo "Found existing simulator runtime(s) for $OS_KEY. Skipping expensive download."
  exit 0
fi

echo "No simulator found for $OS_KEY. Executing download via xcodebuild..."
xcodebuild -downloadPlatform "$PLATFORM_INPUT"
