//
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

#import "Crashlytics/Crashlytics/Controllers/FIRCLSContextManager.h"
#import "Crashlytics/Crashlytics/Models/Record/FIRCLSReportAdapter.h"
#import "Crashlytics/Crashlytics/Models/Record/FIRCLSReportAdapter_Private.h"
#import "Crashlytics/Crashlytics/Settings/Models/FIRCLSApplicationIdentifierModel.h"

#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockFileManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockSettings.h"
#import "Crashlytics/UnitTests/Mocks/FIRMockInstallations.h"

NSString *const TestContextReportID = @"TestContextReportID";
NSString *const TestContextSessionID = @"TestContextSessionID";
NSString *const TestContextSessionID2 = @"TestContextSessionID2";

@interface FIRCLSContextManagerTests : XCTestCase

@property(nonatomic, strong) FIRCLSMockFileManager *fileManager;
@property(nonatomic, strong) FIRCLSMockSettings *mockSettings;
@property(nonatomic, strong) FIRCLSContextManager *contextManager;
@property(nonatomic, strong) FIRCLSInternalReport *report;
@property(nonatomic, strong) FIRCLSInstallIdentifierModel *installIDModel;
@end

@implementation FIRCLSContextManagerTests

- (void)setUp {
  self.fileManager = [[FIRCLSMockFileManager alloc] init];
  [self.fileManager createReportDirectories];
  [self.fileManager setupNewPathForExecutionIdentifier:TestContextReportID];

  FIRCLSApplicationIdentifierModel *appIDModel = [[FIRCLSApplicationIdentifierModel alloc] init];
  _mockSettings = [[FIRCLSMockSettings alloc] initWithFileManager:self.fileManager
                                                       appIDModel:appIDModel];

  //  NSString *name = @"exception_model_report";
  NSString *reportPath =
      [self.fileManager.activePath stringByAppendingPathComponent:TestContextReportID];

  self.report = [[FIRCLSInternalReport alloc] initWithPath:reportPath
                                       executionIdentifier:TestContextReportID];

  self.contextManager = [[FIRCLSContextManager alloc] init];

  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:@"test_token"];
  self.installIDModel = [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];
}

- (void)tearDown {
  [[NSFileManager defaultManager] removeItemAtPath:self.fileManager.rootPath error:nil];
  [super tearDown];
}

- (void)test_notSettingSessionID_protoHasNilSessionID {
  [self.contextManager setupContextWithReport:self.report
                                     settings:self.mockSettings
                                  fileManager:self.fileManager];

  FIRCLSReportAdapter *adapter = [[FIRCLSReportAdapter alloc] initWithPath:self.report.path
                                                               googleAppId:@"TestGoogleAppID"
                                                            installIDModel:self.installIDModel
                                                                      fiid:@"TestFIID"
                                                                 authToken:@"TestAuthToken"];

  XCTAssertEqualObjects(adapter.identity.app_quality_session_id, @"");
}

- (void)test_settingSessionIDMultipleTimes_protoHasLastSessionID {
  [self.contextManager setAppQualitySessionId:TestContextSessionID];

  [self.contextManager setupContextWithReport:self.report
                                     settings:self.mockSettings
                                  fileManager:self.fileManager];

  [self.contextManager setAppQualitySessionId:TestContextSessionID2];

  FIRCLSReportAdapter *adapter = [[FIRCLSReportAdapter alloc] initWithPath:self.report.path
                                                               googleAppId:@"TestGoogleAppID"
                                                            installIDModel:self.installIDModel
                                                                      fiid:@"TestFIID"
                                                                 authToken:@"TestAuthToken"];
  NSLog(@"reportPath: %@", self.report.path);

  XCTAssertEqualObjects(adapter.identity.app_quality_session_id, TestContextSessionID2);
}

- (void)test_settingSessionIDOutOfOrder_protoHasLastSessionID {
  [self.contextManager setupContextWithReport:self.report
                                     settings:self.mockSettings
                                  fileManager:self.fileManager];

  [self.contextManager setAppQualitySessionId:TestContextSessionID];

  [self.contextManager setAppQualitySessionId:TestContextSessionID2];

  FIRCLSReportAdapter *adapter = [[FIRCLSReportAdapter alloc] initWithPath:self.report.path
                                                               googleAppId:@"TestGoogleAppID"
                                                            installIDModel:self.installIDModel
                                                                      fiid:@"TestFIID"
                                                                 authToken:@"TestAuthToken"];
  NSLog(@"reportPath: %@", self.report.path);

  XCTAssertEqualObjects(adapter.identity.app_quality_session_id, TestContextSessionID2);
}

@end
