// Copyright 2019 Google
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

#include <stdatomic.h>

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#include "Crashlytics/Crashlytics/Components/FIRCLSCrashedMarkerFile.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#import "Crashlytics/Crashlytics/Components/FIRCLSHost.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSUserLogging.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionArbiter.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionToken.h"
#import "Crashlytics/Crashlytics/FIRCLSUserDefaults/FIRCLSUserDefaults.h"
#include "Crashlytics/Crashlytics/Handlers/FIRCLSException.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSDefines.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSUtility.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSExecutionIdentifierModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"
#import "Crashlytics/Crashlytics/Settings/Models/FIRCLSApplicationIdentifierModel.h"

#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"
#import "Crashlytics/Shared/FIRCLSByteUtility.h"
#import "Crashlytics/Shared/FIRCLSConstants.h"
#import "Crashlytics/Shared/FIRCLSFABHost.h"

#import "Crashlytics/Crashlytics/Controllers/FIRCLSAnalyticsManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSContextManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSExistingReportManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSNotificationManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSReportManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSReportUploader.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSRolloutsPersistenceManager.h"
#import "Crashlytics/Crashlytics/Private/FIRCLSExistingReportManager_Private.h"
#import "Crashlytics/Crashlytics/Private/FIRCLSOnDemandModel_Private.h"
#import "Crashlytics/Crashlytics/Private/FIRExceptionModel_Private.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

#import <GoogleDataTransport/GoogleDataTransport.h>

@import FirebaseSessions;
@import FirebaseRemoteConfigInterop;
#if SWIFT_PACKAGE
@import FirebaseCrashlyticsSwift;
#elif __has_include(<FirebaseCrashlytics/FirebaseCrashlytics-Swift.h>)
#import <FirebaseCrashlytics/FirebaseCrashlytics-Swift.h>
#elif __has_include("FirebaseCrashlytics-Swift.h")
// If frameworks are not available, fall back to importing the header as it
// should be findable from a header search path pointing to the build
// directory. See #12611 for more context.
#import "FirebaseCrashlytics-Swift.h"
#endif

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

FIRCLSContext _firclsContext;
dispatch_queue_t _firclsLoggingQueue;
dispatch_queue_t _firclsBinaryImageQueue;
dispatch_queue_t _firclsExceptionQueue;

static atomic_bool _hasInitializedInstance;

NSString *const FIRCLSGoogleTransportMappingID = @"1206";

/// Empty protocol to register with FirebaseCore's component system.
@protocol FIRCrashlyticsInstanceProvider <NSObject>
@end

@interface FIRCrashlytics () <FIRLibrary,
                              FIRCrashlyticsInstanceProvider,
                              FIRSessionsSubscriber,
                              FIRRolloutsStateSubscriber>

@property(nonatomic) BOOL didPreviouslyCrash;
@property(nonatomic, copy) NSString *googleAppID;
@property(nonatomic) FIRCLSDataCollectionArbiter *dataArbiter;
@property(nonatomic) FIRCLSFileManager *fileManager;

@property(nonatomic) FIRCLSReportManager *reportManager;

@property(nonatomic) FIRCLSReportUploader *reportUploader;

@property(nonatomic, strong) FIRCLSExistingReportManager *existingReportManager;

@property(nonatomic, strong) FIRCLSAnalyticsManager *analyticsManager;

@property(nonatomic, strong) FIRCLSRemoteConfigManager *remoteConfigManager;

// Dependencies common to each of the Controllers
@property(nonatomic, strong) FIRCLSManagerData *managerData;

@end

@implementation FIRCrashlytics

#pragma mark - Singleton Support

