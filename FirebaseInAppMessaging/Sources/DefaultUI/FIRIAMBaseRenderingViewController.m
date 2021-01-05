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

#import "FirebaseInAppMessaging/Sources/DefaultUI/FIRCore+InAppMessagingDisplay.h"
#import "FirebaseInAppMessaging/Sources/DefaultUI/FIRIAMBaseRenderingViewController.h"
#import "FirebaseInAppMessaging/Sources/Private/Util/FIRIAMTimeFetcher.h"

@interface FIRIAMBaseRenderingViewController ()
// For fiam messages, it's required to be kMinValidImpressionTime to
// be considered as a valid impression help. If the app is closed before that's reached,
// SDK may try to render the same message again in the future.
@property(nonatomic, nullable) NSTimer *minImpressionTimer;

// Tracking the start time when the current impression session start.
@property(nonatomic) double currentImpressionStartTime;

@end

static const NSTimeInterval kMinValidImpressionTime = 3.0;

@implementation FIRIAMBaseRenderingViewController

- (nullable FIRInAppMessagingDisplayMessage *)inAppMessage {
  return nil;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // In order to track display time for this message, we need to respond to
  // app foreground/background events since viewDidAppear/viewDidDisappear are not
  // triggered when app switches happen.
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appWillBecomeInactive:)
                                               name:UIApplicationWillResignActiveNotification
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appDidBecomeActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
  if (@available(iOS 13.0, *)) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillBecomeInactive:)
                                                 name:UISceneWillDeactivateNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UISceneDidActivateNotification
                                               object:nil];
  }
#endif  // defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
  self.aggregateImpressionTimeInSeconds = 0;
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self impressionStartCheckpoint];
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
  [self impressionStopCheckpoint];
}

// Call this when the view starts to be rendered so that we can track the aggregate impression
// time for the current message
- (void)impressionStartCheckpoint {
  self.currentImpressionStartTime = [self.timeFetcher currentTimestampInSeconds];
  [self setupMinImpressionTimer];
}

// Trigger this when the view stops to be rendered so that we can track the aggregate impression
// time for the current message
- (void)impressionStopCheckpoint {
  // Pause the impression timer.
  [self.minImpressionTimer invalidate];

  // Track the effective impression time for this impression session.
  double effectiveImpressionTime =
      [self.timeFetcher currentTimestampInSeconds] - self.currentImpressionStartTime;
  self.aggregateImpressionTimeInSeconds += effectiveImpressionTime;
}

- (void)dealloc {
  FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID200001",
              @"[FIDBaseRenderingViewController dealloc] triggered");
  [self.minImpressionTimer invalidate];
  [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)appWillBecomeInactive:(NSNotification *)notification {
  [self impressionStopCheckpoint];
}

- (void)appDidBecomeActive:(NSNotification *)notification {
  [self impressionStartCheckpoint];
}

- (void)minImpressionTimeReached {
  FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID200004",
              @"Min impression time has been reached.");

  if ([self.displayDelegate respondsToSelector:@selector(impressionDetectedForMessage:)]) {
    [self.displayDelegate impressionDetectedForMessage:[self inAppMessage]];
  }

  [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)setupMinImpressionTimer {
  NSTimeInterval remaining = kMinValidImpressionTime - self.aggregateImpressionTimeInSeconds;
  FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID200006",
              @"Remaining minimal impression time is %lf", remaining);

  if (remaining < 0.00001) {
    return;
  }

  __weak id weakSelf = self;
  self.minImpressionTimer =
      [NSTimer scheduledTimerWithTimeInterval:remaining
                                       target:weakSelf
                                     selector:@selector(minImpressionTimeReached)
                                     userInfo:nil
                                      repeats:NO];
}

- (void)dismissView:(FIRInAppMessagingDismissType)dismissType {
  [self.view.window setHidden:YES];
  // This is for the purpose of releasing the potential memory associated with the image view.
  self.view.window.rootViewController = nil;

  if (self.displayDelegate) {
    [self.displayDelegate messageDismissed:[self inAppMessage] dismissType:dismissType];
  } else {
    FIRLogWarning(kFIRLoggerInAppMessagingDisplay, @"I-FID200007",
                  @"Display delegate is nil while message is being dismissed.");
  }
  return;
}

- (void)followAction:(FIRInAppMessagingAction *)action {
  [self.view.window setHidden:YES];
  // This is for the purpose of releasing the potential memory associated with the image view.
  self.view.window.rootViewController = nil;

  if (self.displayDelegate) {
    [self.displayDelegate messageClicked:[self inAppMessage] withAction:action];
  } else {
    FIRLogWarning(kFIRLoggerInAppMessagingDisplay, @"I-FID200008",
                  @"Display delegate is nil while trying to follow action :%@.", action.actionText);
  }
  return;
}
@end

#endif  // TARGET_OS_IOS
