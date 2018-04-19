#!/usr/bin/env bash

# Copyright 2018 Google
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

# USAGE: build.sh product [platform] [method]
#
# Builds the given product for the given platform using the given build method

set -euo pipefail

if [[ $# -lt 1 ]]; then
  cat 1>&2 <<EOF
USAGE: $0 product [platform] [method]

product can be one of:
  Firebase
  Firestore

platform can be one of:
  iOS (default)
  macOS
  tvOS

method can be one of:
  xcodebuild (default)
  cmake
EOF
  exit 1
fi

product="$1"

platform="iOS"
if [[ $# -gt 1 ]]; then
  platform="$2"
fi

method="xcodebuild"
if [[ $# -gt 2 ]]; then
  method="$3"
fi

echo "Building $product for $platform using $method"

# Runs xcodebuild with the given flags, piping output to xcpretty
# If xcodebuild fails with known error codes, retries once.
function RunXcodebuild() {
  xcodebuild "$@" | xcpretty; result=$?
  if [[ $result == 65 ]]; then
    echo "xcodebuild exited with 65, retrying" 1>&2
    sleep 5

    xcodebuild "$@" | xcpretty; result=$?
  fi
  if [[ $result != 0 ]]; then
    exit $result
  fi
}

# Compute standard flags for all platforms
case "$platform" in
  iOS)
    xcb_flags=(
      -sdk 'iphonesimulator'
      -destination 'platform=iOS Simulator,name=iPhone 7'
    )
    ;;

  macOS)
    xcb_flags=(
      -sdk 'macosx'
      -destination 'platform=OS X,arch=x86_64'
    )
    ;;

  tvOS)
    xcb_flags=(
      -sdk "appletvsimulator"
      -destination 'platform=tvOS Simulator,name=Apple TV'
    )
    ;;

  *)
    echo "Unknown platform '$platform'" 1>&2
    exit 1
    ;;
esac

xcb_flags+=(
  ONLY_ACTIVE_ARCH=YES
  CODE_SIGNING_REQUIRED=NO
)

case "$product-$method-$platform" in
  Firebase-xcodebuild-*)
    RunXcodebuild \
        -workspace 'Example/Firebase.xcworkspace' \
        -scheme "AllUnitTests_$platform" \
        "${xcb_flags[@]}" \
        build \
        test

    if [[ $platform == 'iOS' ]]; then
      RunXcodebuild \
          -workspace 'Functions/Example/FirebaseFunctions.xcworkspace' \
          -scheme "FirebaseFunctions_Tests" \
          "${xcb_flags[@]}" \
          build \
          test

      # Test iOS Objective-C static library build
      cd Example
      sed -i -e 's/use_frameworks/\#use_frameworks/' Podfile
      pod update --no-repo-update
      # Workarounds for https://github.com/CocoaPods/CocoaPods/issues/7592.
      # Remove when updating to CocoaPods 1.5.1
      sed -i -e 's/-l"FirebaseMessaging"//' "Pods/Target Support Files/Pods-Messaging_Tests_iOS/Pods-Messaging_Tests_iOS.debug.xcconfig"
      sed -i -e 's/-l"FirebaseAuth-iOS" -l"FirebaseCore-iOS"//' "Pods/Target Support Files/Pods-Auth_Tests_iOS/Pods-Auth_Tests_iOS.debug.xcconfig"
      cd ..
      RunXcodebuild \
          -workspace 'Example/Firebase.xcworkspace' \
          -scheme "AllUnitTests_$platform" \
          "${xcb_flags[@]}" \
          build \
          test

      cd Functions/Example
      sed -i -e 's/use_frameworks/\#use_frameworks/' Podfile
      pod update --no-repo-update
      cd ../..
      RunXcodebuild \
          -workspace 'Functions/Example/FirebaseFunctions.xcworkspace' \
          -scheme "FirebaseFunctions_Tests" \
          "${xcb_flags[@]}" \
          build \
          test
    fi
    ;;

  Firestore-xcodebuild-iOS)
    RunXcodebuild \
        -workspace 'Firestore/Example/Firestore.xcworkspace' \
        -scheme "Firestore_Tests_$platform" \
        "${xcb_flags[@]}" \
        build \
        test

    RunXcodebuild \
        -workspace 'Firestore/Example/Firestore.xcworkspace' \
        -scheme 'SwiftBuildTest' \
        "${xcb_flags[@]}" \
        build
    ;;

  Firestore-cmake-macOS)
    test -d build || mkdir build
    echo "Preparing cmake build ..."
    (cd build; cmake ..)

    echo "Building cmake build ..."
    cpus=$(sysctl -n hw.ncpu)
    (cd build; env CTEST_OUTPUT_ON_FAILURE=1 make -j $cpus all)
    ;;

  *)
    echo "Don't know how to build this product-platform-method combination" 1>&2
    echo "  product=$product" 1>&2
    echo "  platform=$platform" 1>&2
    echo "  method=$method" 1>&2
    exit 1
    ;;
esac