- (instancetype)initWithApp:(FIRApp *)app
                    appInfo:(NSDictionary *)appInfo
              installations:(FIRInstallations *)installations
                  analytics:(id<FIRAnalyticsInterop>)analytics
                   sessions:(id<FIRSessionsProvider>)sessions
               remoteConfig:(id<FIRRemoteConfigInterop>)remoteConfig {
  self = [super init];

  if (self) {
    bool expectedCalled = NO;
    if (!atomic_compare_exchange_strong(&_hasInitializedInstance, &expectedCalled, YES)) {
      FIRCLSErrorLog(@"Cannot instantiate more than one instance of Crashlytics.");
      return nil;
    }

    NSLog(@"[Firebase/Crashlytics] Version %@", FIRCLSSDKVersion());

    FIRCLSDeveloperLog("Crashlytics", @"Running on %@, %@ (%@)", FIRCLSHostModelInfo(),
                       FIRCLSHostOSDisplayVersion(), FIRCLSHostOSBuildVersion());

    GDTCORTransport *googleTransport =
        [[GDTCORTransport alloc] initWithMappingID:FIRCLSGoogleTransportMappingID
                                      transformers:nil
                                            target:kGDTCORTargetCSH];

    _fileManager = [[FIRCLSFileManager alloc] init];
    _googleAppID = app.options.googleAppID;
    _dataArbiter = [[FIRCLSDataCollectionArbiter alloc] initWithApp:app withAppInfo:appInfo];

    FIRCLSApplicationIdentifierModel *appModel = [[FIRCLSApplicationIdentifierModel alloc] init];
    FIRCLSSettings *settings = [[FIRCLSSettings alloc] initWithFileManager:_fileManager
                                                                appIDModel:appModel];

    FIRCLSOnDemandModel *onDemandModel =
        [[FIRCLSOnDemandModel alloc] initWithFIRCLSSettings:settings fileManager:_fileManager];
    _managerData = [[FIRCLSManagerData alloc] initWithGoogleAppID:_googleAppID
                                                  googleTransport:googleTransport
                                                    installations:installations
                                                        analytics:analytics
                                                      fileManager:_fileManager
                                                      dataArbiter:_dataArbiter
                                                         settings:settings
                                                    onDemandModel:onDemandModel];

    if (sessions) {
      FIRCLSDebugLog(@"Registering Sessions SDK subscription for session data");

      // Subscription should be made after the DataCollectionArbiter
      // is initialized so that the Sessions SDK can immediately get
      // the data collection state.
      //
      // It should also be made after managerData is initialized so
      // that the ContextManager can accept data
      [sessions registerWithSubscriber:self];
    }

    _reportUploader = [[FIRCLSReportUploader alloc] initWithManagerData:_managerData];

    _existingReportManager =
        [[FIRCLSExistingReportManager alloc] initWithManagerData:_managerData
                                                  reportUploader:_reportUploader];

    _analyticsManager = [[FIRCLSAnalyticsManager alloc] initWithAnalytics:analytics];

    _reportManager = [[FIRCLSReportManager alloc] initWithManagerData:_managerData
                                                existingReportManager:_existingReportManager
                                                     analyticsManager:_analyticsManager];

    _didPreviouslyCrash = [_fileManager didCrashOnPreviousExecution];
    // Process did crash during previous execution
    if (_didPreviouslyCrash) {
      // Delete the crash file marker in the background ensure start up is as fast as possible
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSString *crashedMarkerFileFullPath = [[self.fileManager rootPath]
            stringByAppendingPathComponent:[NSString
                                               stringWithUTF8String:FIRCLSCrashedMarkerFileName]];
        [self.fileManager removeItemAtPath:crashedMarkerFileFullPath];
      });
    }

    [[[_reportManager startWithProfiling] then:^id _Nullable(NSNumber *_Nullable value) {
      if (![value boolValue]) {
        FIRCLSErrorLog(@"Crash reporting could not be initialized");
      }
      return value;
    }] catch:^void(NSError *error) {
      FIRCLSErrorLog(@"Crash reporting failed to initialize with error: %@", error);
    }];

    // RemoteConfig subscription should be made after session report directory created.
    if (remoteConfig) {
      FIRCLSDebugLog(@"Registering RemoteConfig SDK subscription for rollouts data");

      FIRCLSRolloutsPersistenceManager *persistenceManager =
          [[FIRCLSRolloutsPersistenceManager alloc]
              initWithFileManager:_fileManager
                         andQueue:dispatch_queue_create(
                                      "com.google.firebase.FIRCLSRolloutsPersistence",
                                      DISPATCH_QUEUE_SERIAL)];
      _remoteConfigManager =
          [[FIRCLSRemoteConfigManager alloc] initWithRemoteConfig:remoteConfig
                                              persistenceDelegate:persistenceManager];
          [remoteConfig registerRolloutsStateSubscriber:self for:FIRRemoteConfigConstants.FIRNamespaceGoogleMobilePlatform];
    }
  }
  return self;
}

