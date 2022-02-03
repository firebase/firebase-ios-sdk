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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#include "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSCrashedMarkerFile.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSAnalyticsManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionArbiter.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSDefines.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockExistingReportManager.h"

#import "Crashlytics/Crashlytics/Settings/Models/FIRCLSApplicationIdentifierModel.h"
#import "Crashlytics/UnitTests/Mocks/FABMockApplicationIdentifierModel.h"
#import "Crashlytics/UnitTests/Mocks/FIRAppFake.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockReportManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockReportUploader.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockSettings.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSTempMockFileManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRMockGDTCoreTransport.h"
#import "Crashlytics/UnitTests/Mocks/FIRMockInstallations.h"

#define TEST_API_KEY (@"DB5C8FA65C0D43419120FB96CFDBDE0C")
#define TEST_GOOGLE_APP_ID (@"1:632950151350:ios:d5b0d08d4f00f4b1")
#define TEST_INSTALL_ID (@"DC352568-33A7-4830-A9D8-20EA708F1905")
#define TEST_API_ENDPOINT (@"http://test.com")
#define TEST_BUNDLE_ID (@"com.crashlytics.test")
#define TEST_ANALYTICS_JSON \
  (@"{\"name\":\"some_name\",\"nested\":{\"object\":\"with_stuff\"},\"price\":100}")

@interface FIRCLSReportManagerTests : XCTestCase

@property(nonatomic, strong) FIRCLSMockReportManager *reportManager;
@property(nonatomic, strong) FIRCLSMockExistingReportManager *existingReportManager;
@property(nonatomic, strong) FIRCLSMockSettings *mockSettings;
@property(nonatomic, strong) FIRCLSMockReportUploader *mockReportUploader;
@property(nonatomic, strong) FIRCLSTempMockFileManager *fileManager;

@property(nonatomic, strong) FIRCLSDataCollectionArbiter *dataArbiter;
@property(nonatomic, strong) FIRCLSApplicationIdentifierModel *appIDModel;

@end

@implementation FIRCLSReportManagerTests

- (void)setUp {
  [super setUp];

  FIRSetLoggerLevel(FIRLoggerLevelMax);

  FIRCLSContextBaseInit();

  id fakeApp = [[FIRAppFake alloc] init];
  self.dataArbiter = [[FIRCLSDataCollectionArbiter alloc] initWithApp:fakeApp withAppInfo:@{}];

  self.fileManager = [[FIRCLSTempMockFileManager alloc] init];

  // Delete cached settings
  [self.fileManager removeItemAtPath:_fileManager.settingsFilePath];

  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:@"test_token"];

  FIRMockGDTCORTransport *mockGoogleTransport =
      [[FIRMockGDTCORTransport alloc] initWithMappingID:@"id" transformers:nil target:0];
  self.appIDModel = [[FIRCLSApplicationIdentifierModel alloc] init];
  self.mockSettings = [[FIRCLSMockSettings alloc] initWithFileManager:self.fileManager
                                                           appIDModel:self.appIDModel];

  // Allow nil values only in tests
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  FIRCLSManagerData *managerData =
      [[FIRCLSManagerData alloc] initWithGoogleAppID:TEST_GOOGLE_APP_ID
                                     googleTransport:mockGoogleTransport
                                       installations:iid
                                           analytics:nil
                                         fileManager:self.fileManager
                                         dataArbiter:self.dataArbiter
                                            settings:self.mockSettings
                                       onDemandModel:nil];
#pragma clang diagnostic pop

  self.mockReportUploader = [[FIRCLSMockReportUploader alloc] initWithManagerData:managerData];

  self.existingReportManager =
      [[FIRCLSMockExistingReportManager alloc] initWithManagerData:managerData
                                                    reportUploader:self.mockReportUploader];
  FIRCLSAnalyticsManager *analyticsManager = [[FIRCLSAnalyticsManager alloc] initWithAnalytics:nil];

  self.reportManager =
      [[FIRCLSMockReportManager alloc] initWithManagerData:managerData
                                     existingReportManager:self.existingReportManager
                                          analyticsManager:analyticsManager];
}

