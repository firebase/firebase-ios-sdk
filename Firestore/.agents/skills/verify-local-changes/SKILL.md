---
name: Verify Local Changes
description: Verifies local Firebase iOS SDK changes.
---

# Verify Local Changes (iOS/Apple)

This skill documents how to verify local code changes for the Firebase Apple SDKs.

## Prerequisites

- Xcode 26.2+
- CocoaPods 1.12.0+
- `cocoapods-generate` plugin

---

## Step 0: Format and Style

Run the style script before creating a PR:

```bash
./scripts/check.sh --allow-dirty
```

---

## Step 1: Build and Unit Test (CocoaPods)

For Firestore development:

```bash
cd Firestore/Example
pod update
open Firestore.xcworkspace
```

In Xcode:
1. Select the `Firestore_Tests_iOS` scheme.
2. Press `⌘U` to run unit tests.

---

## Step 2: Command-Line Build

```bash
PLATFORM=iOS pod update --project-directory=Firestore/Example
scripts/build.sh Firestore iOS
```

---

## Step 3: Integration Testing (Emulator)

1. Start the emulator in a separate terminal:
   ```bash
   scripts/run_firestore_emulator.sh
   ```
2. In Xcode, select `Firestore_IntegrationTests_iOS`.
3. Press `⌘U`.

---

> [!IMPORTANT]
> Running `scripts/build.sh` might modify Xcode project files. Revert these changes before creating a PR.
