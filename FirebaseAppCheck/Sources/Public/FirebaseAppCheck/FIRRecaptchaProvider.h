/*
 * Copyright 2026 Google LLC
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

#import <Foundation/Foundation.h>
#import "FIRAppCheckAvailability.h"
#import "FIRAppCheckProvider.h"

@class FIRApp;

NS_ASSUME_NONNULL_BEGIN

/// App Check provider that verifies app integrity using
/// [reCAPTCHA Enterprise for iOS](https://cloud.google.com/recaptcha/docs/instrument-ios-apps)
/// API.
NS_SWIFT_NAME(RecaptchaProvider)
@interface FIRRecaptchaProvider : NSObject <FIRAppCheckProvider>

- (instancetype)init NS_UNAVAILABLE;

/// The default initializer.
/// @param app A `FirebaseApp` instance.
/// @param siteKey The reCAPTCHA Enterprise iOS site key to be used during
///     attestation.
/// @return An instance of `RecaptchaProvider` if the provided
///     `FirebaseApp` instance contains all required parameters.
- (nullable instancetype)initWithApp:(FIRApp *)app siteKey:(NSString *)siteKey;

@end
NS_ASSUME_NONNULL_END
