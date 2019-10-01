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

#import <FirebaseCore/FIRLogger.h>

#import "FIRCore+InAppMessaging.h"
#import "FIRIAMActivityLogger.h"
#import "FIRIAMAnalyticsEventLoggerImpl.h"
#import "FIRIAMBookKeeper.h"
#import "FIRIAMClearcutHttpRequestSender.h"
#import "FIRIAMClearcutLogStorage.h"
#import "FIRIAMClearcutLogger.h"
#import "FIRIAMClearcutUploader.h"
#import "FIRIAMClientInfoFetcher.h"
#import "FIRIAMDisplayCheckOnAnalyticEventsFlow.h"
#import "FIRIAMDisplayCheckOnAppForegroundFlow.h"
#import "FIRIAMDisplayCheckOnFetchDoneNotificationFlow.h"
#import "FIRIAMDisplayExecutor.h"
#import "FIRIAMFetchOnAppForegroundFlow.h"
#import "FIRIAMFetchResponseParser.h"
#import "FIRIAMMessageClientCache.h"
#import "FIRIAMMsgFetcherUsingRestful.h"
#import "FIRIAMRuntimeManager.h"
#import "FIRIAMSDKModeManager.h"
#import "FIRInAppMessaging.h"

@interface FIRInAppMessaging ()
@property(nonatomic, readwrite, strong) id<FIRAnalyticsInterop> _Nullable analytics;
@end

// A enum indicating 3 different possiblities of a setting about auto data collection.
typedef NS_ENUM(NSInteger, FIRIAMAutoDataCollectionSetting) {
  // This indicates that the config is not explicitly set.
  FIRIAMAutoDataCollectionSettingNone = 0,

  // This indicates that the setting explicitly enables the auto data collection.
  FIRIAMAutoDataCollectionSettingEnabled = 1,

  // This indicates that the setting explicitly disables the auto data collection.
  FIRIAMAutoDataCollectionSettingDisabled = 2,
};

@interface FIRIAMRuntimeManager () <FIRIAMTestingModeListener>
@property(nonatomic, nonnull) FIRIAMMsgFetcherUsingRestful *restfulFetcher;
@property(nonatomic, nonnull) FIRIAMDisplayCheckOnAppForegroundFlow *displayOnAppForegroundFlow;
@property(nonatomic, nonnull) FIRIAMDisplayCheckOnFetchDoneNotificationFlow *displayOnFetchDoneFlow;
@property(nonatomic, nonnull)
    FIRIAMDisplayCheckOnAnalyticEventsFlow *displayOnFIRAnalyticEventsFlow;

@property(nonatomic, nonnull) FIRIAMFetchOnAppForegroundFlow *fetchOnAppForegroundFlow;
@property(nonatomic, nonnull) FIRIAMClientInfoFetcher *clientInfoFetcher;
@property(nonatomic, nonnull) FIRIAMFetchResponseParser *responseParser;
@end

static NSString *const _userDefaultsKeyForFIAMProgammaticAutoDataCollectionSetting =
    @"firebase-iam-sdk-auto-data-collection";

@implementation FIRIAMRuntimeManager {
  // since we allow the SDK feature to be disabled/enabled at runtime, we need a field to track
  // its state on this
  BOOL _running;
}
+ (FIRIAMRuntimeManager *)getSDKRuntimeInstance {
  static FIRIAMRuntimeManager *managerInstance = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    managerInstance = [[FIRIAMRuntimeManager alloc] init];
  });

  return managerInstance;
}

// For protocol FIRIAMTestingModeListener.
- (void)testingModeSwitchedOn {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180015",
              @"Dynamically switch to the display flow for testing mode instance.");

  [self.displayOnAppForegroundFlow stop];
  [self.displayOnFetchDoneFlow start];
}

- (FIRIAMAutoDataCollectionSetting)FIAMProgrammaticAutoDataCollectionSetting {
  id settingEntry = [[NSUserDefaults standardUserDefaults]
      objectForKey:_userDefaultsKeyForFIAMProgammaticAutoDataCollectionSetting];

  if (![settingEntry isKindOfClass:[NSNumber class]]) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180014",
                @"No auto data collection enable setting entry detected."
                 "So no FIAM programmatic setting from the app.");
    return FIRIAMAutoDataCollectionSettingNone;
  } else {
    if ([(NSNumber *)settingEntry boolValue]) {
      return FIRIAMAutoDataCollectionSettingEnabled;
    } else {
      return FIRIAMAutoDataCollectionSettingDisabled;
    }
  }
}

// the key for the plist entry to suppress auto start
static NSString *const kFirebaseInAppMessagingAutoDataCollectionKey =
    @"FirebaseInAppMessagingAutomaticDataCollectionEnabled";

