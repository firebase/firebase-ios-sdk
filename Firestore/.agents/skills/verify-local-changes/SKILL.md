---
name: Verify Local Changes
description: Verifies local Firebase iOS SDK changes.
---

# Verify Local Changes (iOS/Apple)

This skill documents how to verify local code changes for the Firebase Apple SDKs using command-line tools.

## Prerequisites

- Xcode 16.2+
- CocoaPods 1.12.0+
- `cocoapods-generate` plugin

---

## Step 0: Format and Style

Run the style script before creating a PR:

```bash
./scripts/check.sh --allow-dirty
```

---

## Step 1: Boot the iOS Simulator

Ensure that an iOS Simulator is booted and ready to run tests.

```bash
# List available simulators and find their status
xcrun simctl list devices | grep "iPhone 16"

# Boot the simulator (e.g., "iPhone 16" for Xcode 16)
xcrun simctl boot "iPhone 16"
```

---

## Step 2: Install Dependencies (CocoaPods)

Generate the CocoaPods workspace targeting the iOS platform:

```bash
PLATFORM=iOS pod update --project-directory=Firestore/Example
```

---

## Step 3: Build and Run Unit Tests

Use `xcodebuild` to build and run the unit tests.

### Build Unit Tests:
```bash
xcodebuild \
  -workspace Firestore/Example/Firestore.xcworkspace \
  -scheme Firestore_Tests_iOS \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -jobs 4 \
  build-for-testing
```

### Run Unit Tests:
```bash
xcodebuild \
  -workspace Firestore/Example/Firestore.xcworkspace \
  -scheme Firestore_Tests_iOS \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  test-without-building
```

---

## Step 4: Build and Run Integration Tests (Emulator)

The integration tests run against the Cloud Firestore emulator. The build/test scripts automatically manage the emulator lifecycle.

### Build Integration Tests:
```bash
scripts/build.sh Firestore iOS xcodebuild
```

### Run Integration Tests:
```bash
scripts/build.sh Firestore iOS xcodetest
```

---

> [!IMPORTANT]
> Running `scripts/build.sh` might modify Xcode project files. Revert these changes before creating a PR.
