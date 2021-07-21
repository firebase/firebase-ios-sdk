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

@protocol FIRAppCheckTokenResultInterop;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AppCheckTokenHandlerInterop)
typedef void (^FIRAppCheckTokenHandlerInterop)(id<FIRAppCheckTokenResultInterop> tokenResult);

@protocol FIRAppCheckInterop <NSObject>

/// Retrieve a cached or generate a new FAA Token. If forcingRefresh == YES always generates a new
/// token and updates the cache.
- (void)getTokenForcingRefresh:(BOOL)forcingRefresh
                    completion:(FIRAppCheckTokenHandlerInterop)handler
    NS_SWIFT_NAME(getToken(forcingRefresh:completion:));

/// A notification with the specified name is sent to the default notification center
/// (`NotificationCenter.default`) each time a Firebase app check token is refreshed.
/// The user info dictionary contains `-[self notificationTokenKey]` and
/// `-[self notificationAppNameKey]` keys.
- (NSString *)tokenDidChangeNotificationName;

/// `userInfo` key for the FAC token in a notification for `tokenDidChangeNotificationName`.
- (NSString *)notificationTokenKey;
/// `userInfo` key for the `FirebaseApp.name` in a notification for
/// `tokenDidChangeNotificationName`.
- (NSString *)notificationAppNameKey;

@end

NS_ASSUME_NONNULL_END
