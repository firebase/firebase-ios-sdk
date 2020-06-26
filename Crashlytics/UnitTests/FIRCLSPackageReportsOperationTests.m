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

#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"
#import "Crashlytics/Crashlytics/Operations/Reports/FIRCLSPackageReportOperation.h"
#import "Crashlytics/UnitTests/Mocks/FABMockApplicationIdentifierModel.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockSettings.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSTempMockFileManager.h"

NSString *const TestOrgID = @"TestOrgID";

@interface FIRCLSPackageReportsOperationTests : XCTestCase

@property(nonatomic, strong) FIRCLSFileManager *fileManager;
@property(nonatomic, strong) FIRCLSMockSettings *settings;

@property(nonatomic, copy) NSString *packagedPath;
@property(nonatomic, copy) NSString *reportPath;

@end

@implementation FIRCLSPackageReportsOperationTests

- (void)setUp {
  [super setUp];

  FABMockApplicationIdentifierModel *appIDModel = [[FABMockApplicationIdentifierModel alloc] init];
  self.settings = [[FIRCLSMockSettings alloc] initWithFileManager:self.fileManager
                                                       appIDModel:appIDModel];

  FIRCLSTempMockFileManager *manager = [[FIRCLSTempMockFileManager alloc] init];

  self.fileManager = manager;

  assert([manager createReportDirectories]);
}

- (void)tearDown {
  NSFileManager *fileManager = [NSFileManager defaultManager];

  [fileManager removeItemAtPath:self.packagedPath error:nil];
  [fileManager removeItemAtPath:self.reportPath error:nil];

  [super tearDown];
}

- (void)testBasicPackaging {
  // Mock the Organization ID because we will not package reports without one
  self.settings.orgID = TestOrgID;

  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *reportPath =
      [NSTemporaryDirectory() stringByAppendingPathComponent:@"execution_identifier"];
  FIRCLSInternalReport *report =
      [[FIRCLSInternalReport alloc] initWithPath:reportPath
                             executionIdentifier:@"execution_identifier"];

  assert(report.identifier);

  // create the directory path
  assert([self.fileManager createDirectoryAtPath:[report path]]);

  // put some test files in it
  XCTAssertTrue([fileManager createFileAtPath:[report pathForContentFile:@"file1.txt"]
                                     contents:[@"contents" dataUsingEncoding:NSUTF8StringEncoding]
                                   attributes:nil],
                @"");
  XCTAssertTrue([fileManager createFileAtPath:[report pathForContentFile:@"file2.txt"]
                                     contents:[@"contents" dataUsingEncoding:NSUTF8StringEncoding]
                                   attributes:nil],
                @"");

  // and now generate a valid metadata file and put that in place too
  NSData *metadataData =
      [@"{\"identity\":{\"api_key\":\"my_key\",\"session_id\":\"my_session_id\"}}\n"
          dataUsingEncoding:NSUTF8StringEncoding];

  XCTAssertTrue([fileManager createFileAtPath:[report metadataPath]
                                     contents:metadataData
                                   attributes:nil],
                @"");

  // Now, actually run the operation
  FIRCLSPackageReportOperation *packageOperation =
      [[FIRCLSPackageReportOperation alloc] initWithReport:report
                                               fileManager:self.fileManager
                                                  settings:self.settings];

  [packageOperation start];

  self.packagedPath = [packageOperation finalPath];
  self.reportPath = [report path];

  // And verify the results
  XCTAssertNotNil(self.packagedPath, @"Packaging should succeed");

  XCTAssertTrue([fileManager fileExistsAtPath:self.reportPath],
                @"The original report directory should not be removed");
  XCTAssertTrue([fileManager fileExistsAtPath:self.packagedPath],
                @"The multipart mime structure should be present");
}

- (void)testPackagingNoOrgID {
  // Mock the Organization ID because we will not package reports without one
  self.settings.orgID = nil;

  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *reportPath =
      [NSTemporaryDirectory() stringByAppendingPathComponent:@"execution_identifier"];
  FIRCLSInternalReport *report =
      [[FIRCLSInternalReport alloc] initWithPath:reportPath
                             executionIdentifier:@"execution_identifier"];

  // Now, actually run the operation
  FIRCLSPackageReportOperation *packageOperation =
      [[FIRCLSPackageReportOperation alloc] initWithReport:report
                                               fileManager:self.fileManager
                                                  settings:self.settings];

  [packageOperation start];

  self.packagedPath = [packageOperation finalPath];
  self.reportPath = [report path];

  // And verify the results
  XCTAssertNil(self.packagedPath, @"Packaging should fail");

  XCTAssertFalse([fileManager fileExistsAtPath:self.reportPath],
                 @"The original report directory should be removed");
  XCTAssertFalse([fileManager fileExistsAtPath:self.packagedPath],
                 @"The multipart mime structure should be present");
}

@end
