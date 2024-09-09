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

@class GACAppCheckToken;

NS_ASSUME_NONNULL_BEGIN

/// A block to be called before sending API requests.
/// @param request The request that is about to be sent.
typedef void (^GACAppCheckAPIRequestHook)(NSMutableURLRequest *request);

/// Defines the methods required to be implemented by a specific App Check provider.
NS_SWIFT_NAME(AppCheckCoreProvider)
@protocol GACAppCheckProvider <NSObject>

/// Returns a new App Check token.
/// @param handler The completion handler. Make sure to call the handler with either a token
/// or an error.
- (void)getTokenWithCompletion:
    (void (^)(GACAppCheckToken *_Nullable token, NSError *_Nullable error))handler
    NS_SWIFT_NAME(getToken(completion:));

/// Returns a new App Check token suitable for consumption in a limited-use scenario.
/// @param handler The completion handler. Make sure to call the handler with either a token
/// or an error.
- (void)getLimitedUseTokenWithCompletion:
    (void (^)(GACAppCheckToken *_Nullable token, NSError *_Nullable error))handler
    NS_SWIFT_NAME(getLimitedUseToken(completion:));

@end

NS_ASSUME_NONNULL_END
