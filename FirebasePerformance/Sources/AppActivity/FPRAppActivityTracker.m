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

#import "FirebasePerformance/Sources/AppActivity/FPRAppActivityTracker.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager.h"
#import "FirebasePerformance/Sources/Gauges/CPU/FPRCPUGaugeCollector+Private.h"
#import "FirebasePerformance/Sources/Gauges/FPRGaugeManager.h"
#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeCollector+Private.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Private.h"

#import <GoogleUtilities/GULAppEnvironmentUtil.h>

static NSDate *appStartTime = nil;
static NSDate *doubleDispatchTime = nil;
static NSDate *applicationDidFinishLaunchTime = nil;
static NSTimeInterval gAppStartMaxValidDuration = 60 * 60;  // 60 minutes.
static FPRCPUGaugeData *gAppStartCPUGaugeData = nil;
static FPRMemoryGaugeData *gAppStartMemoryGaugeData = nil;

NSString *const kFPRAppStartTraceName = @"_as";
NSString *const kFPRAppStartStageNameTimeToUI = @"_astui";
NSString *const kFPRAppStartStageNameTimeToFirstDraw = @"_astfd";
NSString *const kFPRAppStartStageNameTimeToUserInteraction = @"_asti";
NSString *const kFPRAppTraceNameForegroundSession = @"_fs";
NSString *const kFPRAppTraceNameBackgroundSession = @"_bs";
NSString *const kFPRAppCounterNameTraceEventsRateLimited = @"_fstec";
NSString *const kFPRAppCounterNameNetworkTraceEventsRateLimited = @"_fsntc";
NSString *const kFPRAppCounterNameTraceNotStopped = @"_tsns";
NSString *const kFPRAppCounterNameActivePrewarm = @"_fsapc";
NSString *const kFPRAppCounterNameDoubleDispatch = @"_fsddc";

@interface FPRAppActivityTracker ()

/** The foreground session trace. Will be set only when the app is in the foreground. */
@property(nonatomic, readwrite) FIRTrace *foregroundSessionTrace;

/** The background session trace. Will be set only when the app is in the background. */
@property(nonatomic, readwrite) FIRTrace *backgroundSessionTrace;

/** Current running state of the application. */
@property(nonatomic, readwrite) FPRApplicationState applicationState;

/** Trace to measure the app start performance. */
@property(nonatomic) FIRTrace *appStartTrace;

/** Tracks if the gauge metrics are dispatched. */
@property(nonatomic) BOOL appStartGaugeMetricDispatched;

/** Firebase Performance Configuration object */
@property(nonatomic) FPRConfigurations *configurations;

/** Starts tracking app active sessions. */
- (void)startAppActivityTracking;

@end

@implementation FPRAppActivityTracker

+ (void)load {
  // This is an approximation of the app start time.
  appStartTime = [NSDate date];

  // Double dispatch is used to detect prewarming, but if it causes hang or crash in the future
  // developers can disable it by setting a plist flag "fireperf_disable_dd" to true
  if ([[[NSBundle mainBundle] objectForInfoDictionaryKey:@"fireperf_disable_dd"] boolValue] == NO) {
    dispatch_async(dispatch_get_main_queue(), ^{
      dispatch_async(dispatch_get_main_queue(), ^{
        doubleDispatchTime = [NSDate date];
      });
    });
  }

  gAppStartCPUGaugeData = fprCollectCPUMetric();
  gAppStartMemoryGaugeData = fprCollectMemoryMetric();
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(windowDidBecomeVisible:)
                                               name:UIWindowDidBecomeVisibleNotification
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(applicationDidFinishLaunching:)
                                               name:UIApplicationDidFinishLaunchingNotification
                                             object:nil];
}

+ (void)windowDidBecomeVisible:(NSNotification *)notification {
  FPRAppActivityTracker *activityTracker = [self sharedInstance];
  [activityTracker startAppActivityTracking];

  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:UIWindowDidBecomeVisibleNotification
                                                object:nil];
}

