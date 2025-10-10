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
#import <Network/Network.h>
#import <UIKit/UIKit.h>

#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Gauges/CPU/FPRCPUGaugeCollector+Private.h"
#import "FirebasePerformance/Sources/Gauges/FPRGaugeManager.h"
#import "FirebasePerformance/Sources/Gauges/Memory/FPRMemoryGaugeCollector+Private.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Private.h"

static NSDate *appStartTime = nil;
static NSDate *doubleDispatchTime = nil;
static NSDate *applicationDidFinishLaunchTime = nil;
static NSTimeInterval gAppStartMaxValidDuration = 60 * 60;  // 60 minutes.
static NSTimeInterval gAppStartReasonableValidDuration = 30.0;  // 30 seconds, reasonable app start time???
static FPRCPUGaugeData *gAppStartCPUGaugeData = nil;
static FPRMemoryGaugeData *gAppStartMemoryGaugeData = nil;
static BOOL isActivePrewarm = NO;

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

@interface FPRAppActivityTracker ()

/** The foreground session trace. Will be set only when the app is in the foreground. */
@property(nonatomic, readwrite) FIRTrace *foregroundSessionTrace;

/** The background session trace. Will be set only when the app is in the background. */
@property(nonatomic, readwrite) FIRTrace *backgroundSessionTrace;

/** Current running state of the application. */
@property(nonatomic, readwrite) FPRApplicationState applicationState;

/** Current network connection type of the application. */
@property(nonatomic, readwrite) firebase_perf_v1_NetworkConnectionInfo_NetworkType networkType;

/** Network monitor object to track network movements. */
@property(nonatomic, readwrite) nw_path_monitor_t monitor;

/** Queue used to track the network monitoring changes. */
@property(nonatomic, readwrite) dispatch_queue_t monitorQueue;

/** Trace to measure the app start performance. */
@property(nonatomic) FIRTrace *appStartTrace;

/** Tracks if the gauge metrics are dispatched. */
@property(nonatomic) BOOL appStartGaugeMetricDispatched;

/** Tracks if TTI stage has been started for this instance. */
@property(nonatomic) BOOL ttiStageStarted;

/** Firebase Performance Configuration object */
@property(nonatomic) FPRConfigurations *configurations;

/** Starts tracking app active sessions. */
- (void)startAppActivityTracking;

@end

@implementation FPRAppActivityTracker

+ (void)load {
  // This is an approximation of the app start time.
  appStartTime = [NSDate date];

  // When an app is prewarmed, Apple sets env variable ActivePrewarm to 1, then the env variable is
  // deleted after didFinishLaunching
  isActivePrewarm = [NSProcessInfo.processInfo.environment[@"ActivePrewarm"] isEqualToString:@"1"];

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
  if (self != nil) {
    _applicationState = FPRApplicationStateUnknown;
    _appStartGaugeMetricDispatched = NO;
    _ttiStageStarted = NO;
    _configurations = [FPRConfigurations sharedInstance];
    [self startTrackingNetwork];
  }
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

- (void)startTrackingNetwork {
  self.networkType = firebase_perf_v1_NetworkConnectionInfo_NetworkType_NONE;

  dispatch_queue_attr_t attrs = dispatch_queue_attr_make_with_qos_class(
      DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, DISPATCH_QUEUE_PRIORITY_DEFAULT);
  self.monitorQueue = dispatch_queue_create("com.google.firebase.perf.network.monitor", attrs);

  self.monitor = nw_path_monitor_create();
  nw_path_monitor_set_queue(self.monitor, self.monitorQueue);
  __weak FPRAppActivityTracker *weakSelf = self;
  nw_path_monitor_set_update_handler(self.monitor, ^(nw_path_t _Nonnull path) {
    BOOL isWiFi = nw_path_uses_interface_type(path, nw_interface_type_wifi);
    BOOL isCellular = nw_path_uses_interface_type(path, nw_interface_type_cellular);
    BOOL isEthernet = nw_path_uses_interface_type(path, nw_interface_type_wired);

    if (isWiFi) {
      weakSelf.networkType = firebase_perf_v1_NetworkConnectionInfo_NetworkType_WIFI;
    } else if (isCellular) {
      weakSelf.networkType = firebase_perf_v1_NetworkConnectionInfo_NetworkType_MOBILE;
    } else if (isEthernet) {
      weakSelf.networkType = firebase_perf_v1_NetworkConnectionInfo_NetworkType_ETHERNET;
    }
  });

  nw_path_monitor_start(self.monitor);
}

/**
 * Checks if the prewarming feature is available on the current device.
 *
 * @return true if the OS could prewarm apps on the current device
 */
- (BOOL)isPrewarmAvailable {
  return YES;
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
  return (mode == PrewarmDetectionModeActivePrewarm);
}

/**
 Checks if the current app start is a prewarmed app start
 */
- (BOOL)isApplicationPreWarmed {
  if (![self isPrewarmAvailable]) {
    return NO;
  }

  BOOL isPrewarmed = NO;

  if (isActivePrewarm == YES) {
    isPrewarmed = isPrewarmed || [self isActivePrewarmEnabled];
    [self.activeTrace incrementMetric:kFPRAppCounterNameActivePrewarm byInt:1];
  } else {
    [self.activeTrace incrementMetric:kFPRAppCounterNameActivePrewarm byInt:0];
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

  // If ever the app start trace had its life in background stage, do not send the trace.
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
  if (!self.ttiStageStarted) {
    [self.appStartTrace startStageNamed:kFPRAppStartStageNameTimeToUserInteraction];
    self.ttiStageStarted = YES;

    // Use dispatch_async with a higher priority queue to reduce interference from network
    // operations This ensures trace completion isn't delayed by main queue congestion from network
    // calls
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.appStartTrace) {
          return;
        }

        NSTimeInterval startTimeSinceEpoch = [strongSelf.appStartTrace startTimeSinceEpoch];
        NSTimeInterval currentTimeSinceEpoch = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval elapsed = currentTimeSinceEpoch - startTimeSinceEpoch;

        // The below check accounts for multiple scenarios:
        // 1. App started in background and comes to foreground later
        // 2. App launched but immediately backgrounded
        // 3. Network delays during startup inflating metrics
        BOOL shouldCompleteTrace = (elapsed < gAppStartMaxValidDuration) &&
                                   [strongSelf isAppStartEnabled] &&
                                   ![strongSelf isApplicationPreWarmed];

        // Additional safety: cancel if elapsed time is unreasonably long for app start
        if (shouldCompleteTrace && elapsed < gAppStartReasonableValidDuration) {
          [strongSelf.appStartTrace stop];
        } else {
          [strongSelf.appStartTrace cancel];
          if (elapsed >= gAppStartReasonableValidDuration) {
            // Log for debugging network related delays
            NSLog(
                @"Firebase Performance: App start trace cancelled due to excessive duration: %.2fs",
                elapsed);
          }
        }
      });
    });
  }
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
  nw_path_monitor_cancel(self.monitor);

  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:UIApplicationDidBecomeActiveNotification
                                                object:[UIApplication sharedApplication]];

  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:UIApplicationWillResignActiveNotification
                                                object:[UIApplication sharedApplication]];
}

@end
