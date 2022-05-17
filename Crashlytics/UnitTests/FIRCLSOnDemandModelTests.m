// Copyright 2022 Google LLC
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

#import <XCTest/XCTest.h>

#include "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSExecutionIdentifierModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Private/FIRCLSOnDemandModel_Private.h"
#import "Crashlytics/UnitTests/Mocks/FIRAppFake.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockExistingReportManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockFileManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockOnDemandModel.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockReportUploader.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockSettings.h"
#import "Crashlytics/UnitTests/Mocks/FIRMockGDTCoreTransport.h"
#import "Crashlytics/UnitTests/Mocks/FIRMockInstallations.h"

#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionArbiter.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionToken.h"
#import "Crashlytics/Crashlytics/Settings/Models/FIRCLSApplicationIdentifierModel.h"

#define TEST_GOOGLE_APP_ID (@"1:632950151350:ios:d5b0d08d4f00f4b1")

@interface FIRCLSOnDemandModelTests : XCTestCase

@property(nonatomic, retain) FIRCLSMockOnDemandModel *onDemandModel;
@property(nonatomic, strong) FIRCLSExistingReportManager *existingReportManager;
@property(nonatomic, strong) FIRCLSManagerData *managerData;
@property(nonatomic, strong) FIRCLSDataCollectionArbiter *dataArbiter;
@property(nonatomic, strong) FIRCLSMockFileManager *fileManager;
@property(nonatomic, strong) FIRCLSMockReportUploader *mockReportUploader;
@property(nonatomic, strong) FIRCLSMockSettings *mockSettings;

@end

@implementation FIRCLSOnDemandModelTests

- (void)setUp {
  [super setUp];
  FIRSetLoggerLevel(FIRLoggerLevelMax);

  FIRCLSContextBaseInit();

  id fakeApp = [[FIRAppFake alloc] init];
  self.dataArbiter = [[FIRCLSDataCollectionArbiter alloc] initWithApp:fakeApp withAppInfo:@{}];

  self.fileManager = [[FIRCLSMockFileManager alloc] init];

  FIRCLSApplicationIdentifierModel *appIDModel = [[FIRCLSApplicationIdentifierModel alloc] init];
  _mockSettings = [[FIRCLSMockSettings alloc] initWithFileManager:self.fileManager
                                                       appIDModel:appIDModel];
  _onDemandModel = [[FIRCLSMockOnDemandModel alloc] initWithFIRCLSSettings:_mockSettings
                                                               fileManager:_fileManager
                                                                sleepBlock:^(int delay){
                                                                }];

  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:@"test_token"];

  FIRMockGDTCORTransport *mockGoogleTransport =
      [[FIRMockGDTCORTransport alloc] initWithMappingID:@"id" transformers:nil target:0];

  _managerData = [[FIRCLSManagerData alloc] initWithGoogleAppID:TEST_GOOGLE_APP_ID
                                                googleTransport:mockGoogleTransport
                                                  installations:iid
                                                      analytics:nil
                                                    fileManager:self.fileManager
                                                    dataArbiter:self.dataArbiter
                                                       settings:self.mockSettings
                                                  onDemandModel:_onDemandModel];
  _mockReportUploader = [[FIRCLSMockReportUploader alloc] initWithManagerData:self.managerData];
  _existingReportManager =
      [[FIRCLSExistingReportManager alloc] initWithManagerData:self.managerData
                                                reportUploader:self.mockReportUploader];
  [self.fileManager createReportDirectories];
  [self.fileManager
      setupNewPathForExecutionIdentifier:self.managerData.executionIDModel.executionID];

  NSString *name = @"exception_model_report";
  NSString *reportPath = [self.fileManager.rootPath stringByAppendingPathComponent:name];
  [self.fileManager createDirectoryAtPath:reportPath];

  FIRCLSInternalReport *report =
      [[FIRCLSInternalReport alloc] initWithPath:reportPath
                             executionIdentifier:@"TEST_EXECUTION_IDENTIFIER"];

  FIRCLSContextInitialize(report, self.mockSettings, self.fileManager);
}

