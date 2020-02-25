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

#import "FIRCLSReportUploader_Private.h"

#import "FABMockApplicationIdentifierModel.h"
#import "FIRCLSApplication.h"
#include "FIRCLSConstants.h"
#include "FIRCLSDataCollectionToken.h"
#include "FIRCLSDefines.h"
#include "FIRCLSFileManager.h"
#include "FIRCLSMockFileManager.h"
#include "FIRCLSMockNetworkClient.h"
#include "FIRCLSMockSettings.h"
#include "FIRCLSSettings.h"
#include "FIRMockGDTCoreTransport.h"

NSString *const TestEndpoint = @"https://reports.crashlytics.com";

@interface FIRCLSReportUploaderTests
    : XCTestCase <FIRCLSReportUploaderDelegate, FIRCLSReportUploaderDataSource>

@property(nonatomic, strong) FIRCLSReportUploader *uploader;
@property(nonatomic, strong) FIRCLSMockFileManager *fileManager;
@property(nonatomic, strong) FIRMockGDTCORTransport *dataTransport;
@property(nonatomic, strong) NSOperationQueue *queue;
@property(nonatomic, strong) FIRCLSMockSettings *settings;
@property(nonatomic, strong) FIRCLSMockNetworkClient *networkClient;

@end

@implementation FIRCLSReportUploaderTests

- (void)setUp {
  [super setUp];

  FABMockApplicationIdentifierModel *appIDModel = [[FABMockApplicationIdentifierModel alloc] init];
  self.settings = [[FIRCLSMockSettings alloc] initWithFileManager:self.fileManager
                                                       appIDModel:appIDModel];
  self.settings.fetchedBundleID = self.bundleIdentifier;

  self.queue = [NSOperationQueue new];

  self.networkClient = [[FIRCLSMockNetworkClient alloc] initWithQueue:self.queue
                                                          fileManager:self.fileManager
                                                             delegate:nil];

  self.fileManager = [[FIRCLSMockFileManager alloc] init];
  self.uploader = [[FIRCLSReportUploader alloc] initWithQueue:self.queue
                                                     delegate:self
                                                   dataSource:self
                                                       client:self.networkClient
                                                  fileManager:self.fileManager
                                                    analytics:nil];

  self.dataTransport = [[FIRMockGDTCORTransport alloc] initWithMappingID:@"mappingID"
                                                            transformers:nil
                                                                  target:1206];
}

- (void)tearDown {
  self.uploader = nil;

  [super tearDown];
}

- (void)testURLGeneration {
  NSString *urlString =
      [NSString stringWithFormat:@"%@/sdk-api/v1/platforms/%@/apps/%@/reports", TestEndpoint,
                                 FIRCLSApplicationGetPlatform(), self.bundleIdentifier];
  NSURL *url = [NSURL URLWithString:urlString];

  XCTAssertEqualObjects([self.uploader reportURL], url);
}

- (void)testUploadPackagedReportWithPath {
  NSString *packagePath =
      [self.fileManager.preparedPath stringByAppendingPathComponent:@"pkg_uuid"];
  self.settings.shouldUseNewReportEndpoint = YES;
  self.dataTransport.sendDataEvent_wasWritten = YES;

  BOOL success = [self.uploader uploadPackagedReportAtPath:packagePath
                                       dataCollectionToken:FIRCLSDataCollectionToken.validToken
                                                  asUrgent:NO];
  XCTAssertTrue(success);
  XCTAssertNotNil(self.dataTransport.sendDataEvent_event);
  XCTAssertNil(self.networkClient.startUploadRequest);
}

- (void)testUploadPackagedReportWithLegacyPath {
  NSString *packagePath =
      [self.fileManager.legacyPreparedPath stringByAppendingPathComponent:@"pkg_uuid"];
  self.settings.shouldUseNewReportEndpoint = NO;
  self.dataTransport.sendDataEvent_wasWritten = YES;
  self.fileManager.overridenFileSizeAtPath = [NSNumber numberWithInt:1];

  BOOL success = [self.uploader uploadPackagedReportAtPath:packagePath
                                       dataCollectionToken:FIRCLSDataCollectionToken.validToken
                                                  asUrgent:NO];
  XCTAssertTrue(success);
  XCTAssertNil(self.dataTransport.sendDataEvent_event);
  XCTAssertNotNil(self.networkClient.startUploadRequest);
}

- (void)testUploadPackagedReportWithMismatchPathAndSettings {
  NSString *packagePath = @"/some/unknown/path/pkg_uuid";
  self.settings.shouldUseNewReportEndpoint = NO;
  self.dataTransport.sendDataEvent_wasWritten = YES;
  self.fileManager.overridenFileSizeAtPath = [NSNumber numberWithInt:1];

  BOOL success = [self.uploader uploadPackagedReportAtPath:packagePath
                                       dataCollectionToken:FIRCLSDataCollectionToken.validToken
                                                  asUrgent:NO];
  XCTAssertFalse(success);
  XCTAssertNil(self.dataTransport.sendDataEvent_event);
  XCTAssertNil(self.networkClient.startUploadRequest);
}

// Add sync vs async
// Check data collection

#pragma mark - FIRCLSReportUploaderDelegate

- (void)didCompletePackageSubmission:(NSString *)path
                 dataCollectionToken:(FIRCLSDataCollectionToken *)token
                               error:(NSError *)error {
}

#pragma mark - FIRCLSReportUploaderDataSource

- (NSString *)bundleIdentifier {
  return @"com.test.TestApp";
}

- (NSString *)googleAppID {
  return @"someGoogleAppId";
}

- (void)didCompleteAllSubmissions {
}

@end
