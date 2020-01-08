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

#import "FIRCLSApplication.h"
#import "FIRCLSDataCollectionArbiter.h"
#import "FIRCLSDataCollectionToken.h"
#import "FIRCLSDefines.h"
#import "FIRCLSFeatures.h"
#import "FIRCLSFileManager.h"
#import "FIRCLSInternalReport.h"
#import "FIRCLSLogger.h"
#import "FIRCLSNetworkClient.h"
#import "FIRCLSPackageReportOperation.h"
#import "FIRCLSProcessReportOperation.h"
#import "FIRCLSReportUploader.h"
#import "FIRCLSSettings.h"
#import "FIRCLSSymbolResolver.h"
#import "FIRCLSUserLogging.h"

#include "FIRCLSGlobals.h"
#include "FIRCLSUtility.h"

#import "FIRCLSApplicationIdentifierModel.h"
#import "FIRCLSConstants.h"
#import "FIRCLSExecutionIdentifierModel.h"
#import "FIRCLSInstallIdentifierModel.h"
#import "FIRCLSSettingsOnboardingManager.h"

#import "FIRCLSReportManager_Private.h"

#include <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>
#include <FirebaseAnalyticsInterop/FIRAnalyticsInteropListener.h>
#include "FIRAEvent+Internal.h"
#include "FIRCLSFCRAnalytics.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

static NSTimeInterval const CLSReportRetryInterval = 10 * 60;

static NSString *FIRCLSFirebaseAnalyticsEventLogFormat = @"$A$:%@";

@interface FIRCLSAnalyticsInteropListener : NSObject <FIRAnalyticsInteropListener> {
}
@end

@implementation FIRCLSAnalyticsInteropListener

- (void)messageTriggered:(NSString *)name parameters:(NSDictionary *)parameters {
  NSDictionary *event = @{
    @"name" : name,
    @"parameters" : parameters,
  };
  NSString *json = FIRCLSFIRAEventDictionaryToJSON(event);
  if (json != nil) {
    FIRCLSLog(FIRCLSFirebaseAnalyticsEventLogFormat, json);
  }
}

@end

/**
 * A FIRReportAction is used to indicate how to handle unsent reports.
 */
typedef NS_ENUM(NSInteger, FIRCLSReportAction) {
  /** Upload the reports to Crashlytics. */
  FIRCLSReportActionSend,
  /** Delete the reports without uploading them. */
  FIRCLSReportActionDelete,
};

/**
 * This is just a helper to make code using FIRReportAction more readable.
 */
typedef NSNumber FIRCLSWrappedReportAction;
@implementation NSNumber (FIRCLSWrappedReportAction)
- (FIRCLSReportAction)reportActionValue {
  return [self intValue];
}
@end

/**
 * This is a helper to make code using NSNumber for bools more readable.
 */
typedef NSNumber FIRCLSWrappedBool;

@interface FIRCLSReportManager () <FIRCLSNetworkClientDelegate,
                                   FIRCLSReportUploaderDelegate,
                                   FIRCLSReportUploaderDataSource> {
  FIRCLSFileManager *_fileManager;
  FIRCLSNetworkClient *_networkClient;
  FIRCLSReportUploader *_uploader;
  dispatch_queue_t _dispatchQueue;
  NSOperationQueue *_operationQueue;
  id<FIRAnalyticsInterop> _analytics;

  // A promise that will be resolved when unsent reports are found on the device, and
  // processReports: can be called to decide how to deal with them.
  FBLPromise<FIRCLSWrappedBool *> *_unsentReportsAvailable;

  // A promise that will be resolved when the user has provided an action that they want to perform
  // for all the unsent reports.
  FBLPromise<FIRCLSWrappedReportAction *> *_reportActionProvided;

  // A promise that will be resolved when all unsent reports have been "handled". They won't
  // necessarily have been uploaded, but we will know whether they should be sent or deleted, and
  // the initial work to make that happen will have been processed on the work queue.
  //
  // Currently only used for testing
  FBLPromise *_unsentReportsHandled;

  // A token to make sure that checkForUnsentReports only gets called once.
  atomic_bool _checkForUnsentReportsCalled;

  BOOL _registeredAnalyticsEventListener;
}

@property(nonatomic, readonly) NSString *googleAppID;