- (void)tearDown {
  self.onDemandModel = nil;
  [[NSFileManager defaultManager] removeItemAtPath:self.fileManager.rootPath error:nil];
  [super tearDown];
}

- (void)setSleepBlock:(void (^)(int))sleepBlock {
  ((FIRCLSMockOnDemandModel *)self.managerData.onDemandModel).sleepBlock = sleepBlock;
}

- (void)testIncrementsQueueWhenEventRecorded {
  FIRExceptionModel *exceptionModel = [self getTestExceptionModel];
  XCTestExpectation *testComplete =
      [[XCTestExpectation alloc] initWithDescription:@"complete test"];

  // Put an expectation in the sleep block so we can test the state of the queue.
  __weak FIRCLSOnDemandModelTests *weakSelf = self;
  [self setSleepBlock:^(int delay) {
    XCTAssertEqual(delay, 60 / self.mockSettings.onDemandUploadRate);
    [weakSelf waitForExpectations:@[ testComplete ] timeout:1.0];
  }];

  BOOL success = [self.onDemandModel recordOnDemandExceptionIfQuota:exceptionModel
                                          withDataCollectionEnabled:YES
                                         usingExistingReportManager:self.existingReportManager];
  // Should record but not submit a report.
  XCTAssertTrue(success);
  XCTAssertEqual([self.onDemandModel recordedOnDemandExceptionCount], 1);
  XCTAssertEqual(self.onDemandModel.getQueuedOperationsCount, 1);

  // Fulfill the expectation so the sleep block completes.
  [testComplete fulfill];
}

- (void)testCompliesWithDataCollectionOff {
  FIRExceptionModel *exceptionModel = [self getTestExceptionModel];
  XCTestExpectation *sleepComplete =
      [[XCTestExpectation alloc] initWithDescription:@"complete test"];

  // Put an expectation in the sleep block so we can test the state of the queue.
  __weak FIRCLSOnDemandModelTests *weakSelf = self;
  [self setSleepBlock:^(int delay) {
    XCTAssertEqual(delay, 60 / self.mockSettings.onDemandUploadRate);
    [weakSelf waitForExpectations:@[ sleepComplete ] timeout:1.0];
  }];

  BOOL success = [self.onDemandModel recordOnDemandExceptionIfQuota:exceptionModel
                                          withDataCollectionEnabled:NO
                                         usingExistingReportManager:self.existingReportManager];

  // Should record but not submit a report.
  XCTAssertTrue(success);

  // We still count this as a recorded event if it was recorded but not submitted.
  XCTAssertEqual([self.onDemandModel recordedOnDemandExceptionCount], 1);
  XCTAssertEqual(self.onDemandModel.getQueuedOperationsCount, 1);

  // Fulfill the expectation so the sleep block completes.
  [sleepComplete fulfill];
  [self.managerData.onDemandModel.operationQueue waitUntilAllOperationsAreFinished];

  XCTAssertEqual(self.onDemandModel.getQueuedOperationsCount, 0);
  XCTAssertEqual([self contentsOfActivePath].count, 1);
  XCTAssertEqual([self.onDemandModel.storedActiveReportPaths count], 1);
}

