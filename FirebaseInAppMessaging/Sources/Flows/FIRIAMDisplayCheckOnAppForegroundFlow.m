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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseInAppMessaging/Sources/FIRCore+InAppMessaging.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMDisplayCheckOnAppForegroundFlow.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMDisplayExecutor.h"

@implementation FIRIAMDisplayCheckOnAppForegroundFlow

- (void)start {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM500002",
              @"Start observing app foreground notifications for rendering messages.");
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(checkAndDisplayNextAppForegroundMessageFromForeground:)
             name:UIApplicationWillEnterForegroundNotification
           object:nil];
#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
  if (@available(iOS 13.0, *)) {
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(checkAndDisplayNextAppForegroundMessageFromForeground:)
               name:UISceneWillEnterForegroundNotification
             object:nil];
  }
#endif  // defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
}

- (void)checkAndDisplayNextAppForegroundMessageFromForeground:(NSNotification *)notification {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM500001",
              @"App foregrounded, wake up to check in-app messaging.");

  // Show the message with 0.5 second delay so that the app's UI is more stable.
  // When messages are displayed, the UI operation will be dispatched back to main UI thread.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * (int64_t)NSEC_PER_MSEC),
                 dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
                   [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
                 });
}

- (void)stop {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM500004",
              @"Stop observing app foreground notifications.");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end

#endif  // TARGET_OS_IOS