- (void)tearDown {
  self.reportManager = nil;

  if ([[NSFileManager defaultManager] fileExistsAtPath:[self.fileManager rootPath]]) {
    assert([self.fileManager removeItemAtPath:[self.fileManager rootPath]]);
  }

  FIRCLSContextBaseDeinit();

  [super tearDown];
}

#pragma mark - Path Helpers
- (NSString *)resourcePath {
  return [[NSBundle bundleForClass:[self class]] resourcePath];
}

- (NSArray *)contentsOfActivePath {
  return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.fileManager.activePath
                                                             error:nil];
}

- (NSArray *)contentsOfPreparedPath {
  return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.fileManager.preparedPath
                                                             error:nil];
}

- (NSArray *)contentsOfProcessingPath {
  return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.fileManager.processingPath
                                                             error:nil];
}

#pragma mark - Report Helpers
- (FIRCLSInternalReport *)createActiveReport {
  NSString *reportPath =
      [self.fileManager.activePath stringByAppendingPathComponent:@"my_session_id"];
  FIRCLSInternalReport *report = [[FIRCLSInternalReport alloc] initWithPath:reportPath
                                                        executionIdentifier:@"my_session_id"];

  if (![self.fileManager createDirectoryAtPath:report.path]) {
    return nil;
  }

  if (![self createMetadata:
                 @"{\"identity\":{\"api_key\":\"my_key\",\"session_id\":\"my_session_id\"}}\n"
                  forReport:report]) {
    return nil;
  }
  return report;
}

- (BOOL)createFileWithContents:(NSString *)contents atPath:(NSString *)path {
  return [self.fileManager.underlyingFileManager
      createFileAtPath:path
              contents:[contents dataUsingEncoding:NSUTF8StringEncoding]
            attributes:nil];
}

- (BOOL)createMetadata:(NSString *)value forReport:(FIRCLSInternalReport *)report {
  return [self createFileWithContents:value atPath:[report metadataPath]];
}

#pragma mark - Property Helpers
- (NSArray *)prepareAndSubmitReportArray {
  return self.mockReportUploader.prepareAndSubmitReportArray;
}

- (NSArray *)uploadReportArray {
  return self.mockReportUploader.uploadReportArray;
}

#pragma mark - File/Directory Handling
- (void)testCreatesNewReportOnStart {
  FBLPromise<NSNumber *> *promise = [self->_reportManager startWithProfilingMark:0];

  XCTestExpectation *expectation =
      [[XCTestExpectation alloc] initWithDescription:@"waiting on promise"];
  [promise then:^id _Nullable(NSNumber *_Nullable value) {
    XCTAssertTrue([value boolValue]);
    XCTAssertEqual([[self contentsOfActivePath] count], 1);
    [expectation fulfill];
    return value;
  }];

  [self waitForExpectations:@[ expectation ] timeout:1.0];
}

- (void)waitForPromise:(FBLPromise<NSNumber *> *)promise {
  [self waitForPromise:promise withTimeout:1.0];
}