@property(nonatomic, strong) FIRCLSDataCollectionArbiter *dataArbiter;

// Uniquely identifies a build / binary of the app
@property(nonatomic, strong) FIRCLSApplicationIdentifierModel *appIDModel;

// Uniquely identifies an install of the app
@property(nonatomic, strong) FIRCLSInstallIdentifierModel *installIDModel;

// Uniquely identifies a run of the app
@property(nonatomic, strong) FIRCLSExecutionIdentifierModel *executionIDModel;

// Settings fetched from the server
@property(nonatomic, strong) FIRCLSSettings *settings;

// Runs the operations that fetch settings and call onboarding endpoints
@property(nonatomic, strong) FIRCLSSettingsOnboardingManager *settingsAndOnboardingManager;

@end

@implementation FIRCLSReportManager

// Used only for internal data collection E2E testing
static void (^reportSentCallback)(void);

- (instancetype)initWithFileManager:(FIRCLSFileManager *)fileManager
                         instanceID:(FIRInstanceID *)instanceID
                          analytics:(id<FIRAnalyticsInterop>)analytics
                        googleAppID:(NSString *)googleAppID
                        dataArbiter:(FIRCLSDataCollectionArbiter *)dataArbiter {
  self = [super init];
  if (!self) {
    return nil;
  }

  _fileManager = fileManager;
  _analytics = analytics;
  _googleAppID = [googleAppID copy];
  _dataArbiter = dataArbiter;

  NSString *sdkBundleID = FIRCLSApplicationGetSDKBundleID();

  _operationQueue = [NSOperationQueue new];
  [_operationQueue setMaxConcurrentOperationCount:1];
  [_operationQueue setName:[sdkBundleID stringByAppendingString:@".work-queue"]];

  _dispatchQueue = dispatch_queue_create("com.google.firebase.crashlytics.startup", 0);
  _operationQueue.underlyingQueue = _dispatchQueue;

  _networkClient = [self clientWithOperationQueue:_operationQueue];

  _unsentReportsAvailable = [FBLPromise pendingPromise];
  _reportActionProvided = [FBLPromise pendingPromise];
  _unsentReportsHandled = [FBLPromise pendingPromise];

  _checkForUnsentReportsCalled = NO;

  _appIDModel = [[FIRCLSApplicationIdentifierModel alloc] init];
  _installIDModel = [[FIRCLSInstallIdentifierModel alloc] initWithInstanceID:instanceID];
  _executionIDModel = [[FIRCLSExecutionIdentifierModel alloc] init];

  _settings = [[FIRCLSSettings alloc] initWithFileManager:_fileManager appIDModel:_appIDModel];

  _settingsAndOnboardingManager =
      [[FIRCLSSettingsOnboardingManager alloc] initWithAppIDModel:self.appIDModel
                                                   installIDModel:self.installIDModel
                                                         settings:self.settings
                                                      fileManager:self.fileManager
                                                      googleAppID:self.googleAppID];

  return self;
}

- (FIRCLSNetworkClient *)clientWithOperationQueue:(NSOperationQueue *)queue {
  return [[FIRCLSNetworkClient alloc] initWithQueue:queue fileManager:_fileManager delegate:self];
}

/**
 * Returns the number of unsent reports on the device, including the ones passed in.
 */
- (int)unsentReportsCountWithPreexisting:(NSArray<NSString *> *)paths {
  int count = [self countSubmittableAndDeleteUnsubmittableReportPaths:paths];
  count += _fileManager.processingPathContents.count;
  count += _fileManager.preparedPathContents.count;
  return count;
}

