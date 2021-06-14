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

/// An object representing a Firebase App Check token.
NS_SWIFT_NAME(AppCheckToken)
@interface FIRAppCheckToken : NSObject

/// A Firebase App Check token.
@property(nonatomic, readonly) NSString *token;

/// The App Check token's expiration date in the device's local time.
@property(nonatomic, readonly) NSDate *expirationDate;

- (instancetype)init NS_UNAVAILABLE;

/// The default initializer.
/// @param token A Firebase App Check token.
/// @param expirationDate A Firebase App Check token expiration date in the device local time.
- (instancetype)initWithToken:(NSString *)token expirationDate:(NSDate *)expirationDate;

@end

NS_ASSUME_NONNULL_END