- (FIRIAMAutoDataCollectionSetting)FIAMPlistAutoDataCollectionSetting {
  id fiamAutoDataCollectionPlistEntry = [[NSBundle mainBundle]
      objectForInfoDictionaryKey:kFirebaseInAppMessagingAutoDataCollectionKey];

  if ([fiamAutoDataCollectionPlistEntry isKindOfClass:[NSNumber class]]) {
    BOOL fiamDataCollectionEnabledPlistSetting =
        [(NSNumber *)fiamAutoDataCollectionPlistEntry boolValue];

    if (fiamDataCollectionEnabledPlistSetting) {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180011",
                  @"Auto data collection is explicitly enabled in FIAM plist entry.");
      return FIRIAMAutoDataCollectionSettingEnabled;
    } else {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180012",
                  @"Auto data collection is explicitly disabled in FIAM plist entry.");
      return FIRIAMAutoDataCollectionSettingDisabled;
    }
  } else {
    return FIRIAMAutoDataCollectionSettingNone;
  }
}

// Whether data collection is enabled by FIAM programmatic flag.
- (BOOL)automaticDataCollectionEnabled {
  return
      [self FIAMProgrammaticAutoDataCollectionSetting] != FIRIAMAutoDataCollectionSettingDisabled;
}

// Sets FIAM's programmatic flag for auto data collection.
- (void)setAutomaticDataCollectionEnabled:(BOOL)automaticDataCollectionEnabled {
  if (automaticDataCollectionEnabled) {
    [self resume];
  } else {
    [self pause];
  }
}

- (BOOL)shouldRunSDKFlowsOnStartup {
  // This can be controlled at 3 different levels in decsending priority. If a higher-priority
  // setting exists, the lower level settings are ignored.
  //   1. Setting made by the app by setting FIAM SDK's automaticDataCollectionEnabled flag.
  //   2. FIAM specific data collection setting in plist file.
  //   3. Global Firebase auto data collecting setting (carried over by currentSetting property).

  FIRIAMAutoDataCollectionSetting programmaticSetting =
      [self FIAMProgrammaticAutoDataCollectionSetting];

  if (programmaticSetting == FIRIAMAutoDataCollectionSettingEnabled) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180010",
                @"FIAM auto data-collection is explicitly enabled, start SDK flows.");
    return true;
  } else if (programmaticSetting == FIRIAMAutoDataCollectionSettingDisabled) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180013",
                @"FIAM auto data-collection is explicitly disabled, do not start SDK flows.");
    return false;
  } else {
    // No explicit setting from fiam's programmatic setting. Checking next level down.
    FIRIAMAutoDataCollectionSetting fiamPlistDataCollectionSetting =
        [self FIAMPlistAutoDataCollectionSetting];

    if (fiamPlistDataCollectionSetting == FIRIAMAutoDataCollectionSettingNone) {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180018",
                  @"No programmatic or plist setting at FIAM level. Fallback to global Firebase "
                   "level setting.");
      return self.currentSetting.isFirebaseAutoDataCollectionEnabled;
    } else {
      return fiamPlistDataCollectionSetting == FIRIAMAutoDataCollectionSettingEnabled;
    }
  }
}

- (void)resume {
  // persist the setting
  [[NSUserDefaults standardUserDefaults]
      setObject:@(YES)
         forKey:_userDefaultsKeyForFIAMProgammaticAutoDataCollectionSetting];

  @synchronized(self) {
    if (!_running) {
      [self.fetchOnAppForegroundFlow start];
      [self.displayOnAppForegroundFlow start];
      [self.displayOnFIRAnalyticEventsFlow start];
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180019",
                  @"Start Firebase In-App Messaging flows from inactive.");
      _running = YES;
    } else {
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM180004",
                    @"Runtime is already active, resume is just a no-op");
    }
  }
}

- (void)pause {
  // persist the setting
  [[NSUserDefaults standardUserDefaults]
      setObject:@(NO)
         forKey:_userDefaultsKeyForFIAMProgammaticAutoDataCollectionSetting];

  @synchronized(self) {
    if (_running) {
      [self.fetchOnAppForegroundFlow stop];
      [self.displayOnAppForegroundFlow stop];
      [self.displayOnFIRAnalyticEventsFlow stop];
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180006",
                  @"Shutdown Firebase In-App Messaging flows.");
      _running = NO;
    } else {
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM180005",
                    @"No runtime active yet, pause is just a no-op");
    }
  }
}

- (void)setShouldSuppressMessageDisplay:(BOOL)shouldSuppress {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180003", @"Message display suppress set to %@",
              @(shouldSuppress));
  self.displayExecutor.suppressMessageDisplay = shouldSuppress;
}

