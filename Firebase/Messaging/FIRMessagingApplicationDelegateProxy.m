/*
 * Copyright 2018 Google
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

#import "FIRMessagingApplicationDelegateProxy.h"

#import "FIRMessagingLogger.h"
#import "FIRMessaging_Private.h"

@implementation FIRMessagingApplicationDelegateProxy

+ (instancetype)shared {
  static FIRMessagingApplicationDelegateProxy *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[FIRMessagingApplicationDelegateProxy alloc] init];
  });

  return sharedInstance;
}

- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo {
  [[FIRMessaging messaging] appDidReceiveMessage:userInfo];
}

- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  [[FIRMessaging messaging] appDidReceiveMessage:userInfo];
}

- (void)application:(UIApplication *)application
didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  // Pass the APNSToken along to FIRMessaging (and auto-detect the token type)
  [FIRMessaging messaging].APNSToken = deviceToken;
}

- (void)application:(UIApplication *)application
didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  // Log the fact that we failed to register for remote notifications
  FIRMessagingLoggerError(kFIRMessagingMessageCodeRemoteNotificationsProxyAPNSFailed,
                          @"Error in "
                          @"application:didFailToRegisterForRemoteNotificationsWithError: %@",
                          error.localizedDescription);
}

@end
