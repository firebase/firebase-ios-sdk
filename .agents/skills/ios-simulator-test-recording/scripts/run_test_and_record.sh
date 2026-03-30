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

set -e

SHOW_UI=false
VIDEO_PATH="simulator_test_walkthrough.mp4"
UDID=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --show-ui) SHOW_UI=true; shift ;;
        --video) VIDEO_PATH="$2"; shift 2 ;;
        --udid) UDID="$2"; shift 2 ;;
        --) shift; break ;;
        -*) echo "Unknown parameter passed: $1"; exit 1 ;;
        *) break ;;
    esac
done

if [[ -z "$UDID" ]]; then
    echo "0. Auto-selecting latest iOS Simulator..."
    UDID=$(python3 -c "
import json, subprocess, re
try:
    data = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))
    runtimes = sorted([r for r in data['devices'].keys() if 'iOS' in r], reverse=True)
    if not runtimes: exit(1)
    
    def iphone_rank(d):
        name = d['name']
        if 'SE' in name: return (-1, 0, name)
        match = re.search(r'iPhone\s+(\d+)', name)
        num = int(match.group(1)) if match else 0
        tier = 0
        if 'Pro Max' in name: tier = 1
        elif 'Pro' in name: tier = 3
        elif 'Plus' in name: tier = 0
        else: tier = 2 # Standard
        return (num, tier, name)
        
    iphones = [d for d in data['devices'][runtimes[0]] if 'iPhone' in d['name']]
    if not iphones: exit(1)
    iphones.sort(key=iphone_rank, reverse=True)
    print(iphones[0]['udid'])
except Exception:
    exit(1)
")
    if [[ -z "$UDID" ]]; then
        echo "Error: Could not auto-detect the latest iOS Simulator. Please provide a --udid manually."
        exit 1
    fi
    echo "Selected UDID: $UDID"
fi

if [[ -z "$1" ]]; then
    echo "Error: No test command provided."
    echo ""
    echo "Usage: ./run_test_and_record.sh [--show-ui] [--video PATH] [--udid UDID] -- xcodebuild test ..."
    echo "Note: Use the \{UDID\} placeholder in your test command to substitute the selected device UDID."
    exit 1
fi

echo "1. Preparing test command..."
# Substitute {UDID} with actual UDID in the arguments
TEST_CMD=()
for arg in "$@"; do
    TEST_CMD+=("${arg//\{UDID\}/$UDID}")
done

BUILD_CMD=()
IS_XCODEBUILD_TEST=false

# Try building _before_ running, that way we don't end up with a blank simulator recording for a test that wouldn't build.
if [[ "${TEST_CMD[0]}" == "xcodebuild" ]]; then
    for i in "${!TEST_CMD[@]}"; do
        if [[ "${TEST_CMD[$i]}" == "test" || "${TEST_CMD[$i]}" == "test-without-building" ]]; then
            IS_XCODEBUILD_TEST=true
            # Create a dedicated build command
            BUILD_CMD=("${TEST_CMD[@]}")
            if [[ "${TEST_CMD[$i]}" == "test" ]]; then
                BUILD_CMD[$i]="build-for-testing"
                TEST_CMD[$i]="test-without-building"
            fi

            # Prevent Xcode from spawning clones ("Clone 1 of iPhone...") which ruins video capture targeting the base UDID
            TEST_CMD+=("-disable-concurrent-destination-testing" "-parallel-testing-enabled" "NO")
            BUILD_CMD+=("-disable-concurrent-destination-testing" "-parallel-testing-enabled" "NO")
            break
        fi
    done
fi

if [ "$IS_XCODEBUILD_TEST" = true ]; then
    echo "1a. Auto-detected 'xcodebuild test'. Running 'build-for-testing' before booting simulator..."
    echo "\$ ${BUILD_CMD[@]}"
    set +e
    "${BUILD_CMD[@]}"
    BUILD_RESULT=$?
    set -e

    if [ $BUILD_RESULT -ne 0 ]; then
        echo "Error: Compilation failed (Exit $BUILD_RESULT). Aborting video recording and simulator boot."
        exit $BUILD_RESULT
    fi
fi

echo "2. Booting simulator $UDID..."
xcrun simctl boot "$UDID" || true

if [ "$SHOW_UI" = true ]; then
    echo "Showing Simulator UI..."
    open -a Simulator
fi

# Move the old video file if it still exists.
if [[ -f "$VIDEO_PATH" ]]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    FILENAME=$(basename "$VIDEO_PATH")
    EXTENSION="${FILENAME##*.}"
    FILENAME_NO_EXT="${FILENAME%.*}"
    DIRNAME=$(dirname "$VIDEO_PATH")
    BACKUP_PATH="$DIRNAME/${FILENAME_NO_EXT}_${TIMESTAMP}.${EXTENSION}"
    echo "Found existing video. Renaming old file to $BACKUP_PATH..."
    mv "$VIDEO_PATH" "$BACKUP_PATH"
fi

echo "3. Starting xcodebuild testing payload..."

rm -f "/tmp/simctl_record_pid_$$.txt"

# Run xcodebuild natively against a TTY terminal via 'script' to prevent block-buffering, then stream through AWK
# AWK immediately echos each line, and fires the video recorder exactly when the signal crosses the pipe.
set +e
script -q /dev/null "${TEST_CMD[@]}" | awk '{
    print $0;
    if ($0 ~ /Testing started/ && !triggered) {
        system("echo -e \"\\n[+] Test suite execution detected! Engaging camera lens...\" >&2");
        system("xcrun simctl io '"$UDID"' recordVideo '"$VIDEO_PATH"' > /dev/null 2>&1 & echo $! > \"/tmp/simctl_record_pid_'$$'.txt\"");
        triggered=1;
    }
}'
TEST_RESULT=${PIPESTATUS[0]}
set -e

if [[ -f "/tmp/simctl_record_pid_$$.txt" ]]; then
    RECORD_PID=$(cat "/tmp/simctl_record_pid_$$.txt")
    echo "4. Test finished (Exit $TEST_RESULT). Sending SIGINT to recording PID $RECORD_PID..."
    # Capture the final UI state or test outcomes for a few seconds after tests finish before stopping
    sleep 3
    kill -INT "$RECORD_PID" 2>/dev/null || true
    echo "Waiting for video file to finalize..."
    # Wait for it to be done - this is likely long enough. May need to tweak for later.
    sleep 5
    rm -f "/tmp/simctl_record_pid_$$.txt"
else
    # In case the test failed extremely fast before AWK could trigger
    echo "Warning: Test completed too fast; video lens never engaged."
fi

echo "5. Verifying video file size..."
if [[ -f "$VIDEO_PATH" ]]; then
    FILE_SIZE=$(stat -f%z "$VIDEO_PATH" 2>/dev/null || stat -c%s "$VIDEO_PATH" 2>/dev/null || echo "0")
    echo "Video file size: ${FILE_SIZE} bytes"

    if [[ "$FILE_SIZE" -gt 0 ]]; then
        echo "Success: Video generated properly at $VIDEO_PATH"
    else
        echo "Error: Video file is empty."
        exit 1
    fi
else
    echo "Error: Video file is missing."
    exit 1
fi

exit $TEST_RESULT