// This method returns a promise that is resolved with a wrapped FIRReportAction once the user has
// indicated whether they want to upload currently cached reports.
// This method should only be called when we have determined there is at least 1 unsent report.
// This method waits until either:
//    1. Data collection becomes enabled, in which case, the promise will be resolved with Send.
//    2. The developer uses the processCrashReports API to indicate whether the report
//       should be sent or deleted, at which point the promise will be resolved with the action.
- (FBLPromise<FIRCLSWrappedReportAction *> *)waitForReportAction {
  FIRCLSDebugLog(@"[Crashlytics:Crash] Notifying that unsent reports are available.");
  [_unsentReportsAvailable fulfill:@YES];

  // If data collection gets enabled while we are waiting for an action, go ahead and send the
  // reports, and any subsequent explicit response will be ignored.
  FBLPromise<FIRCLSWrappedReportAction *> *collectionEnabled =
      [[self.dataArbiter waitForCrashlyticsCollectionEnabled]
          then:^id _Nullable(NSNumber *_Nullable value) {
            return @(FIRCLSReportActionSend);
          }];

  FIRCLSDebugLog(@"[Crashlytics:Crash] Waiting for send/deleteUnsentReports to be called.");
  // Wait for either the processReports callback to be called, or data collection to be enabled.
  return [FBLPromise race:@[ collectionEnabled, _reportActionProvided ]];
}

- (FBLPromise<FIRCLSWrappedBool *> *)checkForUnsentReports {
  bool expectedCalled = NO;
  if (!atomic_compare_exchange_strong(&_checkForUnsentReportsCalled, &expectedCalled, YES)) {
    FIRCLSErrorLog(@"checkForUnsentReports should only be called once per execution.");
    return [FBLPromise resolvedWith:@NO];
  }
  return _unsentReportsAvailable;
}

- (FBLPromise *)sendUnsentReports {
  [_reportActionProvided fulfill:@(FIRCLSReportActionSend)];
  return _unsentReportsHandled;
}

- (FBLPromise *)deleteUnsentReports {
  [_reportActionProvided fulfill:@(FIRCLSReportActionDelete)];
  return _unsentReportsHandled;
}

- (FBLPromise<NSNumber *> *)startWithProfilingMark:(FIRCLSProfileMark)mark {
  NSString *executionIdentifier = self.executionIDModel.executionID;

  // This needs to be called before any values are read from settings
  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings reloadFromCacheWithGoogleAppID:self.googleAppID currentTimestamp:currentTimestamp];

  if (![self checkBundleIDExists]) {
    return [FBLPromise resolvedWith:@NO];
  }

#if DEBUG
  FIRCLSDebugLog(@"Root: %@", [_fileManager rootPath]);
