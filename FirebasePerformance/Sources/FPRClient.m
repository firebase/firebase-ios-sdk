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

#import "FirebasePerformance/Sources/FPRClient.h"
#import "FirebasePerformance/Sources/FPRClient+Private.h"

#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FirebasePerformance/Sources/AppActivity/FPRScreenTraceTracker.h"
#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager+Private.h"
#import "FirebasePerformance/Sources/AppActivity/FPRTraceBackgroundActivityTracker.h"
#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags.h"
#import "FirebasePerformance/Sources/FPRConsoleLogger.h"
#import "FirebasePerformance/Sources/FPRProtoUtils.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRInstrumentation.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTLogger.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Private.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebasePerformance/ProtoSupport/PerfMetric.pbobjc.h"

@interface FPRClient ()

/** The original configuration object used to initialize the client. */
@property(nonatomic, strong) FPRConfiguration *config;

/** The object that manages all automatic class instrumentation. */
@property(nonatomic) FPRInstrumentation *instrumentation;

@end

@implementation FPRClient

+ (void)load {
  __weak NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  __block id listener;

  void (^observerBlock)(NSNotification *) = ^(NSNotification *aNotification) {
    NSDictionary *appInfoDict = aNotification.userInfo;
    NSNumber *isDefaultApp = appInfoDict[kFIRAppIsDefaultAppKey];
    if (![isDefaultApp boolValue]) {
      return;
    }

    NSString *appName = appInfoDict[kFIRAppNameKey];
    FIRApp *app = [FIRApp appNamed:appName];
    FIROptions *options = app.options;
    NSError *error = nil;

    // Based on the environment variable SDK decides if events are dispatchd to Autopush or Prod.
    // By default, events are sent to Prod.
    BOOL useAutoPush = NO;
    NSDictionary<NSString *, NSString *> *environment = [NSProcessInfo processInfo].environment;
    if (environment[@"FPR_AUTOPUSH_ENV"] != nil &&
        [environment[@"FPR_AUTOPUSH_ENV"] isEqualToString:@"1"]) {
      useAutoPush = YES;
    }

    FPRConfiguration *configuration = [FPRConfiguration configurationWithAppID:options.googleAppID
                                                                        APIKey:options.APIKey
                                                                      autoPush:useAutoPush];
    if (![[self sharedInstance] startWithConfiguration:configuration error:&error]) {
      FPRLogError(kFPRClientInitialize, @"Failed to initialize the client with error:  %@.", error);
    }

    [notificationCenter removeObserver:listener];
    listener = nil;
  };

  // Register the Perf library for Firebase Core tracking.
  [FIRApp registerLibrary:@"fire-perf"  // From go/firebase-sdk-platform-info
              withVersion:[NSString stringWithUTF8String:kFPRSDKVersion]];
  listener = [notificationCenter addObserverForName:kFIRAppReadyToConfigureSDKNotification
                                             object:[FIRApp class]
                                              queue:nil
                                         usingBlock:observerBlock];
}

