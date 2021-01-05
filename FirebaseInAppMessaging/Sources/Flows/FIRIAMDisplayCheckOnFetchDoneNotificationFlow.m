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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseInAppMessaging/Sources/FIRCore+InAppMessaging.h"

#import "FirebaseInAppMessaging/Sources/Flows/FIRIAMDisplayCheckOnFetchDoneNotificationFlow.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMDisplayExecutor.h"

extern NSString *const kFIRIAMFetchIsDoneNotification;

@implementation FIRIAMDisplayCheckOnFetchDoneNotificationFlow

- (void)start {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240001",
              @"Start observing fetch done notifications for rendering messages.");
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(fetchIsDone)
                                               name:kFIRIAMFetchIsDoneNotification
                                             object:nil];
}

- (void)checkAndRenderMessage {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
    [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
  });
}

- (void)fetchIsDone {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240002",
              @"Fetch is done. Start message rendering flow.");

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * (int64_t)NSEC_PER_MSEC),
                 dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
                   [self checkAndRenderMessage];
                 });
}

- (void)stop {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240003",
              @"Stop observing fetch is done notifications.");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end

#endif  // TARGET_OS_IOS
