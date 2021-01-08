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

#import "Crashlytics/Crashlytics/Controllers/FIRCLSReportUploader_Private.h"

#import "Crashlytics/Crashlytics/Components/FIRCLSApplication.h"
#include "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionToken.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSDefines.h"
#include "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#include "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#include "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"
#include "Crashlytics/Shared/FIRCLSConstants.h"
#import "Crashlytics/UnitTests/Mocks/FABMockApplicationIdentifierModel.h"
#include "Crashlytics/UnitTests/Mocks/FIRCLSMockSettings.h"
#include "Crashlytics/UnitTests/Mocks/FIRCLSTempMockFileManager.h"
#include "Crashlytics/UnitTests/Mocks/FIRMockGDTCoreTransport.h"

NSString *const TestEndpoint = @"https://reports.crashlytics.com";

@interface FIRCLSReportUploaderTests : XCTestCase <FIRCLSReportUploaderDataSource>

@property(nonatomic, strong) FIRCLSReportUploader *uploader;
@property(nonatomic, strong) FIRCLSTempMockFileManager *fileManager;
@property(nonatomic, strong) NSOperationQueue *queue;

// Add mock prefix to names as there are naming conflicts with FIRCLSReportUploaderDelegate
@property(nonatomic, strong) FIRMockGDTCORTransport *mockDataTransport;
@property(nonatomic, strong) FIRCLSMockSettings *mockSettings;

@end

@implementation FIRCLSReportUploaderTests

- (void)setUp {
  [super setUp];

  FABMockApplicationIdentifierModel *appIDModel = [[FABMockApplicationIdentifierModel alloc] init];
  self.queue = [NSOperationQueue new];
  self.mockSettings = [[FIRCLSMockSettings alloc] initWithFileManager:self.fileManager
                                                           appIDModel:appIDModel];

  self.fileManager = [[FIRCLSTempMockFileManager alloc] init];
  self.uploader = [[FIRCLSReportUploader alloc] initWithQueue:self.queue
                                                   dataSource:self
                                                  fileManager:self.fileManager
                                                    analytics:nil];
  self.mockDataTransport = [[FIRMockGDTCORTransport alloc] initWithMappingID:@"1206"
                                                                transformers:nil
                                                                      target:kGDTCORTargetCSH];
}

- (void)tearDown {
  self.uploader = nil;

  [super tearDown];
}

#pragma mark - Tests

- (void)testPrepareReport {
  NSString *path = [self.fileManager.activePath stringByAppendingPathComponent:@"pkg_uuid"];
  FIRCLSInternalReport *report = [[FIRCLSInternalReport alloc] initWithPath:path];
  self.fileManager.moveItemAtPathResult = [NSNumber numberWithInt:1];

  [self.uploader prepareAndSubmitReport:report
                    dataCollectionToken:FIRCLSDataCollectionToken.validToken
                               asUrgent:YES
                         withProcessing:YES];

  // Verify with the last move operation is from processing -> prepared
  XCTAssertTrue(
      [self.fileManager.moveItemAtPath_destDir containsString:self.fileManager.preparedPath]);
}

- (void)testUploadPackagedReportWithPath {
  [self runUploadPackagedReportWithUrgency:NO];
}

- (void)testUrgentUploadPackagedReportWithPath {
  [self runUploadPackagedReportWithUrgency:YES];
}

- (void)testUploadPackagedReportWithoutDataCollectionToken {
  [self setUpForUpload];

  [self.uploader uploadPackagedReportAtPath:[self packagePath] dataCollectionToken:nil asUrgent:NO];

  // Ensure we don't hand off an event to GDT
  XCTAssertNil(self.mockDataTransport.sendDataEvent_event);
}

- (void)testUploadPackagedReportNotGDTWritten {
  [self setUpForUpload];
  self.mockDataTransport.sendDataEvent_wasWritten = NO;

  [self.uploader uploadPackagedReportAtPath:[self packagePath] dataCollectionToken:nil asUrgent:NO];

  // Did not delete report
  XCTAssertNil(self.fileManager.removedItemAtPath_path);
}

- (void)testUploadPackagedReportGDTError {
  [self setUpForUpload];
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
  [self setUpForUpload];

  [self.uploader uploadPackagedReportAtPath:[self packagePath]
                        dataCollectionToken:FIRCLSDataCollectionToken.validToken
                                   asUrgent:urgent];

  XCTAssertNotNil(self.mockDataTransport.sendDataEvent_event);
  XCTAssertEqualObjects(self.fileManager.removedItemAtPath_path, [self packagePath]);
}

- (void)setUpForUpload {
  self.mockDataTransport.sendDataEvent_wasWritten = YES;
}

#pragma mark - FIRCLSReportUploaderDataSource

- (NSString *)bundleIdentifier {
  return @"com.test.TestApp";
}

- (NSString *)googleAppID {
  return @"someGoogleAppId";
}

- (GDTCORTransport *)googleTransport {
  return self.mockDataTransport;
}

- (FIRCLSSettings *)settings {
  return self.mockSettings;
}

- (void)didCompleteAllSubmissions {
}

@end
