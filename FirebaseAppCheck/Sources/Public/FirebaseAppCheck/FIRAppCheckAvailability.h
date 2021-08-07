/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Availability conditions for different App Check SDK components.

#import <TargetConditionals.h>

#pragma mark - DeviceCheck

// Targets where DeviceCheck framework is available to be used in preprocessor conditions.
#define FIR_DEVICE_CHECK_SUPPORTED_TARGETS TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV

// `DeviceCheckProvider` availability.
#define FIR_DEVICE_CHECK_PROVIDER_AVAILABILITY \
  API_AVAILABLE(ios(11.0), macos(10.15), tvos(11.0)) API_UNAVAILABLE(watchos)

#pragma mark - App Attest

// App Attest availability was extended to macOS and Mac Catalyst in Xcode 12.5.
#if (defined(__IPHONE_14_5) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_14_5) || \
    (defined(__MAC_11_3) && __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_11_3) ||        \
    (defined(__TVOS_14_5) && __TV_OS_VERSION_MAX_ALLOWED >= __TVOS_14_5)

// Targets where `DCAppAttestService` is available to be used in preprocessor conditions.
#define FIR_APP_ATTEST_SUPPORTED_TARGETS TARGET_OS_IOS || TARGET_OS_OSX

// `AppAttestProvider` availability annotations
#define FIR_APP_ATTEST_PROVIDER_AVAILABILITY \
  API_AVAILABLE(macos(11.0), ios(14.0)) API_UNAVAILABLE(tvos, watchos)

#else  // (defined(__IPHONE_14_5) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_14_5) || \
          (defined(__MAC_11_3) && __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_11_3) ||        \
          (defined(__TVOS_14_5) && __TV_OS_VERSION_MAX_ALLOWED >= __TVOS_14_5)

// Targets where `DCAppAttestService` is available to be used in preprocessor conditions.
#define FIR_APP_ATTEST_SUPPORTED_TARGETS TARGET_OS_IOS && !TARGET_OS_MACCATALYST

// `AppAttestProvider` availability annotations
#define FIR_APP_ATTEST_PROVIDER_AVAILABILITY \
  API_AVAILABLE(ios(14.0)) API_UNAVAILABLE(macos, tvos, watchos)

#endif  // (defined(__IPHONE_14_5) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_14_5) || \
          (defined(__MAC_11_3) && __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_11_3) ||        \
          (defined(__TVOS_14_5) && __TV_OS_VERSION_MAX_ALLOWED >= __TVOS_14_5)