- (void)testQuotaWithDataCollectionOff {
  FIRExceptionModel *exceptionModel = [self getTestExceptionModel];

  for (int i = 0; i < 10; i++) {
    BOOL success =
        [self.managerData.onDemandModel recordOnDemandExceptionIfQuota:exceptionModel
                                             withDataCollectionEnabled:NO
                                            usingExistingReportManager:self.existingReportManager];

    XCTAssertTrue(success);
  }

  // Once we've finished processing, there should be only FIRCLSMaxUnsentReports recorded with the
  // rest considered dropped. The recorded events should be stored in storedActiveReportPaths which
  // is kept in sync with the contents of the active path.
  [self.managerData.onDemandModel.operationQueue waitUntilAllOperationsAreFinished];
  XCTAssertEqual([self.managerData.onDemandModel.operationQueue operationCount], 0);

  XCTAssertEqual([self.managerData.onDemandModel recordedOnDemandExceptionCount],
                 FIRCLSMaxUnsentReports);
  XCTAssertEqual([self contentsOfActivePath].count, FIRCLSMaxUnsentReports);
  XCTAssertEqual([self.managerData.onDemandModel.storedActiveReportPaths count],
                 FIRCLSMaxUnsentReports);

  // Once we call sendUnsentReports, stored reports should be sent immediately.
  [self.existingReportManager sendUnsentReportsWithToken:[FIRCLSDataCollectionToken validToken]
                                                asUrgent:YES];
  XCTAssertEqual([self.managerData.onDemandModel recordedOnDemandExceptionCount],
                 FIRCLSMaxUnsentReports);
  [self.existingReportManager.operationQueue waitUntilAllOperationsAreFinished];
  XCTAssertEqual([self contentsOfActivePath].count, 0);
  XCTAssertEqual([self.managerData.onDemandModel.storedActiveReportPaths count], 0);
}

- (void)testDropsEventIfNoQuota {
  [self.onDemandModel setQueueToFull];
  FIRExceptionModel *exceptionModel = [self getTestExceptionModel];
  BOOL success = [self.onDemandModel recordOnDemandExceptionIfQuota:exceptionModel
                                          withDataCollectionEnabled:NO
                                         usingExistingReportManager:self.existingReportManager];

  // Should return false when attempting to record an event and increment the count of dropped
  // events.
  XCTAssertFalse(success);
  XCTAssertEqual(self.onDemandModel.getQueuedOperationsCount, [self.onDemandModel getQueueMax]);
  XCTAssertEqual([self.onDemandModel droppedOnDemandExceptionCount], 1);
}

- (void)testDroppedEventCountResets {
  [self.onDemandModel setQueueToFull];

  FIRExceptionModel *exceptionModel = [self getTestExceptionModel];
  BOOL success = [self.onDemandModel recordOnDemandExceptionIfQuota:exceptionModel
                                          withDataCollectionEnabled:NO
                                         usingExistingReportManager:self.existingReportManager];

  // Should return false when attempting to record an event and increment the count of dropped
  // events.
  XCTAssertFalse(success);
  XCTAssertEqual(self.onDemandModel.getQueuedOperationsCount, [self.onDemandModel getQueueMax]);
  XCTAssertEqual([self.onDemandModel droppedOnDemandExceptionCount], 1);

  // Reset the queue to empty
  [self.onDemandModel setQueuedOperationsCount:0];
  success = [self.onDemandModel recordOnDemandExceptionIfQuota:exceptionModel
                                     withDataCollectionEnabled:NO
                                    usingExistingReportManager:self.existingReportManager];

  // Now have room in the queue to record the event
  XCTAssertTrue(success);
  // droppedOnDemandExceptionCount should be reset once we record the event
  XCTAssertEqual([self.onDemandModel droppedOnDemandExceptionCount], 0);
}

#pragma mark - Helpers
- (NSArray *)contentsOfActivePath {
  return [self.fileManager activePathContents];
}

- (FIRExceptionModel *)getTestExceptionModel {
  NSArray *stackTrace = @[
    [FIRStackFrame stackFrameWithSymbol:@"CrashyFunc" file:@"AppLib.m" line:504],
    [FIRStackFrame stackFrameWithSymbol:@"ApplicationMain" file:@"AppleLib" line:1],
    [FIRStackFrame stackFrameWithSymbol:@"main()" file:@"main.m" line:201],
  ];
  NSString *name = @"FIRCLSOnDemandModelTestCrash";
  NSString *reason = @"Programmer made an error";

  FIRExceptionModel *exceptionModel = [FIRExceptionModel exceptionModelWithName:name reason:reason];
  exceptionModel.stackTrace = stackTrace;
  exceptionModel.isFatal = YES;
  exceptionModel.onDemand = YES;
  return exceptionModel;
}

@end