#endif

  if ([self.dataArbiter isLegacyDataCollectionKeyInPlist]) {
    FIRCLSErrorLog(@"Found legacy data collection key in app's Info.plist: "
                   @"firebase_crashlytics_collection_enabled");
    FIRCLSErrorLog(@"Please update your Info.plist to use the new data collection key: "
                   @"FirebaseCrashlyticsCollectionEnabled");
    FIRCLSErrorLog(@"The legacy data collection Info.plist value could be overridden by "
                   @"calling: [Fabric with:...]");
    FIRCLSErrorLog(@"The new value can be overridden by calling: [[FIRCrashlytics "
                   @"crashlytics] setCrashlyticsCollectionEnabled:<isEnabled>]");

    return [FBLPromise resolvedWith:@NO];
  }

  if (![self.settings crashReportingEnabled]) {
    FIRCLSInfoLog(@"Reporting is disabled");
    [_fileManager removeContentsOfAllPaths];
    return [FBLPromise resolvedWith:@NO];
  }

  if (![_fileManager createReportDirectories]) {
    return [FBLPromise resolvedWith:@NO];
  }

  // Grab existing reports
  BOOL launchFailure = [self checkForAndCreateLaunchMarker];
  NSArray *preexistingReportPaths = _fileManager.activePathContents;

  FIRCLSInternalReport *report = [self setupCurrentReport:executionIdentifier];
  if (!report) {
    FIRCLSErrorLog(@"Unable to setup a new report");
  }

  if (![self startCrashReporterWithProfilingMark:mark report:report]) {
    FIRCLSErrorLog(@"Unable to start crash reporter");
    report = nil;
  }

  // Regenerate the Install ID on a background thread if it needs to rotate because
  // fetching the Firebase Install ID can be slow on some devices. This should happen after we
  // create the session on disk so that we can update the Install ID in the written crash report
  // metadata.
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    [self checkAndRotateInstallUUIDIfNeededWithReport:report];
  });

  FBLPromise<NSNumber *> *promise = [FBLPromise resolvedWith:@(report != nil)];

  if ([self.dataArbiter isCrashlyticsCollectionEnabled]) {
    FIRCLSDebugLog(@"Automatic data collection is enabled.");
    FIRCLSDebugLog(@"Unsent reports will be uploaded at startup");
    FIRCLSDataCollectionToken *dataCollectionToken = [FIRCLSDataCollectionToken validToken];
    [self startNetworkRequestsWithToken:dataCollectionToken
                 preexistingReportPaths:preexistingReportPaths
                           blockingSend:launchFailure
                                 report:report];

    // If data collection is enabled, the SDK will not notify the user
    // when unsent reports are available, or respect Send / DeleteUnsentReports
    [_unsentReportsAvailable fulfill:@NO];

  } else {
    FIRCLSDebugLog(@"Automatic data collection is disabled.");

    // TODO: This counting of the file system happens on the main thread. Now that some of the other
    // work below has been made async and moved to the dispatch queue, maybe we can move this code
    // to the dispatch queue as well.
    int unsentReportsCount = [self unsentReportsCountWithPreexisting:preexistingReportPaths];
    if (unsentReportsCount > 0) {
      FIRCLSDebugLog(
          @"[Crashlytics:Crash] %d unsent reports are available. Checking for upload permission.",
          unsentReportsCount);
      // Wait for an action to get sent, either from processReports: or automatic data collection.
      promise = [[self waitForReportAction]
          onQueue:_dispatchQueue
             then:^id _Nullable(FIRCLSWrappedReportAction *_Nullable wrappedAction) {
               // Process the actions for the reports on disk.
               FIRCLSReportAction action = [wrappedAction reportActionValue];
               if (action == FIRCLSReportActionSend) {
                 FIRCLSDebugLog(@"Sending unsent reports.");
                 FIRCLSDataCollectionToken *dataCollectionToken =
                     [FIRCLSDataCollectionToken validToken];
                 [self startNetworkRequestsWithToken:dataCollectionToken
                              preexistingReportPaths:preexistingReportPaths
                                        blockingSend:NO
                                              report:report];

               } else if (action == FIRCLSReportActionDelete) {
                 FIRCLSDebugLog(@"Deleting unsent reports.");
                 [self removeExistingReportPaths:preexistingReportPaths];
                 [self removeContentsInOtherReportingDirectories];
               } else {
                 FIRCLSErrorLog(@"Unknown report action: %d", action);
               }
               return @(report != nil);
             }];
    } else {
      FIRCLSDebugLog(@"[Crashlytics:Crash] There are no unsent reports.");
      [_unsentReportsAvailable fulfill:@NO];
    }
  }

  if (report != nil) {
    // capture the start-up time here, but record it asynchronously
    double endMark = FIRCLSProfileEnd(mark);

    dispatch_async(FIRCLSGetLoggingQueue(), ^{
      FIRCLSUserLoggingWriteInternalKeyValue(FIRCLSStartTimeKey, [@(endMark) description]);
    });
  }

  // To make the code more predictable and therefore testable, don't resolve the startup promise
  // until the operations that got queued up for processing reports have been processed through the
  // work queue.
  NSOperationQueue *__weak queue = _operationQueue;
  FBLPromise *__weak unsentReportsHandled = _unsentReportsHandled;
  promise = [promise then:^id _Nullable(NSNumber *_Nullable value) {
    [queue waitUntilAllOperationsAreFinished];
    // Signal that to callers of processReports that everything is finished.
    [unsentReportsHandled fulfill:nil];
    return value;
  }];

  return promise;
}

- (void)checkAndRotateInstallUUIDIfNeededWithReport:(FIRCLSInternalReport *)report {
  [self.installIDModel regenerateInstallIDIfNeededWithBlock:^(BOOL didRotate) {
    if (!didRotate) {
      return;
    }

    FIRCLSContextInitData initData = [self initializeContextInitData:report];

    FIRCLSContextUpdateMetadata(&initData);
  }];
}