+ (FPRClient *)sharedInstance {
  static FPRClient *sharedInstance = nil;
  static dispatch_once_t token;
  dispatch_once(&token, ^{
    sharedInstance = [[FPRClient alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _instrumentation = [[FPRInstrumentation alloc] init];
    _swizzled = NO;
    _eventsQueue = dispatch_queue_create("com.google.perf.FPREventsQueue", DISPATCH_QUEUE_SERIAL);
    _eventsQueueGroup = dispatch_group_create();
    _configuration = [FPRConfigurations sharedInstance];
  }
  return self;
}

- (BOOL)startWithConfiguration:(FPRConfiguration *)config error:(NSError *__autoreleasing *)error {
  self.config = config;
  NSInteger logSource = [self.configuration logSource];

  dispatch_group_async(self.eventsQueueGroup, self.eventsQueue, ^{
    // Create the Logger for the Perf SDK events to be sent to Google Data Transport.
    self.gdtLogger = [[FPRGDTLogger alloc] initWithLogSource:logSource];

#ifdef TARGET_HAS_MOBILE_CONNECTIVITY
    // Create telephony network information object ahead of time to avoid runtime delays.
    FPRNetworkInfo();
#endif

    // Update the configuration flags.
    [self.configuration update];

    [FPRClient cleanupClearcutCacheDirectory];
  });

  // Set up instrumentation.
  [self checkAndStartInstrumentation];

  self.configured = YES;

  return YES;
}

- (void)checkAndStartInstrumentation {
  BOOL instrumentationEnabled = self.configuration.isInstrumentationEnabled;
  if (instrumentationEnabled && !self.isSwizzled) {
    [self.instrumentation registerInstrumentGroup:kFPRInstrumentationGroupNetworkKey];
    [self.instrumentation registerInstrumentGroup:kFPRInstrumentationGroupUIKitKey];
    self.swizzled = YES;
  }
}

#pragma mark - Public methods

- (void)logTrace:(FIRTrace *)trace {
  if (self.configured == NO) {
    FPRLogError(kFPRClientPerfNotConfigured, @"Dropping trace event %@. Perf SDK not configured.",
                trace.name);
    return;
  }
  if ([trace isCompleteAndValid]) {
    dispatch_group_async(self.eventsQueueGroup, self.eventsQueue, ^{
      FPRMSGPerfMetric *metric = FPRGetPerfMetricMessage(self.config.appID);
      metric.traceMetric = FPRGetTraceMetric(trace);
      metric.applicationInfo.applicationProcessState =
          FPRApplicationProcessState(trace.backgroundTraceState);
      FPRLogDebug(kFPRClientMetricLogged, @"Logging trace metric - %@ %.4fms",
                  metric.traceMetric.name, metric.traceMetric.durationUs / 1000.0);
      [self processAndLogEvent:metric];
    });
  } else {
    FPRLogWarning(kFPRClientInvalidTrace, @"Invalid trace, skipping send.");
  }
}

- (void)logNetworkTrace:(nonnull FPRNetworkTrace *)trace {
  if (self.configured == NO) {
    FPRLogError(kFPRClientPerfNotConfigured, @"Dropping trace event %@. Perf SDK not configured.",
                trace.URLRequest.URL.absoluteString);
    return;
  }
  dispatch_group_async(self.eventsQueueGroup, self.eventsQueue, ^{
    FPRMSGNetworkRequestMetric *networkRequestMetric = FPRGetNetworkRequestMetric(trace);
    if (networkRequestMetric) {
      int64_t duration = networkRequestMetric.hasTimeToResponseCompletedUs
                             ? networkRequestMetric.timeToResponseCompletedUs
                             : 0;

      NSString *responseCode = networkRequestMetric.hasHTTPResponseCode
                                   ? [@(networkRequestMetric.HTTPResponseCode) stringValue]
                                   : @"UNKNOWN";
      FPRLogDebug(kFPRClientMetricLogged,
                  @"Logging network request trace - %@, Response code: %@, %.4fms",
                  networkRequestMetric.URL, responseCode, duration / 1000.0);
      FPRMSGPerfMetric *metric = FPRGetPerfMetricMessage(self.config.appID);
      metric.networkRequestMetric = networkRequestMetric;
      metric.applicationInfo.applicationProcessState =
          FPRApplicationProcessState(trace.backgroundTraceState);
      [self processAndLogEvent:metric];
    }
  });
}

- (void)logGaugeMetric:(nonnull NSArray *)gaugeData forSessionId:(nonnull NSString *)sessionId {
  if (self.configured == NO) {
    FPRLogError(kFPRClientPerfNotConfigured, @"Dropping session event. Perf SDK not configured.");
    return;
  }
  dispatch_group_async(self.eventsQueueGroup, self.eventsQueue, ^{
    FPRMSGPerfMetric *metric = FPRGetPerfMetricMessage(self.config.appID);
    FPRMSGGaugeMetric *gaugeMetric = FPRGetGaugeMetric(gaugeData, sessionId);
    metric.gaugeMetric = gaugeMetric;
    [self processAndLogEvent:metric];
  });

  // Check and update the sessionID if the session is running for too long.
  [[FPRSessionManager sharedInstance] renewSessionIdIfRunningTooLong];
}

- (void)processAndLogEvent:(FPRMSGPerfMetric *)event {
  BOOL tracingEnabled = self.configuration.isDataCollectionEnabled;
  if (!tracingEnabled) {
    FPRLogError(kFPRClientPerfNotConfigured, @"Dropping event since data collection is disabled.");
    return;
  }

  BOOL sdkEnabled = [self.configuration sdkEnabled];
  if (!sdkEnabled) {
    FPRLogInfo(kFPRClientSDKDisabled, @"Dropping event since Performance SDK is disabled.");
    return;
  }

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if (self.installations == nil) {
      // Delayed initialization of installations because FIRApp needs to be configured first.
      self.installations = [FIRInstallations installations];
    }
  });

  // Attempts to dispatch events if successfully retrieve installation ID.
  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
        if (error) {
          FPRLogError(kFPRClientInstanceIDNotAvailable, @"FIRInstallations error: %@",
                      error.description);
        } else {
          dispatch_group_async(self.eventsQueueGroup, self.eventsQueue, ^{
            event.applicationInfo.appInstanceId = identifier;
            [self.gdtLogger logEvent:event];
          });
        }
      }];
}

#pragma mark - Clearcut log directory removal methods

+ (void)cleanupClearcutCacheDirectory {
  NSString *logDirectoryPath = [FPRClient logDirectoryPath];

  if (logDirectoryPath != nil) {
    BOOL logDirectoryExists = [[NSFileManager defaultManager] fileExistsAtPath:logDirectoryPath];

    if (logDirectoryExists) {
      NSError *directoryError = nil;
      [[NSFileManager defaultManager] removeItemAtPath:logDirectoryPath error:&directoryError];

      if (directoryError) {
        FPRLogDebug(kFPRClientTempDirectory,
                    @"Failed to delete the stale log directory at path: %@ with error: %@.",
                    logDirectoryPath, directoryError);
      }
    }
  }
}

+ (NSString *)logDirectoryPath {
  static NSString *cacheDir;
  static NSString *fireperfCacheDir;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    cacheDir =
        [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];

    if (!cacheDir) {
      fireperfCacheDir = nil;
    } else {
      fireperfCacheDir = [cacheDir stringByAppendingPathComponent:@"firebase_perf_logging"];
    }
  });

  return fireperfCacheDir;
}

#pragma mark - Unswizzling, use only for unit tests

- (void)disableInstrumentation {
  [self.instrumentation deregisterInstrumentGroup:kFPRInstrumentationGroupNetworkKey];
  [self.instrumentation deregisterInstrumentGroup:kFPRInstrumentationGroupUIKitKey];
  self.swizzled = NO;
  [self.configuration setInstrumentationEnabled:NO];
}

@end
