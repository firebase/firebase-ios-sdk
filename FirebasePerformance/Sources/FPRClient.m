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
#import "FirebasePerformance/Sources/AppActivity/FPRScreenTraceTracker+Private.h"
#import "FirebasePerformance/Sources/AppActivity/FPRScreenTraceTracker.h"
#import "FirebasePerformance/Sources/AppActivity/FPRSessionManager+Private.h"
#import "FirebasePerformance/Sources/AppActivity/FPRTraceBackgroundActivityTracker.h"
#import "FirebasePerformance/Sources/Common/FPRConsoleURLGenerator.h"
#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags.h"
#import "FirebasePerformance/Sources/FPRConsoleLogger.h"
#import "FirebasePerformance/Sources/FPRNanoPbUtils.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRInstrumentation.h"
#import "FirebasePerformance/Sources/Loggers/FPRGDTLogger.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Internal.h"
#import "FirebasePerformance/Sources/Timer/FIRTrace+Private.h"

#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

@import FirebaseSessions;

@interface FPRClient () <FIRLibrary, FIRPerformanceProvider, FIRSessionsSubscriber>

/** The original configuration object used to initialize the client. */
@property(nonatomic, strong) FPRConfiguration *config;

/** The object that manages all automatic class instrumentation. */
@property(nonatomic) FPRInstrumentation *instrumentation;

@end

@implementation FPRClient

+ (void)load {
  [FIRApp registerInternalLibrary:[FPRClient class]
                         withName:@"fire-perf"
                      withVersion:[NSString stringWithUTF8String:kFPRSDKVersion]];
  [FIRSessionsDependencies addDependencyWithName:FIRSessionsSubscriberNamePerformance];
}

#pragma mark - Component registration system

+ (nonnull NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    if (!container.app.isDefaultApp) {
      return nil;
    }

    id<FIRSessionsProvider> sessions = FIR_COMPONENT(FIRSessionsProvider, container);

    NSString *appName = container.app.name;
    FIRApp *app = [FIRApp appNamed:appName];
    FIROptions *options = app.options;
    NSError *error = nil;

    // Based on the environment variable SDK decides if events are dispatched to Autopush or Prod.
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

    if (sessions) {
      FPRLogDebug(kFPRClientInitialize, @"Registering Sessions SDK subscription for session data");

      // Subscription should be made after the first call to [FPRClient sharedInstance] where
      // _configuration is initialized so that the sessions SDK can immediately get the data
      // collection state.
      [sessions registerWithSubscriber:[self sharedInstance]];
    }

    *isCacheable = YES;

    return [self sharedInstance];
  };

  FIRComponent *component =
      [FIRComponent componentWithProtocol:@protocol(FIRPerformanceProvider)
                      instantiationTiming:FIRInstantiationTimingEagerInDefaultApp
                            creationBlock:creationBlock];

  return @[ component ];
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
    _projectID = [FIROptions defaultOptions].projectID;
    _bundleID = [FIROptions defaultOptions].bundleID;
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

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    FPRLogInfo(kFPRClientInitialize,
               @"Firebase Performance Monitoring is successfully initialized! In a minute, visit "
               @"the Firebase console to view your data: %@",
               [FPRConsoleURLGenerator generateDashboardURLWithProjectID:self.projectID
                                                                bundleID:self.bundleID]);
  });

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
      firebase_perf_v1_PerfMetric metric = FPRGetPerfMetricMessage(self.config.appID);
      FPRSetTraceMetric(&metric, FPRGetTraceMetric(trace));
      FPRSetApplicationProcessState(&metric,
                                    FPRApplicationProcessState(trace.backgroundTraceState));

      // Log the trace metric with its console URL.
      if ([trace.name hasPrefix:kFPRPrefixForScreenTraceName]) {
        FPRLogInfo(kFPRClientMetricLogged,
                   @"Logging trace metric - %@ %.4fms. In a minute, visit the Firebase console to "
                   @"view your data: %@",
                   trace.name, metric.trace_metric.duration_us / 1000.0,
                   [FPRConsoleURLGenerator generateScreenTraceURLWithProjectID:self.projectID
                                                                      bundleID:self.bundleID
                                                                     traceName:trace.name]);
      } else {
        FPRLogInfo(kFPRClientMetricLogged,
                   @"Logging trace metric - %@ %.4fms. In a minute, visit the Firebase console to "
                   @"view your data: %@",
                   trace.name, metric.trace_metric.duration_us / 1000.0,
                   [FPRConsoleURLGenerator generateCustomTraceURLWithProjectID:self.projectID
                                                                      bundleID:self.bundleID
                                                                     traceName:trace.name]);
      }
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
    if ([trace isValid]) {
      firebase_perf_v1_NetworkRequestMetric networkRequestMetric =
          FPRGetNetworkRequestMetric(trace);
      int64_t duration = networkRequestMetric.has_time_to_response_completed_us
                             ? networkRequestMetric.time_to_response_completed_us
                             : 0;

      NSString *responseCode = networkRequestMetric.has_http_response_code
                                   ? [@(networkRequestMetric.http_response_code) stringValue]
                                   : @"UNKNOWN";
      FPRLogInfo(kFPRClientMetricLogged,
                 @"Logging network request trace - %@, Response code: %@, %.4fms",
                 trace.trimmedURLString, responseCode, duration / 1000.0);
      firebase_perf_v1_PerfMetric metric = FPRGetPerfMetricMessage(self.config.appID);
      FPRSetNetworkRequestMetric(&metric, networkRequestMetric);
      FPRSetApplicationProcessState(&metric,
                                    FPRApplicationProcessState(trace.backgroundTraceState));

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
    firebase_perf_v1_PerfMetric metric = FPRGetPerfMetricMessage(self.config.appID);
    firebase_perf_v1_GaugeMetric gaugeMetric = firebase_perf_v1_GaugeMetric_init_default;
    if ((gaugeData != nil && gaugeData.count != 0) && (sessionId != nil && sessionId.length != 0)) {
      gaugeMetric = FPRGetGaugeMetric(gaugeData, sessionId);
    }
    FPRSetGaugeMetric(&metric, gaugeMetric);
    [self processAndLogEvent:metric];
  });

  // Check and update the sessionID if the session is running for too long.
  [[FPRSessionManager sharedInstance] stopGaugesIfRunningTooLong];
}

- (void)processAndLogEvent:(firebase_perf_v1_PerfMetric)event {
  BOOL tracingEnabled = self.configuration.isDataCollectionEnabled;
  if (!tracingEnabled) {
    FPRLogDebug(kFPRClientPerfNotConfigured, @"Dropping event since data collection is disabled.");
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
            firebase_perf_v1_PerfMetric updatedEvent = event;
            updatedEvent.application_info.app_instance_id = FPREncodeString(identifier);
            [self.gdtLogger logEvent:updatedEvent];
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

#pragma mark - FIRSessionsSubscriber

- (void)onSessionChanged:(FIRSessionDetails *_Nonnull)session {
  [[FPRSessionManager sharedInstance] updateSessionId:session.sessionId];
}

- (BOOL)isDataCollectionEnabled {
  return self.configuration.isDataCollectionEnabled;
}

- (FIRSessionsSubscriberName)sessionsSubscriberName {
  return FIRSessionsSubscriberNamePerformance;
}

@end
