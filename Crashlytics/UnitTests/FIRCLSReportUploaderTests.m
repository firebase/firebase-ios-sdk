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
#include "FIRCLSDefines.h"
#include "FIRCLSFileManager.h"
#include "FIRCLSMockSettings.h"
#include "FIRCLSSettings.h"
#include "FIRMockGDTCoreTransport.h"

NSString *const TestEndpoint = @"https://reports.crashlytics.com";

@interface FIRCLSReportUploaderTests
    : XCTestCase <FIRCLSReportUploaderDelegate, FIRCLSReportUploaderDataSource>

@property(nonatomic, strong) FIRCLSReportUploader *uploader;
@property(nonatomic, strong) FIRCLSFileManager *fileManager;
@property(nonatomic, strong) NSOperationQueue *queue;
@property(nonatomic, strong) NSURL *url;

@end

@implementation FIRCLSReportUploaderTests

- (void)setUp {
  [super setUp];

  self.queue = [NSOperationQueue new];

  self.fileManager = [[FIRCLSFileManager alloc] init];
  self.uploader = [[FIRCLSReportUploader alloc] initWithQueue:self.queue
                                                     delegate:self
                                                   dataSource:self
                                                       client:nil
                                                  fileManager:nil
                                                    analytics:nil];

  // glue together a string that will work for both platforms
  NSString *urlString =
      [NSString stringWithFormat:@"%@/sdk-api/v1/platforms/%@/apps/%@/reports", TestEndpoint,
                                 FIRCLSApplicationGetPlatform(), self.bundleIdentifier];
  self.url = [NSURL URLWithString:urlString];
}

- (void)tearDown {
  self.uploader = nil;

  [super tearDown];
}

- (void)testURLGeneration {
  XCTAssertEqualObjects([self.uploader reportURL], _url);
}

#pragma mark - FIRCLSReportUploaderDelegate

- (void)didCompletePackageSubmission:(NSString *)path
                 dataCollectionToken:(FIRCLSDataCollectionToken *)token
                               error:(NSError *)error {
}

- (NSString *)bundleIdentifier {
  return @"com.test.TestApp";
}

- (NSString *)googleAppID {
  return @"someGoogleAppId";
}

- (FIRCLSSettings *)settings {
  FABMockApplicationIdentifierModel *appIDModel = [[FABMockApplicationIdentifierModel alloc] init];
  FIRCLSMockSettings *settings = [[FIRCLSMockSettings alloc] initWithFileManager:self.fileManager
                                                                      appIDModel:appIDModel];
  settings.fetchedBundleID = self.bundleIdentifier;
  return settings;
}

- (GDTCORTransport *)googleTransport {
  return [[FIRMockGDTCORTransport alloc] initWithMappingID:@"mappingID" transformers:nil target:0];
}

- (void)didCompleteAllSubmissions {
}

@end
