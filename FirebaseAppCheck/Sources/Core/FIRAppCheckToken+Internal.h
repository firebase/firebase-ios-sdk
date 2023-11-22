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

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckToken.h"

#import <Foundation/Foundation.h>

#import <AppCheckCore/AppCheckCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRAppCheckToken ()

/// A date when the Firebase App Check token was received in the device's local time.
@property(nonatomic) NSDate *receivedAtDate;

/// The designated initializer.
/// @param token A Firebase App Check token.
/// @param expirationDate A Firebase App Check token expiration date in the device local time.
/// @param receivedAtDate A date when the Firebase App Check token was received in the device's
/// local time.
- (instancetype)initWithToken:(NSString *)token
               expirationDate:(NSDate *)expirationDate
               receivedAtDate:(NSDate *)receivedAtDate NS_DESIGNATED_INITIALIZER;

/// Instantiates a `FIRAppCheckToken` token from a `GACAppCheckToken`.
/// @param token The internal App Check token to be converted into a Firebase App Check token.
- (instancetype)initWithInternalToken:(GACAppCheckToken *)token;

- (GACAppCheckToken *)internalToken;

@end

NS_ASSUME_NONNULL_END
