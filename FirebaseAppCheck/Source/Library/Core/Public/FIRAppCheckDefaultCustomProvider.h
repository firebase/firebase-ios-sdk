/*
 * Copyright 2020 Google LLC
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

#import <FirebaseAppCheck/FIRAppCheckProvider.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AppCheckCustomJWTHandler)
typedef void (^FIRAppCheckCustomJWTHandler)(NSString *_Nullable customJWT,
                                            NSError *_Nullable error);

/// `JWTHandler` must be called with either JWT or an error.
NS_SWIFT_NAME(AppCheckCustomJWTRequestHandler)
typedef void (^FIRAppCheckCustomJWTRequestHandler)(FIRAppCheckCustomJWTHandler JWTHandler);

/// Provides a default implementation of a custom attestation provider. Handles exchange of a custom
/// JWT to FAA token.
NS_SWIFT_NAME(AppCheckDefaultCustomProvider)
@interface FIRAppCheckDefaultCustomProvider : NSObject <FIRAppCheckProvider>

/// The `handler` will be called each time when FAA token needs to be refreshed.
- (instancetype)initWithCustomJWTRequestHandler:(FIRAppCheckCustomJWTRequestHandler)handler;

@end

NS_ASSUME_NONNULL_END