+ (void)applicationDidFinishLaunching:(NSNotification *)notification {
  applicationDidFinishLaunchTime = [NSDate date];
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:UIApplicationDidFinishLaunchingNotification
                                                object:nil];
}

+ (instancetype)sharedInstance {
  static FPRAppActivityTracker *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[self alloc] initAppActivityTracker];
  });
  return instance;
}

/**
 * Custom initializer to create an app activity tracker.
 */
- (instancetype)initAppActivityTracker {
  self = [super init];
  _applicationState = FPRApplicationStateUnknown;
  _appStartGaugeMetricDispatched = NO;
  _configurations = [FPRConfigurations sharedInstance];
  return self;
}

- (void)startAppActivityTracking {
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appDidBecomeActiveNotification:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:[UIApplication sharedApplication]];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appWillResignActiveNotification:)
                                               name:UIApplicationWillResignActiveNotification
                                             object:[UIApplication sharedApplication]];
}

- (FIRTrace *)activeTrace {
  if (self.foregroundSessionTrace) {
    return self.foregroundSessionTrace;
  }
  return self.backgroundSessionTrace;
}

/**
 * Checks if prewarming is available for the platform on current device.
 * It is available when running iOS 15 and above.
 *
 * @return true if the platform could prewarm apps on the current device
 */
+ (BOOL)isPrewarmAvailable {
  if (![[[GULAppEnvironmentUtil applePlatform] lowercaseString] isEqualToString:@"ios"]) {
    return NO;
  }
  NSString *systemVersion = [GULAppEnvironmentUtil systemVersion];
  if ([systemVersion length] == 0) {
    return NO;
  }
  return [systemVersion compare:@"15" options:NSNumericSearch] != NSOrderedAscending;
}

/**
 RC flag for dropping all app start events
 */
- (BOOL)isAppStartEnabled {
  return [self.configurations prewarmDetectionMode] != PrewarmDetectionModeKeepNone;
}

/**
 RC flag for enabling prewarm-detection using ActivePrewarm environment variable
 */
- (BOOL)isActivePrewarmEnabled {
  PrewarmDetectionMode mode = [self.configurations prewarmDetectionMode];
  return (mode == PrewarmDetectionModeActivePrewarm ||
          mode == PrewarmDetectionModeActivePrewarmOrDoubleDispatch);
}

/**
 RC flag for enabling prewarm-detection using double dispatch method
 */
- (BOOL)isDoubleDispatchEnabled {
  PrewarmDetectionMode mode = [self.configurations prewarmDetectionMode];
  return (mode == PrewarmDetectionModeDoubleDispatch ||
          mode == PrewarmDetectionModeActivePrewarmOrDoubleDispatch);
}

/**
 Checks if the current app start is a prewarmed app start
 */
- (BOOL)isApplicationPreWarmed {
  if (![FPRAppActivityTracker isPrewarmAvailable]) {
    return NO;
  }

  BOOL isPrewarmed = NO;

  NSDictionary<NSString *, NSString *> *environment = [NSProcessInfo processInfo].environment;
  BOOL activePrewarmFlagValue = [environment[@"ActivePrewarm"] boolValue];
  if (activePrewarmFlagValue == YES) {
    isPrewarmed = isPrewarmed || [self isActivePrewarmEnabled];
    [self.activeTrace incrementMetric:kFPRAppCounterNameActivePrewarm byInt:1];
  } else {
    [self.activeTrace incrementMetric:kFPRAppCounterNameActivePrewarm byInt:0];
  }

  if ([doubleDispatchTime compare:applicationDidFinishLaunchTime] == NSOrderedAscending) {
    isPrewarmed = isPrewarmed || [self isDoubleDispatchEnabled];
    [self.activeTrace incrementMetric:kFPRAppCounterNameDoubleDispatch byInt:1];
  } else if (doubleDispatchTime) {
    [self.activeTrace incrementMetric:kFPRAppCounterNameDoubleDispatch byInt:0];
  }

  return isPrewarmed;
}

