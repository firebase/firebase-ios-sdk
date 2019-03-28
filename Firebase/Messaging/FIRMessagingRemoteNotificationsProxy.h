/*
 * Copyright 2017 Google
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

/**
 *  Swizzle remote-notification callbacks to invoke FIRMessaging methods
 *  before calling original implementations.
 */
@interface FIRMessagingRemoteNotificationsProxy : NSObject

/**
 *  Checks the `FirebaseAppDelegateProxyEnabled` key in the App's Info.plist. If the key is
 *  missing or incorrectly formatted, returns `YES`.
 *
 *  @return YES if the Application Delegate and User Notification Center methods can be swizzled.
 *  Otherwise, returns NO.
 */
+ (BOOL)canSwizzleMethods;

/**
 * A shared instance of `FIRMessagingRemoteNotificationsProxy`
 */
+ (instancetype)sharedProxy;

/**
 *  Swizzles Application Delegate's remote-notification callbacks and User Notification Center
 *  delegate callback, and invokes the original selectors once done.
 */
- (void)swizzleMethodsIfPossible;

@end
