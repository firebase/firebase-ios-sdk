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

#import <FirebaseAppCheckInterop/FirebaseAppCheckInterop.h>

NS_ASSUME_NONNULL_BEGIN

/** @var kFakeAppCheckToken
    @brief A fake App Check token.
 */
static NSString *const kFakeAppCheckToken = @"appCheckToken";

@interface FIRFakeAppCheck : NSObject <FIRAppCheckInterop>

/** @property tokenDidChangeNotificationName
    @brief A notification with the specified name is sent to the default notification center
   (`NotificationCenter.default`) each time a Firebase app check token is refreshed.
 */
@property(nonatomic, nonnull, readwrite, copy) NSString *tokenDidChangeNotificationName;

/** @property notificationAppNameKey
    @brief `userInfo` key for the FAC token in a notification for `tokenDidChangeNotificationName`.
 */
@property(nonatomic, nonnull, readwrite, copy) NSString *notificationAppNameKey;

/** @property notificationAppNameKey
    @brief `userInfo` key for the `FirebaseApp.name` in a notification for
   `tokenDidChangeNotificationName`.
 */
@property(nonatomic, nonnull, readwrite, copy) NSString *notificationTokenKey;

/** @fn getTokenForcingRefresh:completion:
    @brief A fake appCheck used for dependency injection during testing.
    @param forcingRefresh dtermines if a new token is generated.
    @param handler to update the cache.
 */
- (void)getTokenForcingRefresh:(BOOL)forcingRefresh
                    completion:(nonnull FIRAppCheckTokenHandlerInterop)handler;

@end

NS_ASSUME_NONNULL_END