- (void)startNetworkRequestsWithToken:(FIRCLSDataCollectionToken *)token
               preexistingReportPaths:(NSArray *)preexistingReportPaths
                         blockingSend:(BOOL)blockingSend
                               report:(FIRCLSInternalReport *)report {
  if (self.settings.isCacheExpired) {
    // This method can be called more than once if the user calls
    // SendUnsentReports again, so don't repeat the settings fetch
    static dispatch_once_t settingsFetchOnceToken;
    dispatch_once(&settingsFetchOnceToken, ^{
      [self.settingsAndOnboardingManager beginSettingsAndOnboardingWithGoogleAppId:self.googleAppID
                                                                             token:token];
    });
  }

  [self processExistingReportPaths:preexistingReportPaths
               dataCollectionToken:token
                          asUrgent:blockingSend];
  [self handleContentsInOtherReportingDirectoriesWithToken:token];
}

- (FIRCLSContextInitData)initializeContextInitData:(FIRCLSInternalReport *)report {
  FIRCLSContextInitData initData;

  memset(&initData, 0, sizeof(FIRCLSContextInitData));

  // Because we need to start the crash reporter right away,
  // it starts up either with default settings, or cached settings
  // from the last time they were fetched
  FIRCLSSettings *settings = self.settings;

  initData.customBundleId = NULL;
  initData.installId = [self.installIDModel.installID UTF8String];
  initData.sessionId = [[report identifier] UTF8String];
  initData.rootPath = [[report path] UTF8String];
  initData.previouslyCrashedFileRootPath = [[_fileManager rootPath] UTF8String];
#if CLS_MACH_EXCEPTION_SUPPORTED
  initData.machExceptionMask = [self machExceptionMask];
#endif
  initData.errorsEnabled = [settings errorReportingEnabled];
  initData.customExceptionsEnabled = [settings customExceptionsEnabled];
  initData.maxCustomExceptions = [settings maxCustomExceptions];
  initData.maxErrorLogSize = [settings errorLogBufferSize];
  initData.maxLogSize = [settings logBufferSize];
  initData.maxKeyValues = [settings maxCustomKeys];

  return initData;
}

- (BOOL)startCrashReporterWithProfilingMark:(FIRCLSProfileMark)mark
                                     report:(FIRCLSInternalReport *)report {
  if (!report) {
    return NO;
  }

  FIRCLSContextInitData initData = [self initializeContextInitData:report];

  // If this is set, then we could attempt to do a synchronous submission for certain kinds of
  // events (exceptions). This is a very cool feature, but adds complexity to the backend. For now,
  // we're going to leave this disabled. It does work in the exception case, but will ultimtely
  // result in the following crash to be discared. Usually that crash isn't interesting. But, if it
  // was, we'd never have a chance to see it.
  initData.delegate = NULL;

  if (![self installCrashReportingHandlers:&initData]) {
    return NO;
  }

  [self registerAnalyticsEventListener];

  [self crashReportingSetupCompleted:mark];

  return YES;
}

- (void)crashReportingSetupCompleted:(FIRCLSProfileMark)mark {
  // check our handlers
  FIRCLSDispatchAfter(2.0, dispatch_get_main_queue(), ^{
    FIRCLSExceptionCheckHandlers((__bridge void *)(self));
    FIRCLSSignalCheckHandlers();
#if CLS_MACH_EXCEPTION_SUPPORTED
    FIRCLSMachExceptionCheckHandlers();
#endif
  });

  // remove the launch failure marker and record the startup time
  dispatch_async(dispatch_get_main_queue(), ^{
    [self removeLaunchFailureMarker];
    dispatch_async(FIRCLSGetLoggingQueue(), ^{
      FIRCLSUserLoggingWriteInternalKeyValue(FIRCLSFirstRunloopTurnTimeKey,
                                             [@(FIRCLSProfileEnd(mark)) description]);
    });
  });
}

- (BOOL)checkBundleIDExists {
  if (self.appIDModel.bundleID.length == 0) {
    FIRCLSErrorLog(@"An application must have a valid bundle identifier in its Info.plist");
    return NO;
  }

  return YES;
}

- (FIRCLSReportUploader *)uploader {
  if (!_uploader) {
    _uploader = [[FIRCLSReportUploader alloc] initWithQueue:self.operationQueue
                                                   delegate:self
                                                 dataSource:self
                                                     client:self.networkClient
                                                fileManager:_fileManager
                                                  analytics:_analytics];
  }

  return _uploader;
}

