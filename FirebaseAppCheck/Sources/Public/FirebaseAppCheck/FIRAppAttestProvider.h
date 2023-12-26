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

#import <Foundation/Foundation.h>

#import "FIRAppCheckProvider.h"

#import "FIRAppCheckAvailability.h"

@class FIRApp;

NS_ASSUME_NONNULL_BEGIN

/// Firebase App Check provider that verifies app integrity using the
/// [DeviceCheck](https://developer.apple.com/documentation/devicecheck/dcappattestservice) API.
/// This class is available on all platforms for select OS versions. See
/// https://firebase.google.com/docs/ios/learn-more for more details.
FIR_APP_ATTEST_PROVIDER_AVAILABILITY
NS_SWIFT_NAME(AppAttestProvider)
@interface FIRAppAttestProvider : NSObject <FIRAppCheckProvider>

- (instancetype)init NS_UNAVAILABLE;

/// The default initializer.
/// @param app A `FirebaseApp` instance.
/// @return An instance of `AppAttestProvider` if the provided `FirebaseApp` instance contains all
/// required parameters.
- (nullable instancetype)initWithApp:(FIRApp *)app;

/* Jazzy doesn't generate documentation for protocol-inherited
 * methods, so this is copied over from the protocol declaration.
 */
/// Returns a new Firebase App Check token.
/// @param handler The completion handler. Make sure to call the handler with either a token
/// or an error.
- (void)getTokenWithCompletion:
    (void (^)(FIRAppCheckToken *_Nullable token, NSError *_Nullable error))handler
    NS_SWIFT_NAME(getToken(completion:));

/// Returns a new Firebase App Check token.
/// When implementing this method for your custom provider, the token returned should be suitable
/// for consumption in a limited-use scenario. If you do not implement this method, the
/// getTokenWithCompletion will be invoked instead whenever a limited-use token is requested.
/// @param handler The completion handler. Make sure to call the handler with either a token
/// or an error.
- (void)getLimitedUseTokenWithCompletion:
    (void (^)(FIRAppCheckToken *_Nullable token, NSError *_Nullable error))handler
    NS_SWIFT_NAME(getLimitedUseToken(completion:));

@end

NS_ASSUME_NONNULL_END
