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

#import <TargetConditionals.h>

// Resolves with targets where `DCAppAttestService` is available to be used in preprocessor
// conditions.
#define FIR_APP_ATTEST_SUPPORTED_TARGETS TARGET_OS_IOS || TARGET_OS_OSX

// FIRAppAttestProvider availability annotations
#define FIR_APP_ATTEST_PROVIDER_AVAILABILITY \
  API_AVAILABLE(macos(11.0), ios(14.0)) API_UNAVAILABLE(tvos, watchos)