#if CLS_MACH_EXCEPTION_SUPPORTED
- (exception_mask_t)machExceptionMask {
  __block exception_mask_t mask = 0;

  // TODO(b/141241224) This if statement was hardcoded to no, so this block was never run
  //  FIRCLSSignalEnumerateHandledSignals(^(int idx, int signal) {
  //    if ([self.delegate ensureDeliveryOfUnixSignal:signal]) {
  //      mask |= FIRCLSMachExceptionMaskForSignal(signal);
  //    }
  //  });

  return mask;
}
#endif

#pragma mark - Reporting Lifecycle

- (BOOL)installCrashReportingHandlers:(FIRCLSContextInitData *)initData {
  if (!FIRCLSContextInitialize(initData)) {
    return NO;
  }

  [self setupStateNotifications];

  return YES;
}

- (FIRCLSInternalReport *)setupCurrentReport:(NSString *)executionIdentifier {
  [self createLaunchFailureMarker];

  NSString *reportPath = [_fileManager setupNewPathForExecutionIdentifier:executionIdentifier];

  return [[FIRCLSInternalReport alloc] initWithPath:reportPath
                                executionIdentifier:executionIdentifier];
}

- (void)removeExistingReportPaths:(NSArray *)reportPaths {
  [self.operationQueue addOperationWithBlock:^{
    for (NSString *path in reportPaths) {
      [self.fileManager removeItemAtPath:path];
    }
  }];
}

- (int)countSubmittableAndDeleteUnsubmittableReportPaths:(NSArray *)reportPaths {
  int count = 0;
  for (NSString *path in reportPaths) {
    FIRCLSInternalReport *report = [FIRCLSInternalReport reportWithPath:path];
    if ([report needsToBeSubmitted]) {
      count++;
    } else {
      [self.operationQueue addOperationWithBlock:^{
        [self->_fileManager removeItemAtPath:path];
      }];
    }
  }
  return count;
}

- (void)processExistingReportPaths:(NSArray *)reportPaths
               dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                          asUrgent:(BOOL)urgent {
  for (NSString *path in reportPaths) {
    [self processExistingActiveReportPath:path
                      dataCollectionToken:dataCollectionToken
                                 asUrgent:urgent];
  }
}

- (void)processExistingActiveReportPath:(NSString *)path
                    dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                               asUrgent:(BOOL)urgent {
  FIRCLSInternalReport *report = [FIRCLSInternalReport reportWithPath:path];

  // TODO: needsToBeSubmitted should really be called on the background queue.
  if (![report needsToBeSubmitted]) {
    [self.operationQueue addOperationWithBlock:^{
      [self->_fileManager removeItemAtPath:path];
    }];

    return;
  }

  if (urgent && [dataCollectionToken isValid]) {
    // We can proceed without the delegate.
    [[self uploader] prepareAndSubmitReport:report
                        dataCollectionToken:dataCollectionToken
                                   asUrgent:urgent
                             withProcessing:YES];
    return;
  }

  [self submitReport:report dataCollectionToken:dataCollectionToken];
}

- (void)submitReport:(FIRCLSInternalReport *)report
    dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken {
  [self.operationQueue addOperationWithBlock:^{
    [[self uploader] prepareAndSubmitReport:report
                        dataCollectionToken:dataCollectionToken
                                   asUrgent:NO
                             withProcessing:YES];
  }];

  [self didSubmitReport];
}

- (void)removeReport:(FIRCLSInternalReport *)report {
  [_fileManager removeItemAtPath:report.path];
}

- (void)removeContentsInOtherReportingDirectories {
  [self removeExistingReportPaths:self.fileManager.processingPathContents];
  [self removeExistingReportPaths:self.fileManager.preparedPathContents];
}

- (void)handleContentsInOtherReportingDirectoriesWithToken:(FIRCLSDataCollectionToken *)token {
  [self handleExistingFilesInProcessingWithToken:token];
  [self handleExistingFilesInPreparedWithToken:token];
}

- (void)handleExistingFilesInProcessingWithToken:(FIRCLSDataCollectionToken *)token {
  NSArray *processingPaths = _fileManager.processingPathContents;

  // deal with stuff in processing more carefully - do not process again
  [self.operationQueue addOperationWithBlock:^{
    for (NSString *path in processingPaths) {
      FIRCLSInternalReport *report = [FIRCLSInternalReport reportWithPath:path];
      [[self uploader] prepareAndSubmitReport:report
                          dataCollectionToken:token
                                     asUrgent:NO
                               withProcessing:NO];
    }
  }];
}

