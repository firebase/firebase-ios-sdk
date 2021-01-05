/*
 * Copyright 2018 Google
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

#import "Interop/Auth/Public/FIRAuthInterop.h"

NS_ASSUME_NONNULL_BEGIN

/// A fake class to handle Auth interaction. To be used for unit testing only.
@interface FIRAuthInteropFake : NSObject <FIRAuthInterop>

/// The error to be returned in the `getToken` callback.
@property(nonatomic, nullable, strong, readonly) NSError *error;

/// The token to be returned in the `getToken` callback.
@property(nonatomic, nullable, strong, readonly) NSString *token;

/// The user ID to be returned from `getUserID`.
@property(nonatomic, nullable, strong, readonly) NSString *userID;

/// Default initializer.
- (instancetype)initWithToken:(nullable NSString *)token
                       userID:(nullable NSString *)userID
                        error:(nullable NSError *)error NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