/**
 * This gets called whenever the app becomes active. A new trace will be created to track the active
 * foreground session. Any background session trace that was running in the past will be stopped.
 *
 * @param notification Notification received during app launch.
 */
- (void)appDidBecomeActiveNotification:(NSNotification *)notification {
  self.applicationState = FPRApplicationStateForeground;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    self.appStartTrace = [[FIRTrace alloc] initInternalTraceWithName:kFPRAppStartTraceName];
    [self.appStartTrace startWithStartTime:appStartTime];
    [self.appStartTrace startStageNamed:kFPRAppStartStageNameTimeToUI startTime:appStartTime];

    // Start measuring time to first draw on the App start trace.
    [self.appStartTrace startStageNamed:kFPRAppStartStageNameTimeToFirstDraw];
  });

  // If ever the app start trace had it life in background stage, do not send the trace.
  if (self.appStartTrace.backgroundTraceState != FPRTraceStateForegroundOnly) {
    self.appStartTrace = nil;
  }

  // Stop the active background session trace.
  [self.backgroundSessionTrace stop];
  self.backgroundSessionTrace = nil;

  // Start foreground session trace.
  FIRTrace *appTrace =
      [[FIRTrace alloc] initInternalTraceWithName:kFPRAppTraceNameForegroundSession];
  [appTrace start];
  self.foregroundSessionTrace = appTrace;

  // Start measuring time to make the app interactive on the App start trace.
  static BOOL TTIStageStarted = NO;
  if (!TTIStageStarted) {
    [self.appStartTrace startStageNamed:kFPRAppStartStageNameTimeToUserInteraction];
    TTIStageStarted = YES;

    // Assumption here is that - the app becomes interactive in the next runloop cycle.
    // It is possible that the app does more things later, but for now we are not measuring that.
    dispatch_async(dispatch_get_main_queue(), ^{
      NSTimeInterval startTimeSinceEpoch = [self.appStartTrace startTimeSinceEpoch];
      NSTimeInterval currentTimeSinceEpoch = [[NSDate date] timeIntervalSince1970];

      // The below check is to account for 2 scenarios.
      // 1. The app gets started in the background and might come to foreground a lot later.
      // 2. The app is launched, but immediately backgrounded for some reason and the actual launch
      // happens a lot later.
      // Dropping the app start trace in such situations where the launch time is taking more than
      // 60 minutes. This is an approximation, but a more agreeable timelimit for app start.
      if ((currentTimeSinceEpoch - startTimeSinceEpoch < gAppStartMaxValidDuration) &&
          [self isAppStartEnabled] && ![self isApplicationPreWarmed]) {
        [self.appStartTrace stop];
      } else {
        [self.appStartTrace cancel];
      }
    });
  }

  // Let the session manager to start tracking app activity changes.
  [[FPRSessionManager sharedInstance] startTrackingAppStateChanges];
}

/**
 * This gets called whenever the app resigns its active status. The currently active foreground
 * session trace will be stopped and a background session trace will be started.
 *
 * @param notification Notification received during app resigning active status.
 */
- (void)appWillResignActiveNotification:(NSNotification *)notification {
  // Dispatch the collected gauge metrics.
  if (!self.appStartGaugeMetricDispatched) {
    [[FPRGaugeManager sharedInstance] dispatchMetric:gAppStartCPUGaugeData];
    [[FPRGaugeManager sharedInstance] dispatchMetric:gAppStartMemoryGaugeData];
    self.appStartGaugeMetricDispatched = YES;
  }

  self.applicationState = FPRApplicationStateBackground;

  // Stop foreground session trace.
  [self.foregroundSessionTrace stop];
  self.foregroundSessionTrace = nil;

  // Start background session trace.
  self.backgroundSessionTrace =
      [[FIRTrace alloc] initInternalTraceWithName:kFPRAppTraceNameBackgroundSession];
  [self.backgroundSessionTrace start];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:UIApplicationDidBecomeActiveNotification
                                                object:[UIApplication sharedApplication]];

  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:UIApplicationWillResignActiveNotification
                                                object:[UIApplication sharedApplication]];
}

@end
