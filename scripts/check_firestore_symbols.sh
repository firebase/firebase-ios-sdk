#!/bin/bash

# Copyright 2023 Google LLC
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

# DESCRIPTION: This script identifies Objective-C symbols within the
# `FirebaseFirestoreInternal.xcframework` that are not automatically linked
# when used in a client target. Because the
# `FirebaseFirestoreInternal.xcframework` should function without clients
# needing to pass the `-ObjC` flag, this script catches potential regressions
# that break that requirement.
#
# DEPENDENCIES: This script depends on the given Firebase repo's `Package.swift`
# using the `FIREBASECI_USE_LOCAL_FIRESTORE_ZIP` env var to swap the Firestore
# target definition out to instead reference a *local* binary using the
# `.binaryTarget(path:)` API.
#
# DESIGN: This script creates an executable package that depends on Firestore
# via a local binary SPM target. The package is built twice, once with the
# -ObjC flag and once without. The linked Objective-C symbols are then
# stripped from each build's resulting executable. The symbols are then diffed
# to determine if there exists symbols that were only linked due to the -ObjC
# flag.
#
# USAGE: ./check_firestore_symbols.sh <PATH_TO_FIREBASE_REPO> <PATH_TO_FIRESTORE_XCFRAMEWORK>

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: ./check_firestore_symbols.sh <PATH_TO_FIREBASE_REPO> <PATH_TO_FIRESTORE_XCFRAMEWORK>"
    exit 1
fi

# Check if the given repo path is valid.
FIREBASE_REPO_PATH=$1

if [[ "$FIREBASE_REPO_PATH" != /* ]]; then
   echo "The given path should be an absolute path."
   exit 1
fi

if [[ ! -d "$FIREBASE_REPO_PATH" ]]; then
    echo "The given repo does not exist: $FIREBASE_REPO_PATH"
    exit 1
fi

# Check if the given xcframework path is valid.
FIRESTORE_XCFRAMEWORK_PATH=$2

if [ "$(basename $FIRESTORE_XCFRAMEWORK_PATH)" != 'FirebaseFirestoreInternal.xcframework' ]; then
  echo "The given xcframework is not a FirebaseFirestoreInternal.xcframework."
  exit 1
fi

if [[ ! -d "$FIRESTORE_XCFRAMEWORK_PATH" ]]; then
    echo "The given xcframework does not exist: $FIRESTORE_XCFRAMEWORK_PATH"
    exit 1
fi

# Copy the given Firestore framework to the root of the given Firebase repo.
# This script uses an env var that will alter the repo's `Package.swift` to
# pick up the copied Firestore framework. See
# `FIREBASECI_USE_LOCAL_FIRESTORE_ZIP` in Firebase's `Package.swift` for more.
cp -r "$FIRESTORE_XCFRAMEWORK_PATH" "$FIREBASE_REPO_PATH"

# Create a temporary directory for the test package. The test package defines an
# executable and has the following directory structure:
#
#       TestPkg
#       ├── Package.swift
#       └── Sources
#           └── TestPkg
#               └── main.swift
TEST_PKG_ROOT=$(mktemp -d -t TestPkg)
echo "Test package root: $TEST_PKG_ROOT"

# Create the package's subdirectories.
mkdir -p "$TEST_PKG_ROOT/Sources/TestPkg"

# Generate the package's `Package.swift`.
cat > "$TEST_PKG_ROOT/Package.swift" <<- EOM
// swift-tools-version: 5.6
import PackageDescription

let package = Package(
    name: "TestPkg",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(path: "${FIREBASE_REPO_PATH}")
    ],
    targets: [
    .executableTarget(
        name: "TestPkg",
        dependencies: [
            .product(
                name: "FirebaseFirestore",
                package: "firebase-ios-sdk"
            )
        ]
    )
    ]
)
EOM

# Generate the package's `main.swift`.
cat > "$TEST_PKG_ROOT/Sources/TestPkg/main.swift" <<- EOM
import FirebaseFirestore

let db = Firestore.firestore()
EOM

# Change to the test package's root directory in order to build the package.
cd "$TEST_PKG_ROOT"

# Build the test package *without* the `-ObjC` linker flag, and dump the
# resulting executable file's Objective-C symbols into a text file.
echo "Building test package without -ObjC linker flag..."
FIREBASECI_USE_LOCAL_FIRESTORE_ZIP=1 xcodebuild -scheme 'TestPkg' \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/TestPkg" \
    | xcpretty

nm ~/Library/Developer/Xcode/DerivedData/TestPkg/Build/Products/Debug/TestPkg \
      | grep -o "[-+]\[.*\]" > objc_symbols_without_linker_flag.txt

# Build the test package *with* the -ObjC linker flag, and dump the
# resulting executable file's Objective-C symbols into a text file.
echo "Building test package with -ObjC linker flag..."
FIREBASECI_USE_LOCAL_FIRESTORE_ZIP=1 xcodebuild -scheme 'TestPkg' \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/TestPkg-ObjC" \
    OTHER_LDFLAGS='-ObjC' \
    | xcpretty

nm ~/Library/Developer/Xcode/DerivedData/TestPkg-ObjC/Build/Products/Debug/TestPkg \
      | grep -o "[-+]\[.*\]" > objc_symbols_with_linker_flag.txt

# Compare the two text files to see if the -ObjC linker flag caused additional
# symbols to link.
#
# Note: In the case where the diff is non-empty, the diff command will
# return exit code 1, which will cause the set pipefail to terminate execution.
# To avoid this, `|| true` ensures the exit code always indicates success.
DIFF=$(
    git diff --no-index --output-indicator-new="?" \
        objc_symbols_without_linker_flag.txt \
        objc_symbols_with_linker_flag.txt \
        || true
)
if [[ -n "$DIFF" ]]; then
    echo "Failure: Unlinked Objective-C symbols have been detected:"
    echo "$DIFF"
    echo -n "💡 To fix, follow the process shown in "
    echo -n "https://github.com/firebase/firebase-ios-sdk/pull/12534 for the "
    echo "above symbols that are prefixed with ?"
    exit 1
else
    echo "Success: No unlinked Objective-C symbols have been detected."
    exit 0
fi
