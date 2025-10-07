// Copyright 2020 Google LLC
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

#import "FirebasePerformance/Sources/AppActivity/FPRTraceBackgroundActivityTracker.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "FirebasePerformance/Sources/AppActivity/FPRAppActivityTracker.h"

@interface FPRTraceBackgroundActivityTracker ()

@property(nonatomic, readwrite) FPRTraceState traceBackgroundState;

- (void)registerNotificationObservers;

@end

@implementation FPRTraceBackgroundActivityTracker

- (instancetype)init {
  self = [super init];
  if (self) {
    if ([FPRAppActivityTracker sharedInstance].applicationState == FPRApplicationStateBackground) {
      _traceBackgroundState = FPRTraceStateBackgroundOnly;
    } else {
      _traceBackgroundState = FPRTraceStateForegroundOnly;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (strongSelf) {
        [strongSelf registerNotificationObservers];
      }
    });
  }
  return self;
}

- (void)registerNotificationObservers {
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationDidBecomeActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:[UIApplication sharedApplication]];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationDidEnterBackground:)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:[UIApplication sharedApplication]];
}

- (void)dealloc {
  // Remove all the notification observers registered.
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UIApplicationDelegate events

/**
 * This gets called whenever the app becomes active.
 *
 * @param notification Notification received during app launch.
 */
- (void)applicationDidBecomeActive:(NSNotification *)notification {
  if (_traceBackgroundState == FPRTraceStateBackgroundOnly) {
    _traceBackgroundState = FPRTraceStateBackgroundAndForeground;
  }
}

/**
 * This gets called whenever the app enters background.
 *
 * @param notification Notification received when the app enters background.
 */
- (void)applicationDidEnterBackground:(NSNotification *)notification {
  if (_traceBackgroundState == FPRTraceStateForegroundOnly) {
    _traceBackgroundState = FPRTraceStateBackgroundAndForeground;
  }
}

@end
