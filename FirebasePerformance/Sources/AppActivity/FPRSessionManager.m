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

#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager.h"
#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager+Private.h"

#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/FPRConsoleLogger.h"
#import "FirebasePerformance/Sources/Gauges/FPRGaugeManager.h"

#import <UIKit/UIKit.h>

NSString *const kFPRSessionIdUpdatedNotification = @"kFPRSessionIdUpdatedNotification";
NSString *const kFPRSessionIdNotificationKey = @"kFPRSessionIdNotificationKey";

@interface FPRSessionManager ()

@property(nonatomic, readwrite) NSNotificationCenter *sessionNotificationCenter;

/**
 * Creates an instance of FPRSesssionManager with the notification center provided. All the
 * notifications from the session manager will sent using this notification center.
 *
 * @param notificationCenter Notification center with which the session manager with be initialized.
 * @return Returns an instance of the session manager.
 */
- (instancetype)initWithNotificationCenter:(NSNotificationCenter *)notificationCenter;

@end

@implementation FPRSessionManager

+ (FPRSessionManager *)sharedInstance {
  static FPRSessionManager *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSNotificationCenter *notificationCenter = [[NSNotificationCenter alloc] init];
    instance = [[FPRSessionManager alloc] initWithNotificationCenter:notificationCenter];
  });
  return instance;
}

- (FPRSessionManager *)initWithNotificationCenter:(NSNotificationCenter *)notificationCenter {
  self = [super init];
  if (self) {
    _sessionNotificationCenter = notificationCenter;
    // Empty string is immediately replaced when FirebaseCore runs Fireperf's
    // FIRComponentCreationBlock, because in the creation block we register Fireperf with Sessions,
    // and the registration function immediately propagates real sessionId. This is at an early time
    // in initialization that any trace is yet to be created.
    _sessionDetails = [[FPRSessionDetails alloc] initWithSessionId:@""
                                                           options:FPRSessionOptionsNone];
  }
  return self;
}

- (void)stopGaugesIfRunningTooLong:(NSDate *)now {
  NSUInteger maxSessionLength = [[FPRConfigurations sharedInstance] maxSessionLengthInMinutes];
  if ([self.sessionDetails sessionLengthInMinutes:now] >= maxSessionLength) {
    [[FPRGaugeManager sharedInstance] stopCollectingGauges:FPRGaugeCPU | FPRGaugeMemory];
  }
}

/**
 * Stops current session, and create a new session with new session id.
 *
 * @param sessionIdString New session id.
 */
- (void)updateSessionId:(NSString *)sessionIdString {
  [self updateSessionId:sessionIdString forceGauges:false];
}

- (void)updateSessionId:(NSString *)sessionIdString forceGauges:(BOOL)forceGauges {
  FPRSessionOptions sessionOptions = FPRSessionOptionsNone;
  FPRGaugeManager *gaugeManager = [FPRGaugeManager sharedInstance];
  if (forceGauges || [self isGaugeCollectionEnabledForSessionId:sessionIdString]) {
    [gaugeManager startCollectingGauges:FPRGaugeCPU | FPRGaugeMemory forSessionId:sessionIdString];
    sessionOptions = FPRSessionOptionsGauges;
  } else {
    [gaugeManager stopCollectingGauges:FPRGaugeCPU | FPRGaugeMemory];
  }

  FPRLogDebug(kFPRSessionId, @"Session Id changed - %@", sessionIdString);
  FPRSessionDetails *sessionInfo = [[FPRSessionDetails alloc] initWithSessionId:sessionIdString
                                                                        options:sessionOptions];
  self.sessionDetails = sessionInfo;
  NSMutableDictionary<NSString *, FPRSessionDetails *> *userInfo =
      [[NSMutableDictionary alloc] init];
  [userInfo setObject:sessionInfo forKey:kFPRSessionIdNotificationKey];
  [self.sessionNotificationCenter postNotificationName:kFPRSessionIdUpdatedNotification
                                                object:self
                                              userInfo:[userInfo copy]];
}

/**
 * Checks if the provided sessionId can have gauge data collection enabled.
 *
 * @param sessionId Session Id for which the check is done.
 * @return YES if gauge collection is enabled, NO otherwise.
 */
- (BOOL)isGaugeCollectionEnabledForSessionId:(NSString *)sessionId {
  float_t sessionSamplePercentage = [[FPRConfigurations sharedInstance] sessionsSamplingPercentage];
  double randomNumberBetween0And1 = ((double)arc4random() / UINT_MAX);
  BOOL sessionsEnabled = randomNumberBetween0And1 * 100 < sessionSamplePercentage;
  return sessionsEnabled;
}

@end
