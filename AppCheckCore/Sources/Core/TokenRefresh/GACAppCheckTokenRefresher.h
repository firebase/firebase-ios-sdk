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

#import "AppCheckCore/Sources/Core/TokenRefresh/GACAppCheckTimer.h"

@protocol GACAppCheckSettingsProtocol;
@class GACAppCheckTokenRefreshResult;

NS_ASSUME_NONNULL_BEGIN

/** The block to be called on the token refresh completion.
 *  @param refreshResult The refresh result.
 */
typedef void (^GACAppCheckTokenRefreshCompletion)(GACAppCheckTokenRefreshResult *refreshResult);

/** The block that will be called by `GACAppCheckTokenRefresher` to trigger the token refresh.
 *  @param completion The block that the client must call when the token refresh was completed.
 */
typedef void (^GACAppCheckTokenRefreshBlock)(GACAppCheckTokenRefreshCompletion completion);

@protocol GACAppCheckTokenRefresherProtocol <NSObject>

/// The block to be called when refresh is needed. The client is responsible for actual token
/// refresh in the block.
@property(nonatomic, copy) GACAppCheckTokenRefreshBlock tokenRefreshHandler;

/// Updates the next refresh date based on the new token expiration date. This method should be
/// called when the token update was initiated not by the refresher.
/// @param refreshResult A result of a refresh attempt.
- (void)updateWithRefreshResult:(GACAppCheckTokenRefreshResult *)refreshResult;

@end

/// The class calls `tokenRefreshHandler` periodically to keep FAC token fresh to reduce FAC token
/// exchange overhead for product requests.
@interface GACAppCheckTokenRefresher : NSObject <GACAppCheckTokenRefresherProtocol>

- (instancetype)init NS_UNAVAILABLE;

/// The designated initializer.
/// @param refreshResult A previous token refresh attempt result.
/// @param settings An object that handles Firebase app check settings.
- (instancetype)initWithRefreshResult:(GACAppCheckTokenRefreshResult *)refreshResult
                        timerProvider:(GACTimerProvider)timerProvider
                             settings:(id<GACAppCheckSettingsProtocol>)settings
    NS_DESIGNATED_INITIALIZER;

/// A convenience initializer with a timer provider returning an instance of  `GACAppCheckTimer`.
- (instancetype)initWithRefreshResult:(GACAppCheckTokenRefreshResult *)refreshResult
                             settings:(id<GACAppCheckSettingsProtocol>)settings;

@end

NS_ASSUME_NONNULL_END
