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

NS_ASSUME_NONNULL_BEGIN

@class GACAppCheckToken;

NS_SWIFT_NAME(AppCheckCoreTokenResult)
@interface GACAppCheckTokenResult : NSObject

/// An App Check token in the case of success or a placeholder token in the case of a failure.
@property(nonatomic, readonly) GACAppCheckToken *token;

/// A token fetch error in the case of a failure or `nil` in the case of success.
@property(nonatomic, readonly, nullable) NSError *error;

- (instancetype)initWithToken:(GACAppCheckToken *)token;

- (instancetype)initWithError:(NSError *)error;

- (instancetype)initWithToken:(GACAppCheckToken *)token
                        error:(nullable NSError *)error NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