+ (void)load {
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self withName:@"firebase-crashlytics"];
  [FIRSessionsDependencies addDependencyWithName:FIRSessionsSubscriberNameCrashlytics];
}

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    if (!container.app.isDefaultApp) {
      FIRCLSErrorLog(@"Crashlytics must be used with the default Firebase app.");
      return nil;
    }

    id<FIRAnalyticsInterop> analytics = FIR_COMPONENT(FIRAnalyticsInterop, container);
    id<FIRSessionsProvider> sessions = FIR_COMPONENT(FIRSessionsProvider, container);
    id<FIRRemoteConfigInterop> remoteConfig = FIR_COMPONENT(FIRRemoteConfigInterop, container);

    FIRInstallations *installations = [FIRInstallations installationsWithApp:container.app];

    *isCacheable = YES;

    return [[FIRCrashlytics alloc] initWithApp:container.app
                                       appInfo:NSBundle.mainBundle.infoDictionary
                                 installations:installations
                                     analytics:analytics
                                      sessions:sessions
                                  remoteConfig:remoteConfig];
  };

  FIRComponent *component =
      [FIRComponent componentWithProtocol:@protocol(FIRCrashlyticsInstanceProvider)
                      instantiationTiming:FIRInstantiationTimingEagerInDefaultApp
                            creationBlock:creationBlock];
  return @[ component ];
}

+ (instancetype)crashlytics {
  // The container will return the same instance since isCacheable is set

  FIRApp *defaultApp = [FIRApp defaultApp];  // Missing configure will be logged here.

  // Get the instance from the `FIRApp`'s container. This will create a new instance the
  // first time it is called, and since `isCacheable` is set in the component creation
  // block, it will return the existing instance on subsequent calls.
  id<FIRCrashlyticsInstanceProvider> instance =
      FIR_COMPONENT(FIRCrashlyticsInstanceProvider, defaultApp.container);

  // In the component creation block, we return an instance of `FIRCrashlytics`. Cast it and
  // return it.
  return (FIRCrashlytics *)instance;
}

- (void)setCrashlyticsCollectionEnabled:(BOOL)enabled {
  [self.dataArbiter setCrashlyticsCollectionEnabled:enabled];
}

- (BOOL)isCrashlyticsCollectionEnabled {
  return [self.dataArbiter isCrashlyticsCollectionEnabled];
}

#pragma mark - API: didCrashDuringPreviousExecution

- (BOOL)didCrashDuringPreviousExecution {
  return self.didPreviouslyCrash;
}

- (void)processDidCrashDuringPreviousExecution {
  NSString *crashedMarkerFileName = [NSString stringWithUTF8String:FIRCLSCrashedMarkerFileName];
  NSString *crashedMarkerFileFullPath =
      [[self.fileManager rootPath] stringByAppendingPathComponent:crashedMarkerFileName];
  self.didPreviouslyCrash = [self.fileManager fileExistsAtPath:crashedMarkerFileFullPath];

  if (self.didPreviouslyCrash) {
    // Delete the crash file marker in the background ensure start up is as fast as possible
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
      [self.fileManager removeItemAtPath:crashedMarkerFileFullPath];
    });
  }
}

#pragma mark - API: Logging
- (void)log:(NSString *)msg {
  FIRCLSLog(@"%@", msg);
}

- (void)logWithFormat:(NSString *)format, ... {
  va_list args;
  va_start(args, format);
  [self logWithFormat:format arguments:args];
  va_end(args);
}

- (void)logWithFormat:(NSString *)format arguments:(va_list)args {
  [self log:[[NSString alloc] initWithFormat:format arguments:args]];
}

#pragma mark - API: Accessors

- (void)checkForUnsentReportsWithCompletion:(void (^)(BOOL))completion {
  [[self.reportManager checkForUnsentReports]
      then:^id _Nullable(FIRCrashlyticsReport *_Nullable value) {
        completion(value ? true : false);
        return nil;
      }];
}

- (void)checkAndUpdateUnsentReportsWithCompletion:
    (void (^)(FIRCrashlyticsReport *_Nonnull))completion {
  [[self.reportManager checkForUnsentReports]
      then:^id _Nullable(FIRCrashlyticsReport *_Nullable value) {
        completion(value);
        return nil;
      }];
}

