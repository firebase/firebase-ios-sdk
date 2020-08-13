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
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMFetchOnAppForegroundFlow.h"
@implementation FIRIAMFetchOnAppForegroundFlow
- (void)start {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM600002",
              @"Start observing app foreground notifications for message fetching.");
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appWillEnterForeground:)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];
#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
  if (@available(iOS 13.0, *)) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillEnterForeground:)
                                                 name:UISceneWillEnterForegroundNotification
                                               object:nil];
  }
#endif  // defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
}

- (void)appWillEnterForeground:(NSNotification *)notification {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM600001",
              @"App foregrounded, wake up to see if we can fetch in-app messaging.");
  // for fetch operation, dispatch it to non main UI thread to avoid blocking. It's ok to dispatch
  // to a concurrent global queue instead of serial queue since app open event won't happen at
  // fast speed to cause race conditions
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
    [self checkAndFetchForInitialAppLaunch:NO];
  });
}

- (void)stop {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM600003",
              @"Stop observing app foreground notifications.");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end

#endif  // TARGET_OS_IOS