- (void)handleExistingFilesInPreparedWithToken:(FIRCLSDataCollectionToken *)token {
  NSArray *preparedPaths = _fileManager.preparedPathContents;

  // Give our network client a chance to reconnect here, if needed. This attempts to avoid
  // trying to re-submit a prepared file that is already in flight.
  [self.networkClient attemptToReconnectBackgroundSessionWithCompletionBlock:^{
    [self.operationQueue addOperationWithBlock:^{
      [self uploadPreexistingFiles:preparedPaths withToken:token];
    }];
  }];
}

- (void)uploadPreexistingFiles:(NSArray *)files withToken:(FIRCLSDataCollectionToken *)token {
  // Because this could happen quite a bit after the inital set of files was
  // captured, some could be completed (deleted). So, just double-check to make sure
  // the file still exists.

  for (NSString *path in files) {
    if (![[_fileManager underlyingFileManager] fileExistsAtPath:path]) {
      continue;
    }

    [[self uploader] uploadPackagedReportAtPath:path dataCollectionToken:token asUrgent:NO];
  }
}

- (void)retryUploadForReportAtPath:(NSString *)path
               dataCollectionToken:(FIRCLSDataCollectionToken *)token {
  FIRCLSAddOperationAfter(CLSReportRetryInterval, self.operationQueue, ^{
    FIRCLSDeveloperLog("Crashlytics:Crash", @"re-attempting report submission");
    [[self uploader] uploadPackagedReportAtPath:path dataCollectionToken:token asUrgent:NO];
  });
}

#pragma mark - Launch Failure Detection
- (NSString *)launchFailureMarkerPath {
  return [[_fileManager structurePath] stringByAppendingPathComponent:@"launchmarker"];
}

- (BOOL)createLaunchFailureMarker {
  // It's tempting to use - [NSFileManger createFileAtPath:contents:attributes:] here. But that
  // operation, even with empty/nil contents does a ton of work to write out nothing via a
  // temporarly file. This is a much faster implemenation.
  const char *path = [[self launchFailureMarkerPath] fileSystemRepresentation];

#if TARGET_OS_IPHONE
  /*
   * data-protected non-portable open(2) :
   * int open_dprotected_np(user_addr_t path, int flags, int class, int dpflags, int mode)
   */
  int fd = open_dprotected_np(path, O_WRONLY | O_CREAT | O_TRUNC, 4, 0, 0644);
#else
  int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
#endif
  if (fd == -1) {
    return NO;
  }

  return close(fd) == 0;
}

- (BOOL)launchFailureMarkerPresent {
  return [[_fileManager underlyingFileManager] fileExistsAtPath:[self launchFailureMarkerPath]];
}

- (BOOL)removeLaunchFailureMarker {
  return [_fileManager removeItemAtPath:[self launchFailureMarkerPath]];
}

- (BOOL)checkForAndCreateLaunchMarker {
  BOOL launchFailure = [self launchFailureMarkerPresent];
  if (launchFailure) {
    FIRCLSDeveloperLog("Crashlytics:Crash",
                       @"Last launch failed: this may indicate a crash shortly after app launch.");
  } else {
    [self createLaunchFailureMarker];
  }

  return launchFailure;
}

#pragma mark -

- (void)registerAnalyticsEventListener {
  if (_registeredAnalyticsEventListener) {
    return;
  }
  FIRCLSAnalyticsInteropListener *listener = [[FIRCLSAnalyticsInteropListener alloc] init];
  [FIRCLSFCRAnalytics registerEventListener:listener toAnalytics:_analytics];
  _registeredAnalyticsEventListener = YES;
}

#pragma mark - Notifications
- (void)setupStateNotifications {
  [self captureInitialNotificationStates];

#if TARGET_OS_IOS
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(willBecomeActive:)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didBecomeInactive:)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didChangeOrientation:)
                                               name:UIDeviceOrientationDidChangeNotification
                                             object:nil];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(didChangeUIOrientation:)
             name:UIApplicationDidChangeStatusBarOrientationNotification
           object:nil];
#pragma clang diagnostic pop

