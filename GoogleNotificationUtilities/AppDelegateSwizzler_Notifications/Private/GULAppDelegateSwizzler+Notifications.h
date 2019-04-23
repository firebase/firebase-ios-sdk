// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>
#import <GoogleUtilities/GULAppDelegateSwizzler.h>

NS_ASSUME_NONNULL_BEGIN

@interface GULAppDelegateSwizzler (Notifications)

/** This method ensures that the original app delegate has been proxied including APNS related
 *  methods. Call this before registering your interceptor. This method is safe to call multiple
 *  times (but it only proxies the app delegate once) or
 *  after +[GULAppDelegateSwizzler proxyOriginalDelegate]
 *
 *  This method calls +[GULAppDelegateSwizzler proxyOriginalDelegate] under the hood.
 *  After calling this method the following App Delegate methods will be proxied in addition to
 *  the methods proxied by proxyOriginalDelegate:
 *  @code
 *    - application:didRegisterForRemoteNotificationsWithDeviceToken:
 *    - application:didFailToRegisterForRemoteNotificationsWithError:
 *    - application:didReceiveRemoteNotification:fetchCompletionHandler:
 *    - application:didReceiveRemoteNotification:
 *  @endcode
 *
 *  The method has no effect for extensions.
 *
 *  @see proxyOriginalDelegate
 */
+ (void)proxyOriginalDelegateIncludingAPNSMethods;

/** Resets the token that prevents the app delegate proxy from being isa swizzled multiple times. */
+ (void)resetProxyOriginalDelegateIncludingAPNSMethodsOnceToken;

@end

NS_ASSUME_NONNULL_END
