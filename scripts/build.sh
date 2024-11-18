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
  bundle exec pod gen --local-sources=./ --sources=https://github.com/firebase/SpecsDev.git,https://github.com/firebase/SpecsStaging.git,https://cdn.cocoapods.org/ "$@"
}

set -euo pipefail

if [[ $# -lt 1 ]]; then
  cat 1>&2 <<EOF
USAGE: $0 product [platform] [method]
product can be one of:
  Firebase
  Firestore
  CombineSwift
  InAppMessaging
  Messaging
  MessagingSample
  SwiftUISample
  MLModelDownloaderSample
  RemoteConfig
  RemoteConfigSample
  Sessions
  Storage
  SymbolCollision
  GoogleDataTransport
  Performance
  ClientApp
platform can be one of:
  iOS (default)
  iOS-device
  macOS
  tvOS
  watchOS
  catalyst
  visionOS
method can be one of:
  xcodebuild (default)
  cmake
  unit
  integration
  spm
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
database_emulator="${scripts_dir}/run_database_emulator.sh"

system=$(uname -s)
case "$system" in
  Darwin)
    xcode_version=$(xcodebuild -version | grep Xcode)
    xcode_version="${xcode_version/Xcode /}"
    xcode_major="${xcode_version/.*/}"
    ;;
  *)
    xcode_major="0"
    ;;
esac

# Source function to check if CI secrets are available.
source scripts/check_secrets.sh

# Runs xcodebuild with the given flags, piping output to xcbeautify
# If xcodebuild fails with known error codes, retries once.
function RunXcodebuild() {
  echo xcodebuild "$@"

  xcbeautify_cmd=(xcbeautify --renderer github-actions)

  result=0
  xcodebuild "$@" | tee xcodebuild.log | "${xcbeautify_cmd[@]}" || result=$?

  if [[ $result == 65 ]]; then
    ExportLogs "$@"

    echo "xcodebuild exited with 65, retrying" 1>&2
    sleep 5

    result=0
    xcodebuild "$@" | tee xcodebuild.log | "${xcbeautify_cmd[@]}" || result=$?
  fi

  if [[ $result != 0 ]]; then
    echo "xcodebuild exited with $result" 1>&2

    ExportLogs "$@"
    return $result
  fi
}

# Exports any logs output captured in the xcresult
function ExportLogs() {
  python "${scripts_dir}/xcresult_logs.py" "$@"
}

if [[ "$xcode_major" -lt 15 ]]; then
  ios_flags=(
    -sdk 'iphonesimulator'
    -destination 'platform=iOS Simulator,name=iPhone 14'
  )
  watchos_flags=(
    -sdk 'watchsimulator'
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 7 (45mm)'
  )
elif [[ "$xcode_major" -lt 16 ]]; then
  ios_flags=(
    -sdk 'iphonesimulator'
    -destination 'platform=iOS Simulator,name=iPhone 15'
  )
  watchos_flags=(
    -sdk 'watchsimulator'
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 7 (45mm)'
  )
else
  ios_flags=(
    -sdk 'iphonesimulator'
    -destination 'platform=iOS Simulator,name=iPhone 16'
  )
    watchos_flags=(
    -sdk 'watchsimulator'
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (42mm)'
  )
fi

ios_device_flags=(
  -sdk 'iphoneos'
  -destination 'generic/platform=iOS'
)

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
visionos_flags=(
  -sdk 'xrsimulator'
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro'
)
catalyst_flags=(
  ARCHS=x86_64 VALID_ARCHS=x86_64 SUPPORTS_MACCATALYST=YES -sdk macosx
  -destination platform="macOS,variant=Mac Catalyst,arch=x86_64" TARGETED_DEVICE_FAMILY=2
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
)

# Compute standard flags for all platforms
case "$platform" in
  iOS)
    xcb_flags=("${ios_flags[@]}")
    gen_platform=ios
    ;;

  iOS-device)
    xcb_flags=("${ios_device_flags[@]}")
    gen_platform=ios
    ;;

  iPad)
    xcb_flags=("${ipad_flags[@]}")
  ;;

  macOS)
    xcb_flags=("${macos_flags[@]}")
    gen_platform=macos
    ;;

  tvOS)
    xcb_flags=("${tvos_flags[@]}")
    gen_platform=tvos
    ;;

  watchOS)
    xcb_flags=("${watchos_flags[@]}")
    ;;

  visionOS)
    xcb_flags=("${visionos_flags[@]}")
    ;;

  catalyst)
    xcb_flags=("${catalyst_flags[@]}")
    ;;

  all)
    xcb_flags=()
    ;;

  Linux)
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

