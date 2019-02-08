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

#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>
#import <FirebaseAnalyticsInterop/FIRAnalyticsInteropListener.h>
#import <FirebaseCore/FIRLogger.h>

#import "FIRCore+InAppMessaging.h"
#import "FIRIAMDisplayCheckOnAnalyticEventsFlow.h"
#import "FIRIAMDisplayExecutor.h"
#import "FIRInAppMessagingPrivate.h"

@interface FIRIAMDisplayCheckOnAnalyticEventsFlow () <FIRAnalyticsInteropListener>
@end

@implementation FIRIAMDisplayCheckOnAnalyticEventsFlow {
  dispatch_queue_t eventListenerQueue;
}

- (void)start {
  @synchronized(self) {
    if (eventListenerQueue == nil) {
      eventListenerQueue =
          dispatch_queue_create("com.google.firebase.inappmessage.firevent_listener", NULL);
    }

    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM140002",
                @"Start observing Firebase Analytics events for rendering messages.");

    [[FIRInAppMessaging inAppMessaging].analytics registerAnalyticsListener:self
                                                                 withOrigin:@"fiam"];
  }
}

- (void)messageTriggered:(NSString *)name parameters:(NSDictionary *)parameters {
  // Dispatch to a serial queue eventListenerQueue to avoid the complications that two
  // concurrent Firebase Analytics events triggering the
  // checkAndDisplayNextContextualMessageForAnalyticsEvent flow concurrently.
  dispatch_async(self->eventListenerQueue, ^{
    [self.displayExecutor checkAndDisplayNextContextualMessageForAnalyticsEvent:name];
  });
}

- (void)stop {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM140003",
              @"Stop observing Firebase Analytics events for display check.");

  @synchronized(self) {
    [[FIRInAppMessaging inAppMessaging].analytics unregisterAnalyticsListenerWithOrigin:@"fiam"];
  }
}

@end
