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

@protocol FIRAppCheckSettingsProtocol;
@class FIRAppCheckTokenRefreshResult;

NS_ASSUME_NONNULL_BEGIN

/** The block to be called on the token refresh completion.
 *  @param refreshResult The refresh result.
 */
typedef void (^FIRAppCheckTokenRefreshCompletion)(FIRAppCheckTokenRefreshResult *refreshResult);

/** The block that will be called by `FIRAppCheckTokenRefresher` to trigger the token refresh.
 *  @param completion The block that the client must call when the token refresh was completed.
 */
typedef void (^FIRAppCheckTokenRefreshBlock)(FIRAppCheckTokenRefreshCompletion completion);

@protocol FIRAppCheckTokenRefresherProtocol <NSObject>

/// The block to be called when refresh is needed. The client is responsible for actual token
/// refresh in the block.
@property(nonatomic, copy) FIRAppCheckTokenRefreshBlock tokenRefreshHandler;

/// Updates the next refresh date based on the new token expiration date. This method should be
/// called when the token update was initiated not by the refresher.
/// @param refreshResult A result of a refresh attempt.
- (void)updateWithRefreshResult:(FIRAppCheckTokenRefreshResult *)refreshResult;

@end

/// The class calls `tokenRefreshHandler` periodically to keep FAC token fresh to reduce FAC token
/// exchange overhead for product requests.
@interface FIRAppCheckTokenRefresher : NSObject <FIRAppCheckTokenRefresherProtocol>

- (instancetype)init NS_UNAVAILABLE;

/// The designated initializer.
/// @param refreshResult A previous token refresh attempt result.
/// seconds before the actual token expiration time.
/// @param settings An object that handles Firebase app check settings.
- (instancetype)initWithRefreshResult:(FIRAppCheckTokenRefreshResult *)refreshResult
                        timerProvider:(FIRTimerProvider)timerProvider
                             settings:(id<FIRAppCheckSettingsProtocol>)settings
    NS_DESIGNATED_INITIALIZER;

/// A convenience initializer with a timer provider returning an instance of  `FIRAppCheckTimer`.
- (instancetype)initWithRefreshResult:(FIRAppCheckTokenRefreshResult *)refreshResult
                             settings:(id<FIRAppCheckSettingsProtocol>)settings;

@end

NS_ASSUME_NONNULL_END
