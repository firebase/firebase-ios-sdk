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

#import <XCTest/XCTest.h>

#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSReportUploader_Private.h"

#import "Crashlytics/Crashlytics/Components/FIRCLSApplication.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionArbiter.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionToken.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSDefines.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"
#import "Crashlytics/Shared/FIRCLSConstants.h"
#import "Crashlytics/UnitTests/Mocks/FABMockApplicationIdentifierModel.h"
#import "Crashlytics/UnitTests/Mocks/FIRAppFake.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockSettings.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSTempMockFileManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRMockGDTCoreTransport.h"
#import "Crashlytics/UnitTests/Mocks/FIRMockInstallations.h"

NSString *const TestEndpoint = @"https://reports.crashlytics.com";
NSString *const TestFIID = @"TestFIID";

@interface FIRCLSReportUploaderTests : XCTestCase

@property(nonatomic, strong) FIRCLSReportUploader *uploader;
@property(nonatomic, strong) FIRCLSTempMockFileManager *fileManager;
@property(nonatomic, strong) NSOperationQueue *queue;
@property(nonatomic, strong) FIRCLSManagerData *managerData;

// Add mock prefix to names as there are naming conflicts with FIRCLSReportUploaderDelegate
@property(nonatomic, strong) FIRMockGDTCORTransport *mockDataTransport;
@property(nonatomic, strong) FIRCLSMockSettings *mockSettings;
@property(nonatomic, strong) FIRMockInstallations *mockInstallations;
@property(nonatomic, strong) FIRCLSDataCollectionArbiter *dataArbiter;

@end

@implementation FIRCLSReportUploaderTests

- (void)setUp {
  [super setUp];

  FABMockApplicationIdentifierModel *appIDModel = [[FABMockApplicationIdentifierModel alloc] init];
  self.queue = [NSOperationQueue new];
  self.mockSettings = [[FIRCLSMockSettings alloc] initWithFileManager:self.fileManager
                                                           appIDModel:appIDModel];
  self.mockDataTransport = [[FIRMockGDTCORTransport alloc] initWithMappingID:@"1206"
                                                                transformers:nil
                                                                      target:kGDTCORTargetCSH];
  self.mockDataTransport.sendDataEvent_wasWritten = YES;
  self.fileManager = [[FIRCLSTempMockFileManager alloc] init];

  id fakeApp = [[FIRAppFake alloc] init];
  self.dataArbiter = [[FIRCLSDataCollectionArbiter alloc] initWithApp:fakeApp withAppInfo:@{}];
  self.mockInstallations = [[FIRMockInstallations alloc] initWithFID:TestFIID];

  [self setupUploaderWithInstallations:self.mockInstallations];
}

- (void)tearDown {
  self.uploader = nil;
  [FIRApp resetApps];

  [super tearDown];
}

- (void)setupUploaderWithInstallations:(FIRInstallations *)installations {
  // Allow nil values only in tests
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  self.managerData = [[FIRCLSManagerData alloc] initWithGoogleAppID:@"someGoogleAppId"
                                                    googleTransport:self.mockDataTransport
                                                      installations:installations
                                                          analytics:nil
                                                        fileManager:self.fileManager
                                                        dataArbiter:self.dataArbiter
                                                           settings:self.mockSettings
                                                      onDemandModel:nil];
#pragma clang diagnostic pop

  self.uploader = [[FIRCLSReportUploader alloc] initWithManagerData:self.managerData];
}

- (NSString *)resourcePath {
#if SWIFT_PACKAGE
  NSBundle *bundle = SWIFTPM_MODULE_BUNDLE;
  return [bundle.resourcePath stringByAppendingPathComponent:@"Data"];
#else
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  return bundle.resourcePath;
#endif
}

- (FIRCLSInternalReport *)createReport {
  NSString *path = [self.fileManager.activePath stringByAppendingPathComponent:@"pkg_uuid"];
  FIRCLSInternalReport *report = [[FIRCLSInternalReport alloc] initWithPath:path];
  self.fileManager.moveItemAtPathResult = [NSNumber numberWithInt:1];
  return report;
}

#pragma mark - Tests

- (void)testPrepareReport {
  FIRCLSInternalReport *report = [self createReport];

  XCTAssertNil(self.uploader.fiid);

  [self.uploader prepareAndSubmitReport:report
                    dataCollectionToken:FIRCLSDataCollectionToken.validToken
                               asUrgent:NO
                         withProcessing:YES];

  XCTAssertEqual(self.uploader.fiid, TestFIID);

  // Verify with the last move operation is from processing -> prepared
  XCTAssertTrue(
      [self.fileManager.moveItemAtPath_destDir containsString:self.fileManager.preparedPath]);
}

