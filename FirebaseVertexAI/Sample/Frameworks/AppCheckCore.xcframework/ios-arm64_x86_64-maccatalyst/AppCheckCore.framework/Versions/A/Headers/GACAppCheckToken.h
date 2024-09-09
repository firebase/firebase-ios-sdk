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

NS_ASSUME_NONNULL_BEGIN

/// An object representing an App Check token.
NS_SWIFT_NAME(AppCheckCoreToken)
@interface GACAppCheckToken : NSObject

/// The App Check token.
@property(nonatomic, readonly) NSString *token;

/// The App Check token's expiration date in the device's local time.
@property(nonatomic, readonly) NSDate *expirationDate;

/// The date when the App Check token was received in the device's local time.
@property(nonatomic, readonly) NSDate *receivedAtDate;

- (instancetype)init NS_UNAVAILABLE;

/// Convenience initializer that uses the current device local time to set `receivedAtDate`.
/// @param token A Firebase App Check token.
/// @param expirationDate A Firebase App Check token expiration date in the device local time.
- (instancetype)initWithToken:(NSString *)token expirationDate:(NSDate *)expirationDate;

/// The designated initializer.
/// @param token A Firebase App Check token.
/// @param expirationDate A Firebase App Check token expiration date in the device local time.
/// @param receivedAtDate A date when the Firebase App Check token was received in the device's
/// local time.
- (instancetype)initWithToken:(NSString *)token
               expirationDate:(NSDate *)expirationDate
               receivedAtDate:(NSDate *)receivedAtDate NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
