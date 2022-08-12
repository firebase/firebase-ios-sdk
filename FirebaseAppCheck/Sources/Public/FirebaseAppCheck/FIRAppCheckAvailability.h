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

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#pragma mark - DeviceCheck

// DeviceCheck availability was extended to watchOS in Xcode 14.
#if defined(__WATCHOS_9_0) && __WATCH_OS_VERSION_MAX_ALLOWED >= __WATCHOS_9_0

// Targets where DeviceCheck framework is available to be used in preprocessor conditions.
#define FIR_DEVICE_CHECK_SUPPORTED_TARGETS \
  TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV || TARGET_OS_WATCH

// `DeviceCheckProvider` availability.
#define FIR_DEVICE_CHECK_PROVIDER_AVAILABILITY \
  API_AVAILABLE(ios(11.0), macos(10.15), tvos(11.0), watchos(9.0))

// TODO(ncooke3): Remove `#else` clause when Xcode 14 is the minimum supported Xcode.
#else  // defined(__WATCHOS_9_0) && __WATCH_OS_VERSION_MAX_ALLOWED >= __WATCHOS_9_0

// Targets where DeviceCheck framework is available to be used in preprocessor conditions.
#define FIR_DEVICE_CHECK_SUPPORTED_TARGETS TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV

// `DeviceCheckProvider` availability.
#define FIR_DEVICE_CHECK_PROVIDER_AVAILABILITY \
  API_AVAILABLE(ios(11.0), macos(10.15), tvos(11.0)) API_UNAVAILABLE(watchos)

#endif  // defined(__WATCHOS_9_0) && __WATCH_OS_VERSION_MAX_ALLOWED >= __WATCHOS_9_0

#pragma mark - App Attest

#if defined(__WATCHOS_9_0) && __WATCH_OS_VERSION_MAX_ALLOWED >= __WATCHOS_9_0

// Targets where `DCAppAttestService` is available to be used in preprocessor conditions.
#define FIR_APP_ATTEST_SUPPORTED_TARGETS \
  TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV || TARGET_OS_WATCH

// `AppAttestProvider` availability annotations
#define FIR_APP_ATTEST_PROVIDER_AVAILABILITY \
  API_AVAILABLE(macos(11.0), ios(14.0), tvos(15.0), watchos(9.0))

// TODO(ncooke3): Remove `#else` clause when Xcode 14 is the minimum supported Xcode.
#else  // defined(__WATCHOS_9_0) && __WATCH_OS_VERSION_MAX_ALLOWED >= __WATCHOS_9_0

// Targets where `DCAppAttestService` is available to be used in preprocessor conditions.
#define FIR_APP_ATTEST_SUPPORTED_TARGETS TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV

// `AppAttestProvider` availability annotations
#define FIR_APP_ATTEST_PROVIDER_AVAILABILITY \
  API_AVAILABLE(macos(11.0), ios(14.0), tvos(15.0)) API_UNAVAILABLE(watchos)

#endif  // defined(__WATCHOS_9_0) && __WATCH_OS_VERSION_MAX_ALLOWED >= __WATCHOS_9_0
