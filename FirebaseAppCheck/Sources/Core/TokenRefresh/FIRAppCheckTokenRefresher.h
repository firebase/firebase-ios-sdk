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

#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTimer.h"

NS_ASSUME_NONNULL_BEGIN

/** The block to be called on the token refresh completion.
 *  @param success If refresh was successful.
 *  @param tokenExpirationDate The date when the token will expire.
 */
typedef void (^FIRAppCheckTokenRefreshCompletion)(BOOL success,
                                                  NSDate *_Nullable tokenExpirationDate);

/** The block that will be called by `FIRAppCheckTokenRefresher` to trigger the token refresh.
 *  @param completion The block that the client must call when the token refresh was completed.
 */
typedef void (^FIRAppCheckTokenRefreshBlock)(FIRAppCheckTokenRefreshCompletion completion);

@protocol FIRAppCheckTokenRefresherProtocol <NSObject>

/// The block to be called when refresh is needed. The client is responsible for actual token
/// refresh in the block.
@property(atomic, copy) FIRAppCheckTokenRefreshBlock tokenRefreshHandler;

@end

/// The class calls `tokenRefreshHandler` periodically to keep FAC token fresh to reduce FAC token
/// exchange overhead for product requests.
@interface FIRAppCheckTokenRefresher : NSObject <FIRAppCheckTokenRefresherProtocol>

/// The block to be called when refresh is needed. The client is responsible for actual token
/// refresh in the block.
@property(atomic, copy) FIRAppCheckTokenRefreshBlock tokenRefreshHandler;

- (instancetype)init NS_UNAVAILABLE;

/// The designated initializer.
/// @param tokenExpirationDate The initial token expiration date when known. Pass current date or
/// date in the past to trigger refresh once `tokenRefreshHandler` is set.
/// @param tokenExpirationThreshold The token refresh will be triggered  `tokenExpirationThreshold`
/// seconds before the actual token expiration time.
- (instancetype)initWithTokenExpirationDate:(NSDate *)tokenExpirationDate
                   tokenExpirationThreshold:(NSTimeInterval)tokenExpirationThreshold
                              timerProvider:(FIRTimerProvider)timerProvider
    NS_DESIGNATED_INITIALIZER;

/// A convenience initializer with a timer provider returning an instance of  `FIRAppCheckTimer`.
- (instancetype)initWithTokenExpirationDate:(NSDate *)tokenExpirationDate
                   tokenExpirationThreshold:(NSTimeInterval)tokenExpirationThreshold;

@end

NS_ASSUME_NONNULL_END
