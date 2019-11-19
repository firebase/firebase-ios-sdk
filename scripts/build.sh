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

function pod_gen() {
  # Call pod gen with a podspec and additional optional arguments.
  bundle exec pod gen --local-sources=./ --sources=https://cdn.cocoapods.org/ "$@"
}

set -euo pipefail

if [[ $# -lt 1 ]]; then
  cat 1>&2 <<EOF
USAGE: $0 product [platform] [method]

product can be one of:
  Firebase
  Firestore
  InAppMessaging
  InAppMessagingDisplay
  SymbolCollision

platform can be one of:
  iOS (default)
  macOS
  tvOS

method can be one of:
  xcodebuild (default)
  cmake

Optionally, reads the environment variable SANITIZERS. If set, it is expected to
be a string containing a space-separated list with some of the following
elements:
  asan
  tsan
  ubsan
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
if [[ -n "${SANITIZERS:-}" ]]; then
  echo "Using sanitizers: $SANITIZERS"
fi

scripts_dir=$(dirname "${BASH_SOURCE[0]}")
firestore_emulator="${scripts_dir}/run_firestore_emulator.sh"

xcode_version=$(xcodebuild -version | head -n 1)
xcode_version="${xcode_version/Xcode /}"
xcode_major="${xcode_version/.*/}"

# Runs xcodebuild with the given flags, piping output to xcpretty
# If xcodebuild fails with known error codes, retries once.
function RunXcodebuild() {
  echo xcodebuild "$@"

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

if [[ "$xcode_major" -lt 11 ]]; then
  ios_flags=(
    -sdk 'iphonesimulator'
    -destination 'platform=iOS Simulator,name=iPhone 7'
  )
else
  ios_flags=(
    -sdk 'iphonesimulator'
    -destination 'platform=iOS Simulator,name=iPhone 11'
  )
fi

ipad_flags=(
  -sdk 'iphonesimulator'
  -destination 'platform=iOS Simulator,name=iPad Pro (9.7-inch)'
)

macos_flags=(
  -sdk 'macosx'
  -destination 'platform=OS X,arch=x86_64'
)
tvos_flags=(
  -sdk "appletvsimulator"
  -destination 'platform=tvOS Simulator,name=Apple TV'
)

# Compute standard flags for all platforms
case "$platform" in
  iOS)
    xcb_flags=("${ios_flags[@]}")
    ;;

  iPad)
    xcb_flags=("${ipad_flags[@]}")
  ;;

  macOS)
    xcb_flags=("${macos_flags[@]}")
    ;;

  tvOS)
    xcb_flags=("${tvos_flags[@]}")
    ;;

  all)
    xcb_flags=()
    ;;

  *)
    echo "Unknown platform '$platform'" 1>&2
    exit 1
    ;;
esac

xcb_flags+=(
  ONLY_ACTIVE_ARCH=YES
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGNING_ALLOWED=YES
  COMPILER_INDEX_STORE_ENABLE=NO
)

# TODO(varconst): Add --warn-unused-vars and --warn-uninitialized.
# Right now, it makes the log overflow on Travis because many of our
# dependencies don't build cleanly this way.
cmake_options=(
  -Wdeprecated
)

if [[ -n "${SANITIZERS:-}" ]]; then
  for sanitizer in $SANITIZERS; do
    case "$sanitizer" in
      asan)
        xcb_flags+=(
          -enableAddressSanitizer YES
        )
        cmake_options+=(
          -DWITH_ASAN=ON
        )
        ;;

      tsan)
        xcb_flags+=(
          -enableThreadSanitizer YES
        )
        cmake_options+=(
          -DWITH_TSAN=ON
        )
        ;;

      ubsan)
        xcb_flags+=(
          -enableUndefinedBehaviorSanitizer YES
        )
        cmake_options+=(
          -DWITH_UBSAN=ON
        )
        ;;

      *)
        echo "Unknown sanitizer '$sanitizer'" 1>&2
        exit 1
        ;;
    esac
  done
fi

