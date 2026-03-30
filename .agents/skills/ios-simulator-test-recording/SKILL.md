---
name: ios-simulator-test-recording
description: >-
  Skill to run xcodebuild tests on iOS Simulator while recording a video walkthrough, dynamically selecting the
  highest available OS and device. Most useful for running XCUITests.
---

# iOS Simulator Test Recording Skill

This skill provides a generalized bash script to test run and record iOS Simulator workflows and UI tests. It handles
everything natively through AWK TTY streams to ensure the camera triggers exactly when the app launches — eliminating
the simulator's booting and install sequence.

## The Script: `run_test_and_record.sh`

The core logic of this skill resides in `./scripts/run_test_and_record.sh`. You can call this script whenever you
need to execute a test block accompanied by screen recording.

### Usage

```bash
./scripts/run_test_and_record.sh [OPTIONS] -- COMMAND
```

#### Options

- `--video PATH` : Change the video output file. Default: `simulator_walkthrough.mp4`
- `--show-ui` : Explicitly brings the Simulator.app window to the foreground so the user sees the execution happening.
  By default, it runs the simulator headless or in the background.
- `--udid UDID` : Specifies the ID of the simulator to attach to. If left omitted, it queries
  `xcrun simctl list devices available -j` and auto-bootstraps the highest tier iPhone class.

#### Substituting the Device ID

If your test script requires injecting the target UDID dynamically, you can use the `{UDID}` placeholder inside your
command execution block. The script will intercept and substitute it before launching.

### Example Implementations

**1. Basic Automated Fallback (Latest Simulator + Default Video)**
```bash
  ./scripts/run_test_and_record.sh \
  -- xcodebuild test -project SampleApp.xcodeproj -scheme SampleApp \
  -destination "platform=iOS Simulator,id={UDID}" -quiet
```
*Note the usage of `{UDID}` to let the script automatically populate the chosen device ID.*

**2. Custom Video Path & Show UI**
```bash
  ./scripts/run_test_and_record.sh \
  --show-ui \
  --video "~/Code/firebase-ios-sdk/auth_test.mp4" \
  -- xcodebuild test -workspace App.xcworkspace -scheme AppUITests \
  -destination "platform=iOS Simulator,id={UDID}" -only-testing:AppUITests/testLogin -quiet
```

**3. With a specific Custom UDID provided**
```bash
  ./scripts/run_test_and_record.sh \
  --udid "62425200-F824-4E55-ACB4-08D031165A82" \
  --video ./fast_test.mp4 \
  -- xcodebuild test -project Proj.xcodeproj ... -destination "platform=iOS Simulator,id={UDID}"
```

### Important Maintenance Notes
If future framework changes cause the script to fail, take these notes into consideration:
- **Avoid** using `tail -F` on XCTest logs inside CI arrays (it natively locks trailing descriptors indefinitely).
- **Avoid** using "magic numbers" and `sleep` commands to time the simulator launch. The script uses a robust
  TTY-based stream hook that triggers exactly when the test runner starts, ensuring perfect synchronization without
  timing dependencies.
- **Avoid** pipe `xcodebuild` into `tee` logs natively; block buffering will cache the entire script payload until
  test execution completion, causing the hook to deploy at the literal end of the tape, wiping your data. Always use
  the internal TTY `script` wrapper!
