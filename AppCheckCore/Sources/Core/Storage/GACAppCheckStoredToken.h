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

@interface GACAppCheckStoredToken : NSObject <NSSecureCoding>

/// The Firebase App Check token.
@property(nonatomic, copy, nullable) NSString *token;

/// The Firebase App Check token expiration date in the device local time.
@property(nonatomic, strong, nullable) NSDate *expirationDate;

/// The date when the Firebase App Check token was received in the device's local time.
@property(nonatomic, strong, nullable) NSDate *receivedAtDate;

/// The version of local storage.
@property(nonatomic, readonly) NSInteger storageVersion;

@end

NS_ASSUME_NONNULL_END