- (void)startRuntimeWithSDKSettings:(FIRIAMSDKSettings *)settings {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
    [self internalStartRuntimeWithSDKSettings:settings];
  });
}

- (void)internalStartRuntimeWithSDKSettings:(FIRIAMSDKSettings *)settings {
  if (_running) {
    // Runtime has been started previously. Stop all the flows first.
    [self.fetchOnAppForegroundFlow stop];
    [self.displayOnAppForegroundFlow stop];
    [self.displayOnFIRAnalyticEventsFlow stop];
  }

  self.currentSetting = settings;

  FIRIAMTimerWithNSDate *timeFetcher = [[FIRIAMTimerWithNSDate alloc] init];
  NSTimeInterval start = [timeFetcher currentTimestampInSeconds];

  self.activityLogger =
      [[FIRIAMActivityLogger alloc] initWithMaxCountBeforeReduce:settings.loggerMaxCountBeforeReduce
                                             withSizeAfterReduce:settings.loggerSizeAfterReduce
                                                     verboseMode:settings.loggerInVerboseMode
                                                   loadFromCache:YES];

  self.responseParser = [[FIRIAMFetchResponseParser alloc] initWithTimeFetcher:timeFetcher];

  self.bookKeeper = [[FIRIAMBookKeeperViaUserDefaults alloc]
      initWithUserDefaults:[NSUserDefaults standardUserDefaults]];

  self.messageCache = [[FIRIAMMessageClientCache alloc] initWithBookkeeper:self.bookKeeper
                                                       usingResponseParser:self.responseParser];
  self.fetchResultStorage = [[FIRIAMServerMsgFetchStorage alloc] init];
  self.clientInfoFetcher = [[FIRIAMClientInfoFetcher alloc] init];

  self.restfulFetcher =
      [[FIRIAMMsgFetcherUsingRestful alloc] initWithHost:settings.apiServerHost
                                            HTTPProtocol:settings.apiHttpProtocol
                                                 project:settings.firebaseProjectNumber
                                             firebaseApp:settings.firebaseAppId
                                                  APIKey:settings.apiKey
                                            fetchStorage:self.fetchResultStorage
                                       instanceIDFetcher:self.clientInfoFetcher
                                         usingURLSession:nil
                                          responseParser:self.responseParser];

  // start fetch on app foreground flow
  FIRIAMFetchSetting *fetchSetting = [[FIRIAMFetchSetting alloc] init];
  fetchSetting.fetchMinIntervalInMinutes = settings.fetchMinIntervalInMinutes;

  // start render on app foreground flow
  FIRIAMDisplaySetting *appForegroundDisplaysetting = [[FIRIAMDisplaySetting alloc] init];
  appForegroundDisplaysetting.displayMinIntervalInMinutes =
      settings.appFGRenderMinIntervalInMinutes;

  // clearcut log expires after 14 days: give up on attempting to deliver them any more
  NSInteger ctLogExpiresInSeconds = 14 * 24 * 60 * 60;

  FIRIAMClearcutLogStorage *ctLogStorage =
      [[FIRIAMClearcutLogStorage alloc] initWithExpireAfterInSeconds:ctLogExpiresInSeconds
                                                     withTimeFetcher:timeFetcher];

  FIRIAMClearcutHttpRequestSender *clearcutRequestSender = [[FIRIAMClearcutHttpRequestSender alloc]
      initWithClearcutHost:settings.clearcutServerHost
          usingTimeFetcher:timeFetcher
        withOSMajorVersion:[self.clientInfoFetcher getOSMajorVersion]];

  FIRIAMClearcutUploader *ctUploader =
      [[FIRIAMClearcutUploader alloc] initWithRequestSender:clearcutRequestSender
                                                timeFetcher:timeFetcher
                                                 logStorage:ctLogStorage
                                              usingStrategy:settings.clearcutStrategy
                                          usingUserDefaults:nil];

  FIRIAMClearcutLogger *clearcutLogger =
      [[FIRIAMClearcutLogger alloc] initWithFBProjectNumber:settings.firebaseProjectNumber
                                                    fbAppId:settings.firebaseAppId
                                          clientInfoFetcher:self.clientInfoFetcher
                                           usingTimeFetcher:timeFetcher
                                              usingUploader:ctUploader];

  FIRIAMAnalyticsEventLoggerImpl *analyticsEventLogger = [[FIRIAMAnalyticsEventLoggerImpl alloc]
      initWithClearcutLogger:clearcutLogger
            usingTimeFetcher:timeFetcher
           usingUserDefaults:nil
                   analytics:[FIRInAppMessaging inAppMessaging].analytics];

  FIRIAMSDKModeManager *sdkModeManager =
      [[FIRIAMSDKModeManager alloc] initWithUserDefaults:NSUserDefaults.standardUserDefaults
                                     testingModeListener:self];

  self.fetchOnAppForegroundFlow =
      [[FIRIAMFetchOnAppForegroundFlow alloc] initWithSetting:fetchSetting
                                                 messageCache:self.messageCache
                                               messageFetcher:self.restfulFetcher
                                                  timeFetcher:timeFetcher
                                                   bookKeeper:self.bookKeeper
                                               activityLogger:self.activityLogger
                                         analyticsEventLogger:analyticsEventLogger
                                         FIRIAMSDKModeManager:sdkModeManager];

  FIRIAMActionURLFollower *actionFollower = [FIRIAMActionURLFollower actionURLFollower];

  self.displayExecutor =
      [[FIRIAMDisplayExecutor alloc] initWithInAppMessaging:[FIRInAppMessaging inAppMessaging]
                                                    setting:appForegroundDisplaysetting
                                               messageCache:self.messageCache
                                                timeFetcher:timeFetcher
                                                 bookKeeper:self.bookKeeper
                                          actionURLFollower:actionFollower
                                             activityLogger:self.activityLogger
                                       analyticsEventLogger:analyticsEventLogger];

  // Setting the display component. It's needed in case headless SDK is initialized after
  // the display component is already set on FIRInAppMessaging.
  self.displayExecutor.messageDisplayComponent =
      FIRInAppMessaging.inAppMessaging.messageDisplayComponent;

  // Both display flows are created on startup. But they would only be turned on (started) based on
  // the sdk mode for the current instance
  self.displayOnFetchDoneFlow = [[FIRIAMDisplayCheckOnFetchDoneNotificationFlow alloc]
      initWithDisplayFlow:self.displayExecutor];
  self.displayOnAppForegroundFlow =
      [[FIRIAMDisplayCheckOnAppForegroundFlow alloc] initWithDisplayFlow:self.displayExecutor];

  self.displayOnFIRAnalyticEventsFlow =
      [[FIRIAMDisplayCheckOnAnalyticEventsFlow alloc] initWithDisplayFlow:self.displayExecutor];

  self.messageCache.analycisEventDislayCheckFlow = self.displayOnFIRAnalyticEventsFlow;
  [self.messageCache
      loadMessageDataFromServerFetchStorage:self.fetchResultStorage
                             withCompletion:^(BOOL success) {
                               // start flows regardless whether we can load messages from fetch
                               // storage successfully
                               FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180001",
                                           @"Message loading from fetch storage was done.");

                               if ([self shouldRunSDKFlowsOnStartup]) {
                                 FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180008",
                                             @"Start SDK runtime components.");

                                 [self.clientInfoFetcher
                                     fetchFirebaseIIDDataWithProjectNumber:
                                         self.currentSetting.firebaseProjectNumber
                                                            withCompletion:^(
                                                                NSString *_Nullable iid,
                                                                NSString *_Nullable token,
                                                                NSError *_Nullable error) {
                                                              // Always dump the instance id into
                                                              // log on startup to help developers
                                                              // to find it for their app instance.
                                                              FIRLogDebug(kFIRLoggerInAppMessaging,
                                                                          @"I-IAM180017",
                                                                          @"Starting "
                                                                          @"InAppMessaging runtime "
                                                                          @"with "
                                                                           "Instance ID %@",
                                                                          iid);
                                                            }];

                                 [self.fetchOnAppForegroundFlow start];
                                 [self.displayOnFIRAnalyticEventsFlow start];

                                 self->_running = YES;

                                 if (sdkModeManager.currentMode == FIRIAMSDKModeTesting) {
                                   FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180007",
                                               @"InAppMessaging testing mode enabled. App "
                                                "foreground messages will be displayed following "
                                                "fetch");
                                   [self.displayOnFetchDoneFlow start];
                                 } else {
                                   FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180020",
                                               @"Start regular display flow for non-testing "
                                                "instance mode");
                                   [self.displayOnAppForegroundFlow start];

                                   // Simulate app going into foreground on startup
                                   [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
                                 }

                                 // One-time triggering of checks for both fetch flow
                                 // upon SDK/app startup.
                                 [self.fetchOnAppForegroundFlow
                                     checkAndFetchForInitialAppLaunch:YES];
                               } else {
                                 FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180009",
                                             @"No FIAM SDK startup due to settings.");
                               }
                             }];

  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM180002",
              @"Firebase In-App Messaging SDK version %@ finished startup in %lf seconds "
               "with these settings: %@",
              [self.clientInfoFetcher getIAMSDKVersion],
              (double)([timeFetcher currentTimestampInSeconds] - start), settings);
}
@end