- (void)waitForPromise:(FBLPromise<NSNumber *> *)promise withTimeout:(double)timeout {
  __block NSNumber *value = nil;
  __block NSError *error = nil;

  XCTestExpectation *expectation =
      [[XCTestExpectation alloc] initWithDescription:@"waiting on promise"];
  [[promise then:^id _Nullable(NSNumber *_Nullable innerValue) {
    value = innerValue;
    [expectation fulfill];
    return nil;
  }] catch:^(NSError *_Nonnull innerError) {
    error = innerError;
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:timeout];
  XCTAssertNil(error);
  XCTAssertTrue([value boolValue]);
}

- (void)startReportManager {
  [self waitForPromise:[self startReportManagerWithDataCollectionEnabled:YES]];
}

- (FBLPromise<NSNumber *> *)startReportManagerWithDataCollectionEnabled:(BOOL)enabled {
  [self.dataArbiter setCrashlyticsCollectionEnabled:enabled];
  return [self.reportManager startWithProfilingMark:0];
}

- (void)processReports:(BOOL)send andExpectReports:(BOOL)reportsExpected {
  XCTestExpectation *processReportsComplete =
      [[XCTestExpectation alloc] initWithDescription:@"processReports: complete"];
  __block BOOL reportsAvailable = NO;
  [[[self.reportManager checkForUnsentReports]
      then:^id _Nullable(FIRCrashlyticsReport *_Nullable report) {
        reportsAvailable = report ? true : false;
        if (send) {
          return [self->_reportManager sendUnsentReports];
        } else {
          return [self->_reportManager deleteUnsentReports];
        }
      }] then:^id _Nullable(id _Nullable ignored) {
    [processReportsComplete fulfill];
    return nil;
  }];
  [self waitForExpectations:@[ processReportsComplete ] timeout:1.0];
  if (reportsExpected) {
    XCTAssertTrue(reportsAvailable, "should have unsent reports");
  } else {
    XCTAssertFalse(reportsAvailable, "should not have unsent reports");
  }
}

- (void)processReports:(BOOL)send {
  [self processReports:send andExpectReports:YES];
}

- (void)testExistingUnimportantReportOnStart {
  // Create a report representing the last run and put it in place
  [self createActiveReport];

  // Report from the last run should get deleted, and a new
  // one should be created for this run.
  [self startReportManager];

  // If this is > 1 it means we're not cleaning up reports from previous runs.
  // If this == 0, it means we're not creating new reports.
  XCTAssertEqual([[self contentsOfActivePath] count], 1);

  XCTAssertEqual([self.prepareAndSubmitReportArray count], 0);
  XCTAssertEqual([self.uploadReportArray count], 0);
}

- (void)testMetricKitResolvesPromiseIfNoDiagnostics {
  // Create a report representing the last run and put it in place, then create a crashed file
  // marker and MetricKit diagnostic file so that MetricKit manager doesn't resolve the promise
  // immediately.
  [self createActiveReport];
  [self.existingReportManager setShouldHaveExistingReport];
  NSString *metricKitPath =
      [self.fileManager.cachesPath stringByAppendingString:@"/MetricKit/Diagnostics/"];
  [self.fileManager createFileAtPath:[[self.fileManager rootPath]
                                         stringByAppendingPathComponent:@"previously-crashed"]
                            contents:nil
                          attributes:nil];
  [self.fileManager createDirectoryAtPath:metricKitPath];
  [self.fileManager createFileAtPath:[metricKitPath stringByAppendingString:@"Diagnostics.txt"]
                            contents:nil
                          attributes:nil];

  // MetricKit manager should resolve its promise after 3 seconds.
  [self waitForPromise:[self startReportManagerWithDataCollectionEnabled:YES] withTimeout:4];
}

- (void)testExistingUnimportantReportOnStartWithDataCollectionDisabled {
  // create a report and put it in place
  [self createActiveReport];

  // Starting with data collection disabled should report in nothing changing
  [self startReportManagerWithDataCollectionEnabled:NO];

  XCTAssertEqual([[self contentsOfActivePath] count], 1);

  XCTAssertEqual([self.prepareAndSubmitReportArray count], 0);
  XCTAssertEqual([self.uploadReportArray count], 0);
}

- (void)testExistingReportOnStart {
  // create a report and put it in place
  FIRCLSInternalReport *report = [self createActiveReport];

  // create a signal file so it is considering worth reporting
  XCTAssertTrue([self createFileWithContents:@"signal"
                                      atPath:[report pathForContentFile:FIRCLSReportSignalFile]]);

  XCTAssertEqual([[self contentsOfActivePath] count], 1);

  [self startReportManager];

  // verify that processReports won't get called.
  [self processReports:YES andExpectReports:NO];

  XCTAssertEqual([[self contentsOfActivePath] count], 1, @"should contain only the current report");

  // should call report manager once for that report
  XCTAssertEqual([self.prepareAndSubmitReportArray count], 1);
  XCTAssertEqualObjects(self.prepareAndSubmitReportArray[0][@"process"], @(YES));
  XCTAssertEqualObjects(self.prepareAndSubmitReportArray[0][@"urgent"], @(NO));
}

- (void)testExistingReportOnStartWithDataCollectionDisabledThenEnabled {
  // create a report and put it in place
  FIRCLSInternalReport *report = [self createActiveReport];

  // create a signal file so it is considering worth reporting
  XCTAssertTrue([self createFileWithContents:@"signal"
                                      atPath:[report pathForContentFile:FIRCLSReportSignalFile]]);

  XCTAssertEqual([[self contentsOfActivePath] count], 1);

  FBLPromise<NSNumber *> *promise = [self startReportManagerWithDataCollectionEnabled:NO];

  XCTAssertEqual([[self contentsOfActivePath] count], 2,
                 @"should contain the current and old reports");

  // should call report manager once for that report
  XCTAssertEqual([self.prepareAndSubmitReportArray count], 0);

  // We can turn data collection on instead of calling processReports.
  [self.dataArbiter setCrashlyticsCollectionEnabled:YES];
  [self waitForPromise:promise];

  XCTAssertEqual([[self contentsOfActivePath] count], 1, @"should contain only the current report");

  // should call report manager once for that report
  XCTAssertEqual([self.prepareAndSubmitReportArray count], 1);
  XCTAssertEqualObjects(self.prepareAndSubmitReportArray[0][@"process"], @(YES));
  XCTAssertEqualObjects(self.prepareAndSubmitReportArray[0][@"urgent"], @(NO));
}

- (void)testExistingReportOnStartWithDataCollectionDisabledAndSend {
  // create a report and put it in place
  FIRCLSInternalReport *report = [self createActiveReport];

  // create a signal file so it is considering worth reporting
  XCTAssertTrue([self createFileWithContents:@"signal"
                                      atPath:[report pathForContentFile:FIRCLSReportSignalFile]]);

  XCTAssertEqual([[self contentsOfActivePath] count], 1);

  [self startReportManagerWithDataCollectionEnabled:NO];

  XCTAssertEqual([[self contentsOfActivePath] count], 2,
                 @"should contain the current and old reports");

  // should call report manager once for that report
  XCTAssertEqual([self.prepareAndSubmitReportArray count], 0);

  [self processReports:YES];

  XCTAssertEqual([[self contentsOfActivePath] count], 1, @"should contain only the current report");

  // should call report manager once for that report
  XCTAssertEqual([self.prepareAndSubmitReportArray count], 1);
  XCTAssertEqualObjects(self.prepareAndSubmitReportArray[0][@"process"], @(YES));
  XCTAssertEqualObjects(self.prepareAndSubmitReportArray[0][@"urgent"], @(NO));

  // Calling processReports again should not call the callback.
  // Technically, the behavior is unspecified.
  [self processReports:YES andExpectReports:NO];
}

- (void)testExistingReportOnStartWithDataCollectionDisabledAndDelete {
  // create a report and put it in place
  FIRCLSInternalReport *report = [self createActiveReport];

  // create a signal file so it is considering worth reporting
  XCTAssertTrue([self createFileWithContents:@"signal"
                                      atPath:[report pathForContentFile:FIRCLSReportSignalFile]]);

  XCTAssertEqual([[self contentsOfActivePath] count], 1);

  [self startReportManagerWithDataCollectionEnabled:NO];

  XCTAssertEqual([[self contentsOfActivePath] count], 2,
                 @"should contain the current and old reports");

  // should call report manager once for that report
  XCTAssertEqual([self.prepareAndSubmitReportArray count], 0);

  [self processReports:NO];

  XCTAssertEqual([[self contentsOfActivePath] count], 1, @"should contain only the current report");

  // Should not call report manager for that report.
  XCTAssertEqual([self.prepareAndSubmitReportArray count], 0);
}

- (void)testExistingUrgentReportOnStart {
  // create a report and put it in place
  FIRCLSInternalReport *report = [self createActiveReport];

  // create a signal file so it is considering worth reporting
  XCTAssertTrue([self createFileWithContents:@"signal"
                                      atPath:[report pathForContentFile:FIRCLSReportSignalFile]]);

  XCTAssertEqual([[self contentsOfActivePath] count], 1);

  // Put the launch marker in place
  [self.reportManager.launchMarker createLaunchFailureMarker];

  // should call back to the delegate on start
  [self startReportManager];
  XCTAssertEqual([[self contentsOfActivePath] count], 1, @"should contain only the current report");

  // should call report manager once for that report
  XCTAssertEqual([self.prepareAndSubmitReportArray count], 1);
  XCTAssertEqualObjects(self.prepareAndSubmitReportArray[0][@"process"], @(YES));
  XCTAssertEqualObjects(self.prepareAndSubmitReportArray[0][@"urgent"], @(YES));
}

- (void)testExistingUrgentReportOnStartWithDataCollectionDisabled {
  // create a report and put it in place
  FIRCLSInternalReport *report = [self createActiveReport];

  // create a signal file so it is considering worth reporting
  XCTAssertTrue([self createFileWithContents:@"signal"
                                      atPath:[report pathForContentFile:FIRCLSReportSignalFile]]);

  XCTAssertEqual([[self contentsOfActivePath] count], 1);

  // Put the launch marker in place
  [self.reportManager.launchMarker createLaunchFailureMarker];

  // Should wait for processReports: to be called.
  [self startReportManagerWithDataCollectionEnabled:NO];

  XCTAssertEqual([[self contentsOfActivePath] count], 2, @"the report hasn't been sent");

  XCTAssertEqual([self.prepareAndSubmitReportArray count], 0);

  [self processReports:YES];

  XCTAssertEqual([[self contentsOfActivePath] count], 1, @"should contain only current report");

  XCTAssertEqual([self.prepareAndSubmitReportArray count], 1);
  XCTAssertEqualObjects(self.prepareAndSubmitReportArray[0][@"process"], @(YES));

  // If data collection is disabled, you can never send the report urgently / blocking
  // startup because you need to call a method after startup to send the report
  XCTAssertEqualObjects(self.prepareAndSubmitReportArray[0][@"urgent"], @(NO));
}

- (void)testFilesLeftInProcessing {
  // put report in processing
  FIRCLSInternalReport *report = [self createActiveReport];
  XCTAssert([_fileManager createDirectoryAtPath:_fileManager.processingPath]);
  XCTAssert([_fileManager moveItemAtPath:[report path] toDirectory:_fileManager.processingPath]);

  [self startReportManager];

  // we should not process reports left over in processing
  XCTAssertEqual([[self contentsOfProcessingPath] count], 0, @"Processing should be cleared");

  XCTAssertEqual([self.prepareAndSubmitReportArray count], 1);
  XCTAssertEqualObjects(self.prepareAndSubmitReportArray[0][@"process"], @(NO));
  XCTAssertEqualObjects(self.prepareAndSubmitReportArray[0][@"urgent"], @(NO));
}

/*
 * This tests an edge case where there is a report in processing. For the purposes of unsent
 * reports these are not shown to the developer, but they are uploaded / deleted upon
 * calling send / delete.
 */
- (void)testFilesLeftInProcessingWithDataCollectionDisabled {
  // Put report in processing.
  FIRCLSInternalReport *report = [self createActiveReport];
  XCTAssert([_fileManager createDirectoryAtPath:_fileManager.processingPath]);
  XCTAssert([_fileManager moveItemAtPath:[report path] toDirectory:_fileManager.processingPath]);

  [self startReportManagerWithDataCollectionEnabled:NO];

  // Nothing should have happened yet.
  XCTAssertEqual([[self contentsOfProcessingPath] count], 1,
                 @"Processing should still have the report");
  XCTAssertEqual([self.prepareAndSubmitReportArray count], 0);

  // We don't expect reports here because we don't consider processing or prepared
  // reports as unsent as they need to be marked for sending before being placed
  // in those directories.
  [self processReports:YES andExpectReports:NO];

  // We should not process reports left over in processing.
  XCTAssertEqual([[self contentsOfProcessingPath] count], 0, @"Processing should be cleared");
  XCTAssertEqual([[self contentsOfPreparedPath] count], 0, @"Prepared should be cleared");

  XCTAssertEqual([self.prepareAndSubmitReportArray count], 1);
  XCTAssertEqualObjects(self.prepareAndSubmitReportArray[0][@"process"], @(NO));
  XCTAssertEqualObjects(self.prepareAndSubmitReportArray[0][@"urgent"], @(NO));
}

- (void)testFilesLeftInPrepared {
  // Drop a phony multipart-mime file in here, with non-zero contents.
  XCTAssert([_fileManager createDirectoryAtPath:_fileManager.preparedPath]);
  NSString *path = [_fileManager.preparedPath stringByAppendingPathComponent:@"phony-report"];
  path = [path stringByAppendingPathExtension:@"multipart-mime"];

  XCTAssertTrue([[_fileManager underlyingFileManager]
      createFileAtPath:path
              contents:[@"contents" dataUsingEncoding:NSUTF8StringEncoding]
            attributes:nil]);

  [self startReportManager];

  // Reports should be moved out of prepared
  XCTAssertEqual([[self contentsOfPreparedPath] count], 0, @"Prepared should be cleared");

  XCTAssertEqual([self.prepareAndSubmitReportArray count], 0);
  XCTAssertEqual([self.uploadReportArray count], 1);
  XCTAssertEqualObjects(self.uploadReportArray[0][@"path"], path);
}

/*
 * This tests an edge case where there is a report in prepared. For the purposes of unsent
 * reports these are not shown to the developer, but they are uploaded / deleted upon
 * calling send / delete.
 */
- (void)testFilesLeftInPreparedWithDataCollectionDisabled {
  // drop a phony multipart-mime file in here, with non-zero contents
  XCTAssert([_fileManager createDirectoryAtPath:_fileManager.preparedPath]);
  NSString *path = [_fileManager.preparedPath stringByAppendingPathComponent:@"phony-report"];
  path = [path stringByAppendingPathExtension:@"multipart-mime"];

  XCTAssertTrue([[_fileManager underlyingFileManager]
      createFileAtPath:path
              contents:[@"contents" dataUsingEncoding:NSUTF8StringEncoding]
            attributes:nil]);

  [self startReportManagerWithDataCollectionEnabled:NO];

  // Nothing should have happened yet.
  XCTAssertEqual([[self contentsOfPreparedPath] count], 1,
                 @"Prepared should still have the report");
  XCTAssertEqual([self.prepareAndSubmitReportArray count], 0);

  // We don't expect reports here because we don't consider processing or prepared
  // reports as unsent as they need to be marked for sending before being placed
  // in those directories.
  [self processReports:YES andExpectReports:NO];

  // Reports should be moved out of prepared
  XCTAssertEqual([[self contentsOfPreparedPath] count], 0, @"Prepared should be cleared");
  XCTAssertEqual([[self contentsOfProcessingPath] count], 0, @"Processing should be cleared");

  XCTAssertEqual([self.prepareAndSubmitReportArray count], 0);
  XCTAssertEqual([self.uploadReportArray count], 1);
  XCTAssertEqualObjects(self.uploadReportArray[0][@"path"], path);
}

- (void)testSuccessfulSubmission {
  // drop a phony multipart-mime file in here, with non-zero contents
  XCTAssert([_fileManager createDirectoryAtPath:_fileManager.preparedPath]);
  NSString *path = [_fileManager.preparedPath stringByAppendingPathComponent:@"phony-report"];
  path = [path stringByAppendingPathExtension:@"multipart-mime"];

  XCTAssertTrue([[_fileManager underlyingFileManager]
      createFileAtPath:path
              contents:[@"contents" dataUsingEncoding:NSUTF8StringEncoding]
            attributes:nil]);

  [self startReportManager];

  // we should not process reports left over in processing
  XCTAssertEqual([[self contentsOfProcessingPath] count], 0, @"Processing should be cleared");

  XCTAssertEqual([self.prepareAndSubmitReportArray count], 0);
  XCTAssertEqual([self.uploadReportArray count], 1);
  XCTAssertEqualObjects(self.uploadReportArray[0][@"path"], path);

  [self.reportManager.operationQueue waitUntilAllOperationsAreFinished];

  // not 100% sure what to verify here
  // lol
}

- (void)testLogInvalidJSONAnalyticsEvents {
  NSDictionary *eventAsDict = @{
    @"price" : @(NAN),
    @"count" : @(INFINITY),
  };

  NSString *json = FIRCLSFIRAEventDictionaryToJSON(eventAsDict);
  XCTAssertEqualObjects(json, nil);
}

@end
