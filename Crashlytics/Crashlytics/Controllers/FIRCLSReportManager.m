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

//
// The report manager has the ability to send to two different endpoints.
//
// The old legacy flow for a report goes through the following states/folders:
// 1. active - .clsrecords optimized for crash time persistence
// 2. processing - .clsrecords with attempted symbolication
// 3. prepared-legacy - .multipartmime of compressed .clsrecords
//
// The new flow for a report goes through the following states/folders:
// 1. active - .clsrecords optimized for crash time persistence
// 2. processing - .clsrecords with attempted symbolication
// 3. prepared - .clsrecords moved from processing with no changes
//
// The code was designed so the report processing workflows are not dramatically different from one
// another. The design will help avoid having a lot of conditional code blocks throughout the
// codebase.
//

#include <stdatomic.h>

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "Crashlytics/Crashlytics/Components/FIRCLSApplication.h"
#import "Crashlytics/Crashlytics/Components/FIRCLSUserLogging.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSAnalyticsManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSExistingReportManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSMetricKitManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSNotificationManager.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionArbiter.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionToken.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSDefines.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSFeatures.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSLaunchMarkerModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSSymbolResolver.h"
#import "Crashlytics/Crashlytics/Operations/Reports/FIRCLSProcessReportOperation.h"
#import "Crashlytics/Crashlytics/Settings/Models/FIRCLSApplicationIdentifierModel.h"

#include "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSUtility.h"

#import "Crashlytics/Crashlytics/Models/FIRCLSExecutionIdentifierModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInstallIdentifierModel.h"
#import "Crashlytics/Crashlytics/Settings/FIRCLSSettingsManager.h"
#import "Crashlytics/Shared/FIRCLSConstants.h"

#import "Crashlytics/Crashlytics/Controllers/FIRCLSReportManager_Private.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

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

@interface FIRCLSReportManager () {
  FIRCLSFileManager *_fileManager;
  dispatch_queue_t _dispatchQueue;
  NSOperationQueue *_operationQueue;
  id<FIRAnalyticsInterop> _analytics;

  // A promise that will be resolved when unsent reports are found on the device, and
  // processReports: can be called to decide how to deal with them.
  FBLPromise<FIRCrashlyticsReport *> *_unsentReportsAvailable;

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
@property(nonatomic, strong) GDTCORTransport *googleTransport;

@property(nonatomic, strong) FIRCLSDataCollectionArbiter *dataArbiter;
@property(nonatomic, strong) FIRCLSSettings *settings;
@property(nonatomic, strong) FIRCLSLaunchMarkerModel *launchMarker;

@property(nonatomic, strong) FIRCLSApplicationIdentifierModel *appIDModel;
@property(nonatomic, strong) FIRCLSInstallIdentifierModel *installIDModel;
@property(nonatomic, strong) FIRCLSExecutionIdentifierModel *executionIDModel;

@property(nonatomic, strong) FIRCLSAnalyticsManager *analyticsManager;
@property(nonatomic, strong) FIRCLSExistingReportManager *existingReportManager;

// Internal Managers
@property(nonatomic, strong) FIRCLSSettingsManager *settingsManager;
@property(nonatomic, strong) FIRCLSNotificationManager *notificationManager;
#if CLS_METRICKIT_SUPPORTED
@property(nonatomic, strong) FIRCLSMetricKitManager *metricKitManager;
#endif

@end

@implementation FIRCLSReportManager

- (instancetype)initWithManagerData:(FIRCLSManagerData *)managerData
              existingReportManager:(FIRCLSExistingReportManager *)existingReportManager
                   analyticsManager:(FIRCLSAnalyticsManager *)analyticsManager {
  self = [super init];
  if (!self) {
    return nil;
  }

  _fileManager = managerData.fileManager;
  _analytics = managerData.analytics;
  _googleAppID = [managerData.googleAppID copy];
  _dataArbiter = managerData.dataArbiter;
  _googleTransport = managerData.googleTransport;
  _operationQueue = managerData.operationQueue;
  _dispatchQueue = managerData.dispatchQueue;
  _appIDModel = managerData.appIDModel;
  _installIDModel = managerData.installIDModel;
  _settings = managerData.settings;
  _executionIDModel = managerData.executionIDModel;

  _existingReportManager = existingReportManager;
  _analyticsManager = analyticsManager;

  _unsentReportsAvailable = [FBLPromise pendingPromise];
  _reportActionProvided = [FBLPromise pendingPromise];
  _unsentReportsHandled = [FBLPromise pendingPromise];

  _checkForUnsentReportsCalled = NO;

  _settingsManager = [[FIRCLSSettingsManager alloc] initWithAppIDModel:self.appIDModel
                                                        installIDModel:self.installIDModel
                                                              settings:self.settings
                                                           fileManager:self.fileManager
                                                           googleAppID:self.googleAppID];

  _notificationManager = [[FIRCLSNotificationManager alloc] init];

  // This needs to be called before any values are read from settings
  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings reloadFromCacheWithGoogleAppID:self.googleAppID currentTimestamp:currentTimestamp];

#if CLS_METRICKIT_SUPPORTED
  if (@available(iOS 15, *)) {
    if (self.settings.metricKitCollectionEnabled) {
      FIRCLSDebugLog(@"MetricKit data collection enabled.");
      _metricKitManager = [[FIRCLSMetricKitManager alloc] initWithManagerData:managerData
                                                        existingReportManager:existingReportManager
                                                                  fileManager:_fileManager];
    }
  }
#endif

