// Copyright 2021 Google LLC
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
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Private/FIRCLSExistingReportManager_Private.h"
#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRCrashlyticsReport.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockReportUploader.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSTempMockFileManager.h"

#define METADATA_FORMAT                                                                        \
  (@"{\"identity\":{\"generator\":\"Crashlytics iOS "                                          \
   @"SDK/"                                                                                     \
   @"7.7.0\",\"display_version\":\"7.7.0\",\"build_version\":\"7.7.0\",\"started_at\":%ld,"    \
   @"\"session_id\":\"%@\",\"install_id\":\"CA3EE845-594A-4AAD-8343-B0379559E5C5\",\"beta_"    \
   @"token\":\"\",\"absolute_log_timestamps\":true}}\n{\"host\":{\"model\":\"iOS Simulator "   \
   @"(iPhone)\",\"machine\":\"x86_64\",\"cpu\":\"Intel(R) Core(TM) i9-9880H CPU @ "            \
   @"2.30GHz\",\"os_build_version\":\"20D74\",\"os_display_version\":\"14.3.0\",\"platform\":" \
   @"\"ios\",\"locale\":\"en_US\"}}\n{\"application\":{\"bundle_id\":\"com.google.firebase."   \
   @"quickstart.TestingNoAWS\",\"custom_bundle_id\":null,\"build_version\":\"131\",\"display_" \
   @"version\":\"10.10.33\",\"extension_id\":null}}\n{\"executable\":{\"architecture\":\"x86_" \
   @"64\",\"uuid\":\"6a082b52b92a36bdb766fda9049deb21\",\"base\":4471803904,\"size\":49152,"   \
   @"\"encrypted\":false,\"minimum_sdk_version\":\"8.0.0\",\"built_sdk_version\":\"14.3.0\"}}")

@interface FIRCLSExistingReportManagerTests : XCTestCase

@property(nonatomic, strong) FIRCLSMockReportUploader *mockReportUploader;
@property(nonatomic, strong) FIRCLSTempMockFileManager *fileManager;
@property(nonatomic, strong) FIRCLSExistingReportManager *existingReportManager;
@property(nonatomic, strong) FIRCLSManagerData *managerData;

@end

@implementation FIRCLSExistingReportManagerTests

- (void)setUp {
  [super setUp];

  FIRCLSContextBaseInit();

  self.fileManager = [[FIRCLSTempMockFileManager alloc] init];

  // Cleanup potential artifacts from other test files.
  if ([[NSFileManager defaultManager] fileExistsAtPath:[self.fileManager rootPath]]) {
    assert([self.fileManager removeItemAtPath:[self.fileManager rootPath]]);
  }

  // Allow nil values only in tests
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  self.managerData = [[FIRCLSManagerData alloc] initWithGoogleAppID:@"TEST_GOOGLE_APP_ID"
                                                    googleTransport:nil
                                                      installations:nil
                                                          analytics:nil
                                                        fileManager:self.fileManager
                                                        dataArbiter:nil
                                                           settings:nil
                                                      onDemandModel:nil];
#pragma clang diagnostic pop

  self.mockReportUploader = [[FIRCLSMockReportUploader alloc] initWithManagerData:self.managerData];
  self.existingReportManager =
      [[FIRCLSExistingReportManager alloc] initWithManagerData:self.managerData
                                                reportUploader:self.mockReportUploader];
}

- (void)tearDown {
  if ([[NSFileManager defaultManager] fileExistsAtPath:[self.fileManager rootPath]]) {
    assert([self.fileManager removeItemAtPath:[self.fileManager rootPath]]);
  }

  FIRCLSContextBaseDeinit();

  [super tearDown];
}

- (NSArray *)contentsOfActivePath {
  return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.fileManager.activePath
                                                             error:nil];
}

#pragma mark - Helpers

