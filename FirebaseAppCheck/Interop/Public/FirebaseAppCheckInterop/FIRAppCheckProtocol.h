/*
 * Copyright 2023 Google LLC
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

@protocol FIRAppCheckTokenProtocol;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AppCheckProtocol)
@protocol FIRAppCheckProtocol <NSObject>

/// Requests Firebase app check token. This method should *only* be used if you need to authorize
/// requests to a non-Firebase backend. Requests to Firebase backend are authorized automatically if
/// configured.
///
/// If your non-Firebase backend exposes sensitive or expensive endpoints that have low traffic
/// volume, consider protecting it with [Replay
/// Protection](https://firebase.google.com/docs/app-check/custom-resource-backend#replay-protection).
/// In this case, use the ``limitedUseToken(completion:)`` instead to obtain a limited-use token.
/// @param forcingRefresh If `YES`,  a new Firebase app check token is requested and the token
/// cache is ignored. If `NO`, the cached token is used if it exists and has not expired yet. In
/// most cases, `NO` should be used. `YES` should only be used if the server explicitly returns an
/// error, indicating a revoked token.
/// @param handler The completion handler. Includes the app check token if the request succeeds,
/// or an error if the request fails.
- (void)tokenForcingRefresh:(BOOL)forcingRefresh
                 completion:(void (^)(id<FIRAppCheckTokenProtocol> _Nullable token,
                                      NSError *_Nullable error))handler
    NS_SWIFT_NAME(token(forcingRefresh:completion:));

/// Requests a limited-use Firebase App Check token. This method should be used only if you need to
/// authorize requests to a non-Firebase backend.
///
/// Returns limited-use tokens that are intended for use with your non-Firebase backend endpoints
/// that are protected with [Replay
/// Protection](https://firebase.google.com/docs/app-check/custom-resource-backend#replay-protection).
/// This method does not affect the token generation behavior of the
/// ``tokenForcingRefresh()`` method.
- (void)limitedUseTokenWithCompletion:(void (^)(id<FIRAppCheckTokenProtocol> _Nullable token,
                                                NSError *_Nullable error))handler;

@end

NS_ASSUME_NONNULL_END