#elif CLS_TARGET_OS_OSX
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(willBecomeActive:)
                                               name:@"NSApplicationWillBecomeActiveNotification"
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didBecomeInactive:)
                                               name:@"NSApplicationDidResignActiveNotification"
                                             object:nil];
#endif
}

- (void)captureInitialNotificationStates {
#if TARGET_OS_IOS
  UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
  UIInterfaceOrientation statusBarOrientation =
      [FIRCLSApplicationSharedInstance() statusBarOrientation];
#endif

  // It's nice to do this async, so we don't hold up the main thread while doing three
  // consecutive IOs here.
  dispatch_async(FIRCLSGetLoggingQueue(), ^{
    FIRCLSUserLoggingWriteInternalKeyValue(FIRCLSInBackgroundKey, @"0");
#if TARGET_OS_IOS
    FIRCLSUserLoggingWriteInternalKeyValue(FIRCLSDeviceOrientationKey,
                                           [@(orientation) description]);
    FIRCLSUserLoggingWriteInternalKeyValue(FIRCLSUIOrientationKey,
                                           [@(statusBarOrientation) description]);
#endif
  });
}

- (void)willBecomeActive:(NSNotification *)notification {
  FIRCLSUserLoggingRecordInternalKeyValue(FIRCLSInBackgroundKey, @NO);
}

- (void)didBecomeInactive:(NSNotification *)notification {
  FIRCLSUserLoggingRecordInternalKeyValue(FIRCLSInBackgroundKey, @YES);
}

#if TARGET_OS_IOS
- (void)didChangeOrientation:(NSNotification *)notification {
  UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];

  FIRCLSUserLoggingRecordInternalKeyValue(FIRCLSDeviceOrientationKey, @(orientation));
}

- (void)didChangeUIOrientation:(NSNotification *)notification {
  UIInterfaceOrientation statusBarOrientation =
      [FIRCLSApplicationSharedInstance() statusBarOrientation];

  FIRCLSUserLoggingRecordInternalKeyValue(FIRCLSUIOrientationKey, @(statusBarOrientation));
}
#endif

#pragma mark - FIRCLSNetworkClientDelegate
- (BOOL)networkClientCanUseBackgroundSessions:(FIRCLSNetworkClient *)client {
  return !FIRCLSApplicationIsExtension();
}

- (void)networkClient:(FIRCLSNetworkClient *)client
    didFinishUploadWithPath:(NSString *)path
                      error:(NSError *)error {
  // Route this through to the reports uploader.
  // Since this callback happens after an upload finished, then we can assume that the original data
  // collection was authorized. This isn't ideal, but it's better than trying to plumb the data
  // collection token through all the system networking callbacks.
  FIRCLSDataCollectionToken *token = [FIRCLSDataCollectionToken validToken];
  [[self uploader] reportUploadAtPath:path dataCollectionToken:token completedWithError:error];
}

#pragma mark - FIRCLSReportUploaderDelegate

- (void)didCompletePackageSubmission:(NSString *)path
                 dataCollectionToken:(FIRCLSDataCollectionToken *)token
                               error:(NSError *)error {
  if (!error) {
    FIRCLSDeveloperLog("Crashlytics:Crash", @"report submission successful");
    return;
  }

  FIRCLSDeveloperLog("Crashlytics:Crash", @"report submission failed with error %@", error);
  FIRCLSSDKLog("Error: failed to submit report '%s'\n", error.description.UTF8String);

  [self retryUploadForReportAtPath:path dataCollectionToken:token];
}

- (void)didCompleteAllSubmissions {
  [self.operationQueue addOperationWithBlock:^{
    // Dealloc the reports uploader. If we need it again (if we re-enqueued submissions from
    // didCompletePackageSubmission:, we can just create it again
    self->_uploader = nil;

    FIRCLSDeveloperLog("Crashlytics:Crash", @"report submission complete");
  }];
}

#pragma mark - UITest Helpers

// Used only for internal data collection E2E testing
- (void)didSubmitReport {
  if (reportSentCallback) {
    dispatch_async(dispatch_get_main_queue(), ^{
      reportSentCallback();
    });
  }
}

+ (void)setReportSentCallback:(void (^)(void))callback {
  reportSentCallback = callback;
}

@end