  _launchMarker = [[FIRCLSLaunchMarkerModel alloc] initWithFileManager:_fileManager];

  return self;
}

// This method returns a promise that is resolved with a wrapped FIRReportAction once the user has
// indicated whether they want to upload currently cached reports.
// This method should only be called when we have determined there is at least 1 unsent report.
// This method waits until either:
//    1. Data collection becomes enabled, in which case, the promise will be resolved with Send.
//    2. The developer uses the processCrashReports API to indicate whether the report
//       should be sent or deleted, at which point the promise will be resolved with the action.
- (FBLPromise<FIRCLSWrappedReportAction *> *)waitForReportAction {
  FIRCrashlyticsReport *unsentReport = self.existingReportManager.newestUnsentReport;
  [_unsentReportsAvailable fulfill:unsentReport];

  // If data collection gets enabled while we are waiting for an action, go ahead and send the
  // reports, and any subsequent explicit response will be ignored.
  FBLPromise<FIRCLSWrappedReportAction *> *collectionEnabled =
      [[self.dataArbiter waitForCrashlyticsCollectionEnabled]
          then:^id _Nullable(NSNumber *_Nullable value) {
            return @(FIRCLSReportActionSend);
          }];

  // Wait for either the processReports callback to be called, or data collection to be enabled.
  return [FBLPromise race:@[ collectionEnabled, _reportActionProvided ]];
}

/*
 * This method returns a promise that is resolved once
 * MetricKit diagnostic reports have been received by `metricKitManager`.
 */
- (FBLPromise *)waitForMetricKitData {
  // If the platform is not iOS or the iOS version is less than 15, immediately resolve the promise
  // since no MetricKit diagnostics will be available.
  FBLPromise *promise = [FBLPromise resolvedWith:nil];
#if CLS_METRICKIT_SUPPORTED
  if (@available(iOS 15, *)) {
    if (self.settings.metricKitCollectionEnabled) {
      promise = [self.metricKitManager waitForMetricKitDataAvailable];
    }
  }
  return promise;
#endif
  return promise;
}