- (FIRCLSInternalReport *)createActiveReportWithID:(NSString *)reportID
                                              time:(time_t)time
                                        withEvents:(BOOL)withEvents {
  NSString *reportPath = [self.fileManager.activePath stringByAppendingPathComponent:reportID];
  FIRCLSInternalReport *report = [[FIRCLSInternalReport alloc] initWithPath:reportPath
                                                        executionIdentifier:reportID];

  if (![self.fileManager createDirectoryAtPath:report.path]) {
    return nil;
  }

  NSString *metadata = [NSString stringWithFormat:METADATA_FORMAT, time, reportID];
  if (![self createMetadata:metadata forReport:report]) {
    return nil;
  }

  if (withEvents) {
    [self createCrashExceptionFile:@"Content doesn't matter" forReport:report];
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

- (BOOL)createCrashExceptionFile:(NSString *)value forReport:(FIRCLSInternalReport *)report {
  return [self createFileWithContents:value
                               atPath:[report pathForContentFile:FIRCLSReportExceptionFile]];
}

- (BOOL)reportPathAtIndex:(NSUInteger)index isReportID:(NSString *)reportID {
  return [[self.existingReportManager.existingUnemptyActiveReportPaths objectAtIndex:index]
      containsString:reportID];
}

#pragma mark - Tests

- (void)testNoReports {
  [self.existingReportManager collectExistingReports];

  [self.existingReportManager.operationQueue waitUntilAllOperationsAreFinished];

  // Reports without events should be deleted
  XCTAssertEqual([[self contentsOfActivePath] count], 0, @"Contents of active path: %@",
                 [self contentsOfActivePath]);
  XCTAssertEqual(self.existingReportManager.unsentReportsCount, 0);
  XCTAssertEqual(self.existingReportManager.newestUnsentReport, nil);
  XCTAssertEqual(self.existingReportManager.existingUnemptyActiveReportPaths.count, 0);
}

- (void)testReportNoEvents {
  [self createActiveReportWithID:@"report_A" time:12312 withEvents:NO];
  [self createActiveReportWithID:@"report_B" time:12315 withEvents:NO];

  [self.existingReportManager collectExistingReports];

  [self.existingReportManager.operationQueue waitUntilAllOperationsAreFinished];

  // Reports without events should be deleted
  XCTAssertEqual([[self contentsOfActivePath] count], 0, @"Contents of active path: %@",
                 [self contentsOfActivePath]);
  XCTAssertEqual(self.existingReportManager.unsentReportsCount, 0);
  XCTAssertEqual(self.existingReportManager.newestUnsentReport, nil);
  XCTAssertEqual(self.existingReportManager.existingUnemptyActiveReportPaths.count, 0);
}

- (void)testUnsentReportsUnderLimit {
  [self createActiveReportWithID:@"report_A" time:12312 withEvents:YES];
  [self createActiveReportWithID:@"report_B" time:12315 withEvents:YES];
  [self createActiveReportWithID:@"report_C" time:31533 withEvents:YES];
  [self createActiveReportWithID:@"report_D" time:63263 withEvents:YES];

  [self.existingReportManager collectExistingReports];

  [self.existingReportManager.operationQueue waitUntilAllOperationsAreFinished];

  // Reports with events should be kept if there's less than MAX_UNSENT_REPORTS reports
  XCTAssertEqual([[self contentsOfActivePath] count], FIRCLSMaxUnsentReports,
                 @"Contents of active path: %@", [self contentsOfActivePath]);
  XCTAssertEqual(self.existingReportManager.unsentReportsCount, FIRCLSMaxUnsentReports);
  XCTAssertEqual(self.existingReportManager.existingUnemptyActiveReportPaths.count,
                 FIRCLSMaxUnsentReports);

  // Newest report based on started_at timestamp
  XCTAssertEqualObjects(self.existingReportManager.newestUnsentReport.reportID, @"report_D");
}

/**
 * When we go over the limit of FIRCLSMaxUnsentReports, we delete any reports over the limit to
 * ensure performant startup and prevent disk space from filling up. Delete starting with the oldest
 * first.
 */
- (void)testUnsentReportsOverLimit {
  // Create a bunch of reports starting at different times
  [self createActiveReportWithID:@"report_A" time:12312 withEvents:YES];
  [self createActiveReportWithID:@"report_B" time:12315 withEvents:YES];
  [self createActiveReportWithID:@"report_C" time:31533 withEvents:YES];
  [self createActiveReportWithID:@"report_D" time:63263 withEvents:YES];
  [self createActiveReportWithID:@"report_E" time:33263 withEvents:YES];
  [self createActiveReportWithID:@"report_F" time:43263 withEvents:YES];
  [self createActiveReportWithID:@"report_G" time:77777 withEvents:YES];
  [self createActiveReportWithID:@"report_H" time:13263 withEvents:YES];
  [self createActiveReportWithID:@"report_I" time:61263 withEvents:YES];

  [self.existingReportManager collectExistingReports];

  [self.existingReportManager.operationQueue waitUntilAllOperationsAreFinished];

  // Remove any reports over the limit, starting with the oldest
  XCTAssertEqual([[self contentsOfActivePath] count], FIRCLSMaxUnsentReports,
                 @"Contents of active path: %@", [self contentsOfActivePath]);
  XCTAssertEqual(self.existingReportManager.unsentReportsCount, FIRCLSMaxUnsentReports);
  XCTAssertEqual(self.existingReportManager.existingUnemptyActiveReportPaths.count,
                 FIRCLSMaxUnsentReports);

  // Newest report based on started_at timestamp
  XCTAssertEqualObjects(self.existingReportManager.newestUnsentReport.reportID, @"report_G");

  // Make sure we're sorting correctly and keeping the newest reports.
  XCTAssertEqual([self reportPathAtIndex:0 isReportID:@"report_G"], true);
  XCTAssertEqual([self reportPathAtIndex:1 isReportID:@"report_D"], true);
  XCTAssertEqual([self reportPathAtIndex:2 isReportID:@"report_I"], true);
  XCTAssertEqual([self reportPathAtIndex:3 isReportID:@"report_F"], true);
}

@end