- (void)sendUnsentReports {
  [self.reportManager sendUnsentReports];
}

- (void)deleteUnsentReports {
  [self.reportManager deleteUnsentReports];
}

#pragma mark - API: setUserID
- (void)setUserID:(nullable NSString *)userID {
  FIRCLSUserLoggingRecordInternalKeyValue(FIRCLSUserIdentifierKey, userID);
}

#pragma mark - API: setCustomValue

- (void)setCustomValue:(nullable id)value forKey:(NSString *)key {
  FIRCLSUserLoggingRecordUserKeyValue(key, value);
}

- (void)setCustomKeysAndValues:(NSDictionary *)keysAndValues {
  FIRCLSUserLoggingRecordUserKeysAndValues(keysAndValues);
}

#pragma mark - API: Development Platform
// These two methods are deprecated by our own API, so
// its ok to implement them
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
+ (void)setDevelopmentPlatformName:(NSString *)name {
  [[self crashlytics] setDevelopmentPlatformName:name];
}

+ (void)setDevelopmentPlatformVersion:(NSString *)version {
  [[self crashlytics] setDevelopmentPlatformVersion:version];
}
#pragma clang diagnostic pop

- (NSString *)developmentPlatformName {
  FIRCLSErrorLog(@"developmentPlatformName is write-only");
  return nil;
}

- (void)setDevelopmentPlatformName:(NSString *)developmentPlatformName {
  FIRCLSUserLoggingRecordInternalKeyValue(FIRCLSDevelopmentPlatformNameKey,
                                          developmentPlatformName);
}

- (NSString *)developmentPlatformVersion {
  FIRCLSErrorLog(@"developmentPlatformVersion is write-only");
  return nil;
}

- (void)setDevelopmentPlatformVersion:(NSString *)developmentPlatformVersion {
  FIRCLSUserLoggingRecordInternalKeyValue(FIRCLSDevelopmentPlatformVersionKey,
                                          developmentPlatformVersion);
}

#pragma mark - API: Errors and Exceptions
- (void)recordError:(NSError *)error {
  [self recordError:error userInfo:nil];
}

- (void)recordError:(NSError *)error userInfo:(NSDictionary<NSString *, id> *)userInfo {
  NSString *rolloutsInfoJSON = [_remoteConfigManager getRolloutAssignmentsEncodedJsonString];
  FIRCLSUserLoggingRecordError(error, userInfo, rolloutsInfoJSON);
}

- (void)recordExceptionModel:(FIRExceptionModel *)exceptionModel {
  NSString *rolloutsInfoJSON = [_remoteConfigManager getRolloutAssignmentsEncodedJsonString];
  FIRCLSExceptionRecordModel(exceptionModel, rolloutsInfoJSON);
}

- (void)recordOnDemandExceptionModel:(FIRExceptionModel *)exceptionModel {
  [self.managerData.onDemandModel
      recordOnDemandExceptionIfQuota:exceptionModel
           withDataCollectionEnabled:[self.dataArbiter isCrashlyticsCollectionEnabled]
          usingExistingReportManager:self.existingReportManager];
}

#pragma mark - FIRSessionsSubscriber

- (void)onSessionChanged:(FIRSessionDetails *_Nonnull)session {
  FIRCLSDebugLog(@"Session ID changed: %@", session.sessionId.copy);

  [self.managerData.contextManager setAppQualitySessionId:session.sessionId.copy];
}

- (BOOL)isDataCollectionEnabled {
  return self.dataArbiter.isCrashlyticsCollectionEnabled;
}

- (FIRSessionsSubscriberName)sessionsSubscriberName {
  return FIRSessionsSubscriberNameCrashlytics;
}

#pragma mark - FIRRolloutsStateSubscriber
- (void)rolloutsStateDidChange:(FIRRolloutsState *_Nonnull)rolloutsState {
  if (!_remoteConfigManager) {
    FIRCLSDebugLog(@"rolloutsStateDidChange gets called without init the rc manager.");
    return;
  }
  NSString *currentReportID = _managerData.executionIDModel.executionID;
  [_remoteConfigManager updateRolloutsStateWithRolloutsState:rolloutsState
                                                    reportID:currentReportID];
}
@end