source scripts/buildcache.sh
xcb_flags=("${xcb_flags[@]}" "${buildcache_xcb_flags[@]}")

# TODO(varconst): Add --warn-unused-vars and --warn-uninitialized.
# Right now, it makes the log overflow on Travis because many of our
# dependencies don't build cleanly this way.
cmake_options=(
  -Wdeprecated
  -DCMAKE_BUILD_TYPE=Debug
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


case "$product-$platform-$method" in
  FirebasePod-iOS-*)
    RunXcodebuild \
        -workspace 'CoreOnly/Tests/FirebasePodTest/FirebasePodTest.xcworkspace' \
        -scheme "FirebasePodTest" \
        "${xcb_flags[@]}" \
        build
    ;;

  Auth-*-*)
    if check_secrets; then
      RunXcodebuild \
        -project 'FirebaseAuth/Tests/SampleSwift/AuthenticationExample.xcodeproj' \
        -scheme "$method" \
        "${xcb_flags[@]}" \
        test
    fi
    ;;

  CombineSwift-*-xcodebuild)
    pod_gen FirebaseCombineSwift.podspec --platforms=ios
    RunXcodebuild \
      -workspace 'gen/FirebaseCombineSwift/FirebaseCombineSwift.xcworkspace' \
      -scheme "FirebaseCombineSwift-Unit-unit" \
      "${xcb_flags[@]}" \
      build \
      test
    ;;

  InAppMessaging-*-xcodebuild)
    RunXcodebuild \
        -workspace 'FirebaseInAppMessaging/Tests/Integration/DefaultUITestApp/InAppMessagingDisplay-Sample.xcworkspace' \
        -scheme 'FiamDisplaySwiftExample' \
        "${xcb_flags[@]}" \
        test
    ;;

  Firestore-*-xcodebuild)
    "${firestore_emulator}" start
    trap '"${firestore_emulator}" stop' ERR EXIT

    RunXcodebuild \
        -workspace 'Firestore/Example/Firestore.xcworkspace' \
        -scheme "Firestore_IntegrationTests_$platform" \
        -enableCodeCoverage YES \
        "${xcb_flags[@]}" \
        test
    ;;

  Firestore-macOS-cmake | Firestore-Linux-cmake)
    "${firestore_emulator}" start
    trap '"${firestore_emulator}" stop' ERR EXIT

    (
      test -d build || mkdir build
      cd build

      echo "Preparing cmake build ..."
      cmake -G Ninja "${cmake_options[@]}" ..

      echo "Building cmake build ..."
      ninja -k 10 all
      ctest --verbose
    )
    ;;

  SymbolCollision-*-*)
    RunXcodebuild \
        -workspace 'SymbolCollisionTest/SymbolCollisionTest.xcworkspace' \
        -scheme "SymbolCollisionTest" \
        "${xcb_flags[@]}" \
        build
    ;;

  # TODO(#12205) Restore this test to "test" instead of "build"
  Messaging-*-xcodebuild)
    pod_gen FirebaseMessaging.podspec --platforms=ios

    # Add GoogleService-Info.plist to generated Test Wrapper App.
    ruby ./scripts/update_xcode_target.rb gen/FirebaseMessaging/Pods/Pods.xcodeproj \
      AppHost-FirebaseMessaging-Unit-Tests \
      ../../../FirebaseMessaging/Tests/IntegrationTests/Resources/GoogleService-Info.plist

    if check_secrets; then
      # Integration tests are only run on iOS to minimize flake failures.
      RunXcodebuild \
        -workspace 'gen/FirebaseMessaging/FirebaseMessaging.xcworkspace' \
        -scheme "FirebaseMessaging-Unit-integration" \
        "${ios_flags[@]}" \
        "${xcb_flags[@]}" \
        build
    fi
    ;;

  MessagingSample-*-*)
    if check_secrets; then
      RunXcodebuild \
        -workspace 'FirebaseMessaging/Apps/Sample/Sample.xcworkspace' \
        -scheme "Sample" \
        "${xcb_flags[@]}" \
        build
    fi
    ;;

  SwiftUISample-*-*)
    if check_secrets; then
      RunXcodebuild \
        -workspace 'FirebaseMessaging/Apps/SwiftUISample/SwiftUISample.xcworkspace' \
        -scheme "SwiftUISample" \
        "${xcb_flags[@]}" \
        build
    fi
    ;;

  # TODO: This is actually building for iOS instead of watchOS. Update to use
  # watchOS xcb_flags along with the watchOS sdk option. Also nanopb and promises
  # podspecs need minimum version updates.

  MessagingSampleStandaloneWatchApp-*-*)
    if check_secrets; then
      RunXcodebuild \
        -workspace 'FirebaseMessaging/Apps/SampleStandaloneWatchApp/SampleStandaloneWatchApp.xcworkspace' \
        -scheme "SampleStandaloneWatchApp Watch App" \
        -destination 'platform=watchOS Simulator,name=Apple Watch Series 7 (45mm)' \
        build
    fi
    ;;

  MLModelDownloaderSample-*-*)
  if check_secrets; then
    RunXcodebuild \
      -workspace 'FirebaseMLModelDownloader/Apps/Sample/MLDownloaderTestApp.xcworkspace' \
      -scheme "MLDownloaderTestApp" \
      "${xcb_flags[@]}" \
      build
  fi
  ;;

  WatchOSSample-*-*)
    RunXcodebuild \
      -workspace 'Example/watchOSSample/SampleWatchApp.xcworkspace' \
      -scheme "SampleWatchAppWatchKitApp" \
      "${xcb_flags[@]}" \
      build
    ;;

  Database-*-integration)
    "${database_emulator}" start
    trap '"${database_emulator}" stop' ERR EXIT
    pod_gen FirebaseDatabase.podspec --platforms="${gen_platform}"

    RunXcodebuild \
      -workspace 'gen/FirebaseDatabase/FirebaseDatabase.xcworkspace' \
      -scheme "FirebaseDatabase-Unit-integration" \
      "${xcb_flags[@]}" \
      build \
      test
    ;;

  RemoteConfig-*-fakeconsole)
    pod_gen FirebaseRemoteConfig.podspec --platforms="${gen_platform}"

    RunXcodebuild \
      -workspace 'gen/FirebaseRemoteConfig/FirebaseRemoteConfig.xcworkspace' \
      -scheme "FirebaseRemoteConfig-Unit-fake-console-tests" \
      "${xcb_flags[@]}" \
      build \
      test
    ;;

  RemoteConfig-*-integration)
    pod_gen FirebaseRemoteConfig.podspec --platforms="${gen_platform}"

    # Add GoogleService-Info.plist to generated Test Wrapper App.
    ruby ./scripts/update_xcode_target.rb gen/FirebaseRemoteConfig/Pods/Pods.xcodeproj \
      AppHost-FirebaseRemoteConfig-Unit-Tests \
      ../../../FirebaseRemoteConfig/Tests/Swift/SwiftAPI/GoogleService-Info.plist

    # Add AccessToken to generated Test Wrapper App.
    ruby ./scripts/update_xcode_target.rb gen/FirebaseRemoteConfig/Pods/Pods.xcodeproj \
      AppHost-FirebaseRemoteConfig-Unit-Tests \
      ../../../FirebaseRemoteConfig/Tests/Swift/AccessToken.json

    RunXcodebuild \
      -workspace 'gen/FirebaseRemoteConfig/FirebaseRemoteConfig.xcworkspace' \
      -scheme "FirebaseRemoteConfig-Unit-swift-api-tests" \
      "${xcb_flags[@]}" \
      build \
      test
    ;;

  RemoteConfigSample-*-*)
    RunXcodebuild \
      -workspace 'FirebaseRemoteConfig/Tests/Sample/RemoteConfigSampleApp.xcworkspace' \
      -scheme "RemoteConfigSampleApp" \
      "${xcb_flags[@]}" \
      build
    ;;

  VertexIntegration-*-*)
    RunXcodebuild \
      -project 'FirebaseVertexAI/Tests/TestApp/VertexAITestApp.xcodeproj' \
      -scheme "VertexAITestApp-SPM" \
      "${xcb_flags[@]}" \
      -parallel-testing-enabled NO \
      build \
      test
    ;;

  VertexSample-*-*)
    RunXcodebuild \
      -project 'FirebaseVertexAI/Sample/VertexAISample.xcodeproj' \
      -scheme "VertexAISample" \
      "${xcb_flags[@]}" \
      build
    ;;

  Sessions-*-integration)
    # Perform "pod install" to install the relevant dependencies
    # ./FirebaseSessions/generate_testapp.sh
    pod_gen FirebaseSessions.podspec --platforms=ios --clean
    cd FirebaseSessions/Tests/TestApp; pod install; cd -

    # Run E2E Integration Tests for Prod.
    RunXcodebuild \
      -workspace 'FirebaseSessions/Tests/TestApp/AppQualityDevApp.xcworkspace' \
      -scheme "AppQualityDevApp_iOS" \
      "${ios_flags[@]}" \
      "${xcb_flags[@]}" \
      build \
      test

    # Run E2E Integration Tests for Staging.
    RunXcodebuild \
      -workspace 'FirebaseSessions/Tests/TestApp/AppQualityDevApp.xcworkspace' \
      -scheme "AppQualityDevApp_iOS" \
      FirebaseSessionsRunEnvironment=STAGING \
      "${ios_flags[@]}" \
      "${xcb_flags[@]}" \
      build \
      test

    # Run E2E Integration Tests for Autopush.
    RunXcodebuild \
      -workspace 'FirebaseSessions/Tests/TestApp/AppQualityDevApp.xcworkspace' \
      -scheme "AppQualityDevApp_iOS" \
      FirebaseSessionsRunEnvironment=AUTOPUSH \
      "${ios_flags[@]}" \
      "${xcb_flags[@]}" \
      build \
      test
    ;;

  StorageSwift-*-xcodebuild)
    pod_gen FirebaseStorage.podspec --platforms=ios

    # Add GoogleService-Info.plist to generated Test Wrapper App.
    ruby ./scripts/update_xcode_target.rb gen/FirebaseStorage/Pods/Pods.xcodeproj \
      AppHost-FirebaseStorage-Unit-Tests \
      ../../../FirebaseStorage/Tests/Integration/Resources/GoogleService-Info.plist

    if check_secrets; then
      # Integration tests are only run on iOS to minimize flake failures.
      RunXcodebuild \
        -workspace 'gen/FirebaseStorage/FirebaseStorage.xcworkspace' \
        -scheme "FirebaseStorage-Unit-integration" \
        "${ios_flags[@]}" \
        "${xcb_flags[@]}" \
        test
    fi
    ;;

  StorageObjC-*-xcodebuild)
    pod_gen FirebaseStorage.podspec --platforms=ios

    # Add GoogleService-Info.plist to generated Test Wrapper App.
    ruby ./scripts/update_xcode_target.rb gen/FirebaseStorage/Pods/Pods.xcodeproj \
      AppHost-FirebaseStorage-Unit-Tests \
      ../../../FirebaseStorage/Tests/Integration/Resources/GoogleService-Info.plist

    if check_secrets; then
      # Integration tests are only run on iOS to minimize flake failures.
      RunXcodebuild \
        -workspace 'gen/FirebaseStorage/FirebaseStorage.xcworkspace' \
        -scheme "FirebaseStorage-Unit-ObjCIntegration" \
        "${ios_flags[@]}" \
        "${xcb_flags[@]}" \
        test
      fi
    ;;

  StorageCombine-*-xcodebuild)
    pod_gen FirebaseCombineSwift.podspec --platforms=ios

    # Add GoogleService-Info.plist to generated Test Wrapper App.
    ruby ./scripts/update_xcode_target.rb gen/FirebaseCombineSwift/Pods/Pods.xcodeproj \
      AppHost-FirebaseCombineSwift-Unit-Tests \
      ../../../FirebaseStorage/Tests/Integration/Resources/GoogleService-Info.plist

    if check_secrets; then
      # Integration tests are only run on iOS to minimize flake failures.
      RunXcodebuild \
        -workspace 'gen/FirebaseCombineSwift/FirebaseCombineSwift.xcworkspace' \
        -scheme "FirebaseCombineSwift-Unit-integration" \
        "${ios_flags[@]}" \
        "${xcb_flags[@]}" \
        test
      fi
    ;;

  GoogleDataTransport-watchOS-xcodebuild)
    RunXcodebuild \
      -workspace 'GoogleDataTransport/GDTWatchOSTestApp/GDTWatchOSTestApp.xcworkspace' \
      -scheme "GDTWatchOSTestAppWatchKitApp" \
      "${xcb_flags[@]}" \
      build

    RunXcodebuild \
      -workspace 'GoogleDataTransport/GDTCCTWatchOSTestApp/GDTCCTWatchOSTestApp.xcworkspace' \
      -scheme "GDTCCTWatchOSIndependentTestAppWatchKitApp" \
      "${xcb_flags[@]}" \
      build

    RunXcodebuild \
      -workspace 'GoogleDataTransport/GDTCCTWatchOSTestApp/GDTCCTWatchOSTestApp.xcworkspace' \
      -scheme "GDTCCTWatchOSCompanionTestApp" \
      "${xcb_flags[@]}" \
      build
    ;;

  Performance-*-unit)
    # Run unit tests on prod environment with unswizzle capabilities.
    export FPR_UNSWIZZLE_AVAILABLE="1"
    export FPR_AUTOPUSH_ENV="0"
    pod_gen FirebasePerformance.podspec --platforms="${gen_platform}"
    RunXcodebuild \
      -workspace 'gen/FirebasePerformance/FirebasePerformance.xcworkspace' \
      -scheme "FirebasePerformance-Unit-unit" \
      "${xcb_flags[@]}" \
      build \
      test
    ;;

  Performance-*-proddev)
    # Build the prod dev test app.
    export FPR_UNSWIZZLE_AVAILABLE="0"
    export FPR_AUTOPUSH_ENV="0"
    pod_gen FirebasePerformance.podspec --platforms="${gen_platform}"
    RunXcodebuild \
      -workspace 'gen/FirebasePerformance/FirebasePerformance.xcworkspace' \
      -scheme "FirebasePerformance-TestApp" \
      "${xcb_flags[@]}" \
      build
    ;;

  Performance-*-integration)
    # Generate the workspace for the SDK to generate Protobuf files.
    export FPR_UNSWIZZLE_AVAILABLE="0"
    pod_gen FirebasePerformance.podspec --platforms=ios --clean

    # Perform "pod install" to install the relevant dependencies
    cd FirebasePerformance/Tests/FIRPerfE2E; pod install; cd -

    # Run E2E Integration Tests for Autopush.
    RunXcodebuild \
      -workspace 'FirebasePerformance/Tests/FIRPerfE2E/FIRPerfE2E.xcworkspace' \
      -scheme "FIRPerfE2EAutopush" \
      FPR_AUTOPUSH_ENV=1 \
      "${ios_flags[@]}" \
      "${xcb_flags[@]}" \
      build \
      test

    # Run E2E Integration Tests for Prod.
    RunXcodebuild \
      -workspace 'FirebasePerformance/Tests/FIRPerfE2E/FIRPerfE2E.xcworkspace' \
      -scheme "FIRPerfE2EProd" \
      "${ios_flags[@]}" \
      "${xcb_flags[@]}" \
      build \
      test
    ;;

  # Note that the combine tests require setting the minimum iOS and tvOS version to 13.0
  *-*-spm)
    RunXcodebuild \
      -scheme $product \
      "${xcb_flags[@]}" \
      IPHONEOS_DEPLOYMENT_TARGET=13.0 \
      TVOS_DEPLOYMENT_TARGET=13.0 \
      test
    ;;

  *-*-spmbuildonly)
    RunXcodebuild \
      -scheme $product \
      "${xcb_flags[@]}" \
      build
    ;;

  ClientApp-iOS-xcodebuild | ClientApp-iOS13-iOS-xcodebuild)
    RunXcodebuild \
      -project 'IntegrationTesting/ClientApp/ClientApp.xcodeproj' \
      -scheme $product \
      "${xcb_flags[@]}" \
      build
    ;;

  ClientApp-CocoaPods*-iOS-xcodebuild)
    RunXcodebuild \
      -workspace 'IntegrationTesting/ClientApp/ClientApp.xcworkspace' \
      -scheme $product \
      "${xcb_flags[@]}" \
      build
    ;;

  *)

    echo "Don't know how to build this product-platform-method combination" 1>&2
    echo "  product=$product" 1>&2
    echo "  platform=$platform" 1>&2
    echo "  method=$method" 1>&2
    exit 1
    ;;

esac