- (FBLPromise<FIRCrashlyticsReport *> *)checkForUnsentReports {
  bool expectedCalled = NO;
  if (!atomic_compare_exchange_strong(&_checkForUnsentReportsCalled, &expectedCalled, YES)) {
    FIRCLSErrorLog(@"Either checkForUnsentReports or checkAndUpdateUnsentReports should be called "
                   @"once per execution.");
    return [FBLPromise resolvedWith:nil];
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

  // This needs to be called before the new report is created for
  // this run of the app.
  [self.existingReportManager collectExistingReports];

  if (![self validateAppIdentifiers]) {
    return [FBLPromise resolvedWith:@NO];
  }

#if DEBUG
  FIRCLSDebugLog(@"Root: %@", [_fileManager rootPath]);
#endif

  if (![_fileManager createReportDirectories]) {
    return [FBLPromise resolvedWith:@NO];
  }

  BOOL launchFailure = [self.launchMarker checkForAndCreateLaunchMarker];

  FIRCLSInternalReport *report = [self setupCurrentReport:executionIdentifier];
  if (!report) {
    FIRCLSErrorLog(@"Unable to setup a new report");
  }

  if (![self startCrashReporterWithProfilingMark:mark report:report]) {
    FIRCLSErrorLog(@"Unable to start crash reporter");
    report = nil;
  }

#if CLS_METRICKIT_SUPPORTED
  if (@available(iOS 15, *)) {
    if (self.settings.metricKitCollectionEnabled) {
      [self.metricKitManager registerMetricKitManager];
    }
  }
#endif

  FBLPromise<NSNumber *> *promise;

  if ([self.dataArbiter isCrashlyticsCollectionEnabled]) {
    FIRCLSDebugLog(@"Automatic data collection is enabled.");
    FIRCLSDebugLog(@"Unsent reports will be uploaded at startup");
    FIRCLSDataCollectionToken *dataCollectionToken = [FIRCLSDataCollectionToken validToken];

    [self beginSettingsWithToken:dataCollectionToken];

    // Wait for MetricKit data to be available, then continue to send reports and resolve promise.
    promise = [[self waitForMetricKitData]
        onQueue:_dispatchQueue
           then:^id _Nullable(id _Nullable metricKitValue) {
             [self beginReportUploadsWithToken:dataCollectionToken blockingSend:launchFailure];

             // If data collection is enabled, the SDK will not notify the user
             // when unsent reports are available, or respect Send / DeleteUnsentReports
             [self->_unsentReportsAvailable fulfill:nil];
             return @(report != nil);
           }];
  } else {
    FIRCLSDebugLog(@"Automatic data collection is disabled.");
    FIRCLSDebugLog(@"[Crashlytics:Crash] %d unsent reports are available. Waiting for "
                   @"send/deleteUnsentReports to be called.",
                   self.existingReportManager.unsentReportsCount);

    // Wait for an action to get sent, either from processReports: or automatic data collection,
    // and for MetricKit data to be available.
    promise = [[FBLPromise all:@[ [self waitForReportAction], [self waitForMetricKitData] ]]
        onQueue:_dispatchQueue
           then:^id _Nullable(NSArray *_Nullable wrappedActionAndData) {
             // Process the actions for the reports on disk.
             FIRCLSReportAction action = [[wrappedActionAndData firstObject] reportActionValue];

             if (action == FIRCLSReportActionSend) {
               FIRCLSDebugLog(@"Sending unsent reports.");
               FIRCLSDataCollectionToken *dataCollectionToken =
                   [FIRCLSDataCollectionToken validToken];

               [self beginSettingsWithToken:dataCollectionToken];

               [self beginReportUploadsWithToken:dataCollectionToken blockingSend:NO];

             } else if (action == FIRCLSReportActionDelete) {
               FIRCLSDebugLog(@"Deleting unsent reports.");
               [self.existingReportManager deleteUnsentReports];
             } else {
               FIRCLSErrorLog(@"Unknown report action: %d", action);
             }
             return @(report != nil);
           }];
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
    FBLPromise *allOpsFinished = [FBLPromise pendingPromise];
    [queue addOperationWithBlock:^{
      [allOpsFinished fulfill:nil];
    }];

    return [allOpsFinished onQueue:dispatch_get_main_queue()
                              then:^id _Nullable(id _Nullable allOpsFinishedValue) {
                                // Signal that to callers of processReports that everything is
                                // finished.
                                [unsentReportsHandled fulfill:nil];
                                return value;
                              }];
  }];

  return promise;
}

- (void)beginSettingsWithToken:(FIRCLSDataCollectionToken *)token {
  if (self.settings.isCacheExpired) {
    // This method can be called more than once if the user calls
    // SendUnsentReports again, so don't repeat the settings fetch
    static dispatch_once_t settingsFetchOnceToken;
    dispatch_once(&settingsFetchOnceToken, ^{
      [self.settingsManager beginSettingsWithGoogleAppId:self.googleAppID token:token];
    });
  }
}

