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

// `DeviceCheckProvider` availability.
#define GAC_DEVICE_CHECK_PROVIDER_AVAILABILITY \
  API_AVAILABLE(ios(11.0), macos(10.15), macCatalyst(13.0), tvos(11.0), watchos(9.0))

#pragma mark - App Attest

// `AppAttestProvider` availability annotations
#define GAC_APP_ATTEST_PROVIDER_AVAILABILITY \
  API_AVAILABLE(ios(14.0), macos(11.3), macCatalyst(14.5), tvos(15.0), watchos(9.0))