- (void)testPrepareReportOnMainThread {
  NSString *pathToPlist =
      [[self resourcePath] stringByAppendingPathComponent:@"GoogleService-Info.plist"];
  FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:pathToPlist];

  [FIRApp configureWithName:@"__FIRAPP_DEFAULT" options:options];
  XCTAssertNotNil([FIRApp defaultApp], @"configureWithName must have been initialized");

  FIRInstallations *installations = [FIRInstallations installationsWithApp:[FIRApp defaultApp]];
  FIRCLSInternalReport *report = [self createReport];
  [self setupUploaderWithInstallations:installations];

  /*
   if a report is urgent report will be processed on the Main Thread
   otherwise, it will be dispatched to a NSOperationQueue (see `FIRCLSExistingReportManager.m:230`)

   This test checks if `prepareAndSubmitReport` finishes in a reasonable time.
   */

  NSOperationQueue *queue = [NSOperationQueue new];

  // target call will block the main thread, so we need a background thread
  // that will wait on a semaphore for a timeout
  dispatch_semaphore_t backgroundWaiter = dispatch_semaphore_create(0);
  [queue addOperationWithBlock:^{
    intptr_t result = dispatch_semaphore_wait(backgroundWaiter,
                                              dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC));
    BOOL exitBecauseOfTimeout = result != 0;
    XCTAssertFalse(exitBecauseOfTimeout, @"Main Thread was blocked for more than 1 second");
  }];

  // Urgent (on the Main thread)
  [self.uploader prepareAndSubmitReport:report
                    dataCollectionToken:FIRCLSDataCollectionToken.validToken
                               asUrgent:YES
                         withProcessing:YES];
  dispatch_semaphore_signal(backgroundWaiter);

  // Not urgent (on a background thread)
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"wait for a preparation to complete"];

  [queue addOperationWithBlock:^{
    [self.uploader prepareAndSubmitReport:report
                      dataCollectionToken:FIRCLSDataCollectionToken.validToken
                                 asUrgent:YES
                           withProcessing:YES];
    [expectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *_Nullable error) {
                                 XCTAssertNil(error, @"expectations failed: %@", error);
                               }];
}

- (void)test_NilFIID_DoesNotCrash {
  FIRCLSInternalReport *report = [self createReport];

  self.mockInstallations = [[FIRMockInstallations alloc]
      initWithError:[NSError errorWithDomain:@"TestDomain" code:-1 userInfo:nil]];
  [self setupUploaderWithInstallations:self.mockInstallations];

  XCTAssertNil(self.uploader.fiid);

  [self.uploader prepareAndSubmitReport:report
                    dataCollectionToken:FIRCLSDataCollectionToken.validToken
                               asUrgent:YES
                         withProcessing:YES];

  XCTAssertNil(self.uploader.fiid);
}

- (void)testUploadPackagedReportWithPath {
  [self runUploadPackagedReportWithUrgency:NO];
}

- (void)testUrgentUploadPackagedReportWithPath {
  [self runUploadPackagedReportWithUrgency:YES];
}

- (void)testUrgentWaitUntilUpload {
  self.mockDataTransport.async = YES;

  [self runUploadPackagedReportWithUrgency:YES];

  XCTAssertNotNil(self.mockDataTransport.sendDataEvent_event);
}

- (void)testUrgentWaitUntilUploadWithError {
  self.mockDataTransport.async = YES;
  self.mockDataTransport.sendDataEvent_error = [[NSError alloc] initWithDomain:@"domain"
                                                                          code:1
                                                                      userInfo:nil];

  [self.uploader uploadPackagedReportAtPath:[self packagePath]
                        dataCollectionToken:FIRCLSDataCollectionToken.validToken
                                   asUrgent:YES];

  XCTAssertNotNil(self.mockDataTransport.sendDataEvent_event);
}

- (void)testUrgentWaitUntilUploadWithWritingError {
  self.mockDataTransport.async = YES;
  self.mockDataTransport.sendDataEvent_wasWritten = NO;

  [self.uploader uploadPackagedReportAtPath:[self packagePath]
                        dataCollectionToken:FIRCLSDataCollectionToken.validToken
                                   asUrgent:YES];

  XCTAssertNotNil(self.mockDataTransport.sendDataEvent_event);
}

- (void)testUploadPackagedReportWithoutDataCollectionToken {
  [self.uploader uploadPackagedReportAtPath:[self packagePath] dataCollectionToken:nil asUrgent:NO];

  // Ensure we don't hand off an event to GDT
  XCTAssertNil(self.mockDataTransport.sendDataEvent_event);
}

- (void)testUploadPackagedReportNotGDTWritten {
  self.mockDataTransport.sendDataEvent_wasWritten = NO;

  [self.uploader uploadPackagedReportAtPath:[self packagePath] dataCollectionToken:nil asUrgent:NO];

  // Did not delete report
  XCTAssertNil(self.fileManager.removedItemAtPath_path);
}

- (void)testUploadPackagedReportGDTError {
  self.mockDataTransport.sendDataEvent_error = [[NSError alloc] initWithDomain:@"domain"
                                                                          code:1
                                                                      userInfo:nil];

  [self.uploader uploadPackagedReportAtPath:[self packagePath] dataCollectionToken:nil asUrgent:NO];

  // Did not delete report
  XCTAssertNil(self.fileManager.removedItemAtPath_path);
}

#pragma mark - Helper functions

- (NSString *)packagePath {
  return [self.fileManager.preparedPath stringByAppendingPathComponent:@"pkg_uuid"];
}

- (void)runUploadPackagedReportWithUrgency:(BOOL)urgent {
  [self.uploader uploadPackagedReportAtPath:[self packagePath]
                        dataCollectionToken:FIRCLSDataCollectionToken.validToken
                                   asUrgent:urgent];

  XCTAssertNotNil(self.mockDataTransport.sendDataEvent_event);
  XCTAssertEqualObjects(self.fileManager.removedItemAtPath_path, [self packagePath]);
}

@end