- (void)beginReportUploadsWithToken:(FIRCLSDataCollectionToken *)token
                       blockingSend:(BOOL)blockingSend {
  if (self.settings.collectReportsEnabled) {
    [self.existingReportManager sendUnsentReportsWithToken:token asUrgent:blockingSend];

  } else {
    FIRCLSInfoLog(@"Collect crash reports is disabled");
    [self.existingReportManager deleteUnsentReports];
  }
}

- (BOOL)startCrashReporterWithProfilingMark:(FIRCLSProfileMark)mark
                                     report:(FIRCLSInternalReport *)report {
  if (!report) {
    return NO;
  }

  if (!FIRCLSContextInitialize(report, self.settings, _fileManager)) {
    return NO;
  }

  [self.notificationManager registerNotificationListener];

  [self.analyticsManager registerAnalyticsListener];

  [self crashReportingSetupCompleted:mark];

  return YES;
}

- (void)crashReportingSetupCompleted:(FIRCLSProfileMark)mark {
  // check our handlers
  FIRCLSDispatchAfter(2.0, dispatch_get_main_queue(), ^{
    FIRCLSExceptionCheckHandlers((__bridge void *)(self));
#if CLS_SIGNAL_SUPPORTED
    FIRCLSSignalCheckHandlers();
#endif
#if CLS_MACH_EXCEPTION_SUPPORTED
    FIRCLSMachExceptionCheckHandlers();
#endif
  });

  // remove the launch failure marker and record the startup time
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.launchMarker removeLaunchFailureMarker];
    dispatch_async(FIRCLSGetLoggingQueue(), ^{
      FIRCLSUserLoggingWriteInternalKeyValue(FIRCLSFirstRunloopTurnTimeKey,
                                             [@(FIRCLSProfileEnd(mark)) description]);
    });
  });
}

- (BOOL)validateAppIdentifiers {
  // When the ApplicationIdentifierModel fails to initialize, it is usually due to
  // failing computeExecutableInfo. This can happen if the user sets the
  // Exported Symbols File in Build Settings, and leaves off the one symbol
  // that Crashlytics needs, "__mh_execute_header" (wich is defined in mach-o/ldsyms.h as
  // _MH_EXECUTE_SYM). From https://github.com/firebase/firebase-ios-sdk/issues/5020
  if (!self.appIDModel) {
    FIRCLSErrorLog(
        @"Crashlytics could not find the symbol for the app's main function and cannot "
        @"start up. This can happen when Exported Symbols File is set in Build Settings. To "
        @"resolve this, add \"__mh_execute_header\" as a newline to your Exported Symbols File.");
    return NO;
  }

  if (self.appIDModel.bundleID.length == 0) {
    FIRCLSErrorLog(@"An application must have a valid bundle identifier in its Info.plist");
    return NO;
  }

  if ([self.dataArbiter isLegacyDataCollectionKeyInPlist]) {
    FIRCLSErrorLog(@"Found legacy data collection key in app's Info.plist: "
                   @"firebase_crashlytics_collection_enabled");
    FIRCLSErrorLog(@"Please update your Info.plist to use the new data collection key: "
                   @"FirebaseCrashlyticsCollectionEnabled");
    FIRCLSErrorLog(@"The legacy data collection Info.plist value could be overridden by "
                   @"calling: [Fabric with:...]");
    FIRCLSErrorLog(@"The new value can be overridden by calling: [[FIRCrashlytics "
                   @"crashlytics] setCrashlyticsCollectionEnabled:<isEnabled>]");

    return NO;
  }

  return YES;
}

- (FIRCLSInternalReport *)setupCurrentReport:(NSString *)executionIdentifier {
  [self.launchMarker createLaunchFailureMarker];

  NSString *reportPath = [_fileManager setupNewPathForExecutionIdentifier:executionIdentifier];

  return [[FIRCLSInternalReport alloc] initWithPath:reportPath
                                executionIdentifier:executionIdentifier];
}

@end