case "$product-$method-$platform" in
  Firebase-xcodebuild-*)
    # Coverage collection often cause retries to fail because of partial
    # pre-existing data.
    # TODO(paulb777): Find a less blunt solution to this.
    rm -rf ~/Library/Developer/Xcode/DerivedData

    RunXcodebuild \
        -workspace 'Example/Firebase.xcworkspace' \
        -scheme "AllUnitTests_$platform" \
        "${xcb_flags[@]}" \
        build \
        test

    if [[ $platform == 'iOS' ]]; then
      # Code Coverage collection is only working on iOS currently.
      ./scripts/collect_metrics.sh 'Example/Firebase.xcworkspace' "AllUnitTests_$platform"
    fi
    ;;

  FirebasePod-xcodebuild-*)
    RunXcodebuild \
        -workspace 'CoreOnly/Tests/FirebasePodTest/FirebasePodTest.xcworkspace' \
        -scheme "FirebasePodTest" \
        "${xcb_flags[@]}" \
        build
    ;;

  Auth-xcodebuild-*)
    if [[ "$TRAVIS_PULL_REQUEST" == "false" ||
          "$TRAVIS_PULL_REQUEST_SLUG" == "$TRAVIS_REPO_SLUG" ]]; then
      RunXcodebuild \
        -workspace 'Example/Auth/AuthSample/AuthSample.xcworkspace' \
        -scheme "Auth_ApiTests" \
        "${xcb_flags[@]}" \
        build \
        test
    fi
    ;;

  InAppMessaging-xcodebuild-iOS)
    RunXcodebuild \
        -workspace 'InAppMessaging/Example/InAppMessaging-Example-iOS.xcworkspace' \
        -scheme 'InAppMessaging_Example_iOS' \
        "${xcb_flags[@]}" \
        build \
        test
  ;;

  InAppMessagingDisplay-xcodebuild-*)
    RunXcodebuild \
        -workspace 'InAppMessagingDisplay/Example/InAppMessagingDisplay-Sample.xcworkspace' \
        -scheme 'FiamDisplaySwiftExample' \
        "${xcb_flags[@]}" \
        build \
        test
    ;;

  Firestore-xcodebuild-*)
    "${firestore_emulator}" start
    trap '"${firestore_emulator}" stop' ERR EXIT

    if [[ "$xcode_major" -lt 9 ]]; then
      # When building and testing for Xcode 8, only test unit tests.
      RunXcodebuild \
          -workspace 'Firestore/Example/Firestore.xcworkspace' \
          -scheme "Firestore_Tests_$platform" \
          "${xcb_flags[@]}" \
          build \
          test

    else
      # IntegrationTests run all the tests, including Swift tests, which
      # require Swift 4.0 and Xcode 9+.
      RunXcodebuild \
          -workspace 'Firestore/Example/Firestore.xcworkspace' \
          -scheme "Firestore_IntegrationTests_$platform" \
          "${xcb_flags[@]}" \
          build \
          test
    fi
    ;;

  Firestore-cmake-macOS)
    "${firestore_emulator}" start
    trap '"${firestore_emulator}" stop' ERR EXIT

    test -d build || mkdir build
    echo "Preparing cmake build ..."
    (cd build; cmake "${cmake_options[@]}" ..)

    echo "Building cmake build ..."
    cpus=$(sysctl -n hw.ncpu)
    (cd build; env make -j $cpus all generate_protos)
    (cd build; env CTEST_OUTPUT_ON_FAILURE=1 make -j $cpus test)
    ;;

  SymbolCollision-xcodebuild-*)
    RunXcodebuild \
        -workspace 'SymbolCollisionTest/SymbolCollisionTest.xcworkspace' \
        -scheme "SymbolCollisionTest" \
        "${xcb_flags[@]}" \
        build
    ;;

  Database-xcodebuild-*)
    pod_gen FirebaseDatabase.podspec --platforms=ios
    RunXcodebuild \
      -workspace 'gen/FirebaseDatabase/FirebaseDatabase.xcworkspace' \
      -scheme "FirebaseDatabase-Unit-unit" \
      "${ios_flags[@]}" \
      "${xcb_flags[@]}" \
      build \
      test

    if [[ "$TRAVIS_PULL_REQUEST" == "false" ||
          "$TRAVIS_PULL_REQUEST_SLUG" == "$TRAVIS_REPO_SLUG" ]]; then
      # Integration tests are only run on iOS to minimize flake failures.
      RunXcodebuild \
        -workspace 'gen/FirebaseDatabase/FirebaseDatabase.xcworkspace' \
        -scheme "FirebaseDatabase-Unit-integration" \
        "${ios_flags[@]}" \
        "${xcb_flags[@]}" \
        build \
        test
      fi

    pod_gen FirebaseDatabase.podspec --platforms=macos --clean
    RunXcodebuild \
      -workspace 'gen/FirebaseDatabase/FirebaseDatabase.xcworkspace' \
      -scheme "FirebaseDatabase-Unit-unit" \
      "${macos_flags[@]}" \
      "${xcb_flags[@]}" \
      build \
      test

    pod_gen FirebaseDatabase.podspec --platforms=tvos --clean
    RunXcodebuild \
      -workspace 'gen/FirebaseDatabase/FirebaseDatabase.xcworkspace' \
      -scheme "FirebaseDatabase-Unit-unit" \
      "${tvos_flags[@]}" \
      "${xcb_flags[@]}" \
      build \
      test
    ;;

  Storage-xcodebuild-*)
    pod_gen FirebaseStorage.podspec --platforms=ios
    RunXcodebuild \
      -workspace 'gen/FirebaseStorage/FirebaseStorage.xcworkspace' \
      -scheme "FirebaseStorage-Unit-unit" \
      "${ios_flags[@]}" \
      "${xcb_flags[@]}" \
      build \
      test

    if [[ "$TRAVIS_PULL_REQUEST" == "false" ||
          "$TRAVIS_PULL_REQUEST_SLUG" == "$TRAVIS_REPO_SLUG" ]]; then
      # Integration tests are only run on iOS to minimize flake failures.
      RunXcodebuild \
        -workspace 'gen/FirebaseStorage/FirebaseStorage.xcworkspace' \
        -scheme "FirebaseStorage-Unit-integration" \
        "${ios_flags[@]}" \
        "${xcb_flags[@]}" \
        build \
        test
      fi

    pod_gen FirebaseStorage.podspec --platforms=macos --clean
    RunXcodebuild \
      -workspace 'gen/FirebaseStorage/FirebaseStorage.xcworkspace' \
      -scheme "FirebaseStorage-Unit-unit" \
      "${macos_flags[@]}" \
      "${xcb_flags[@]}" \
      build \
      test

    pod_gen FirebaseStorage.podspec --platforms=tvos --clean
    RunXcodebuild \
      -workspace 'gen/FirebaseStorage/FirebaseStorage.xcworkspace' \
      -scheme "FirebaseStorage-Unit-unit" \
      "${tvos_flags[@]}" \
      "${xcb_flags[@]}" \
      build \
      test
    ;;
  *)
    echo "Don't know how to build this product-platform-method combination" 1>&2
    echo "  product=$product" 1>&2
    echo "  platform=$platform" 1>&2
    echo "  method=$method" 1>&2
    exit 1
    ;;
esac
