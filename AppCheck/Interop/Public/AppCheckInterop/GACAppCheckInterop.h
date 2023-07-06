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

@protocol GACAppCheckTokenInterop;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(InternalAppCheckTokenHandlerInterop)
typedef void (^GACAppCheckTokenHandlerInterop)(id<GACAppCheckTokenInterop> _Nullable token,
                                               NSError *_Nullable error);

NS_SWIFT_NAME(InternalAppCheckInterop) @protocol GACAppCheckInterop

/// Requests Firebase app check token.
///
/// @param forcingRefresh If `YES`,  a new Firebase app check token is requested and the token
/// cache is ignored. If `NO`, the cached token is used if it exists and has not expired yet. In
/// most cases, `NO` should be used. `YES` should only be used if the server explicitly returns an
/// error, indicating a revoked token.
/// @param handler The completion handler. Includes the app check token if the request succeeds,
/// or an error if the request fails.
- (void)getTokenForcingRefresh:(BOOL)forcingRefresh
                    completion:(void (^)(id<GACAppCheckTokenInterop> _Nullable token,
                                         NSError *_Nullable error))handler
    NS_SWIFT_NAME(token(forcingRefresh:completion:));

/// Retrieve a new limited-use App Check token
///
/// This method does not affect the token generation behavior of the
/// ``tokenForcingRefresh()`` method.
- (void)getLimitedUseTokenWithCompletion:(void (^)(id<GACAppCheckTokenInterop> _Nullable token,
                                                   NSError *_Nullable error))handler;

/// A notification with the specified name is sent to the default notification center
/// (`NotificationCenter.default`) each time a Firebase app check token is refreshed.
/// The user info dictionary contains `-[self notificationTokenKey]` and
/// `-[self notificationAppNameKey]` keys.
- (NSString *)tokenDidChangeNotificationName;

/// `userInfo` key for the FAC token in a notification for `tokenDidChangeNotificationName`.
- (NSString *)notificationTokenKey;
/// `userInfo` key for the `FirebaseApp.name` in a notification for
/// `tokenDidChangeNotificationName`.
- (NSString *)notificationInstanceNameKey;

@end

NS_ASSUME_NONNULL_END
