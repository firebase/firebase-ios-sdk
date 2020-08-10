// Copyright 2020 Google LLC
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

#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRExceptionModel.h"
#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRStackFrame.h"

#import "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInstallIdentifierModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/UnitTests/Mocks/FABMockApplicationIdentifierModel.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockFileManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockSettings.h"
#import "Crashlytics/UnitTests/Mocks/FIRMockInstallations.h"

#define TEST_BUNDLE_ID (@"com.crashlytics.test")

@interface FIRRecordExceptionModelTests : XCTestCase

@property(nonatomic, strong) FIRCLSMockFileManager *fileManager;
@property(nonatomic, strong) FIRCLSMockSettings *mockSettings;
@property(nonatomic, strong) NSString *reportPath;

@end

@implementation FIRRecordExceptionModelTests

- (void)setUp {
  self.fileManager = [[FIRCLSMockFileManager alloc] init];

  FABMockApplicationIdentifierModel *appIDModel = [[FABMockApplicationIdentifierModel alloc] init];
  self.mockSettings = [[FIRCLSMockSettings alloc] initWithFileManager:self.fileManager
                                                           appIDModel:appIDModel];

  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:@"test_instance_id"];

  FIRCLSInstallIdentifierModel *installIDModel =
      [[FIRCLSInstallIdentifierModel alloc] initWithInstallations:iid];

  NSString *name = @"exception_model_report";
  self.reportPath = [self.fileManager.rootPath stringByAppendingPathComponent:name];
  [self.fileManager createDirectoryAtPath:self.reportPath];

  FIRCLSInternalReport *report =
      [[FIRCLSInternalReport alloc] initWithPath:self.reportPath
                             executionIdentifier:@"TEST_EXECUTION_IDENTIFIER"];

  FIRCLSContextInitialize(report, self.mockSettings, installIDModel, self.fileManager);
}

- (void)tearDown {
  [[NSFileManager defaultManager] removeItemAtPath:self.fileManager.rootPath error:nil];
}

- (void)testWrittenCLSRecordFile {
  NSArray *stackTrace = @[
    [FIRStackFrame stackFrameWithSymbol:@"CrashyFunc" file:@"AppLib.m" line:504],
    [FIRStackFrame stackFrameWithSymbol:@"ApplicationMain" file:@"AppleLib" line:1],
    [FIRStackFrame stackFrameWithSymbol:@"main()" file:@"main.m" line:201],
  ];
  NSString *name = @"FIRExceptionModelTestsCrash";
  NSString *reason = @"Programmer made an error";

  FIRExceptionModel *exceptionModel = [FIRExceptionModel exceptionModelWithName:name reason:reason];
  exceptionModel.stackTrace = stackTrace;

  FIRCLSExceptionRecordModel(exceptionModel);

  NSData *data = [NSData
      dataWithContentsOfFile:[self.reportPath
                                 stringByAppendingPathComponent:@"custom_exception_a.clsrecord"]];
  NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
  NSDictionary *exception = json[@"exception"];
  NSArray *frames = exception[@"frames"];
  XCTAssertEqualObjects(exception[@"name"],
                        @"464952457863657074696f6e4d6f64656c54657374734372617368");
  XCTAssertEqualObjects(exception[@"reason"], @"50726f6772616d6d6572206d61646520616e206572726f72");
  XCTAssertEqual(frames.count, 3);
  XCTAssertEqualObjects(frames[2][@"file"], @"6d61696e2e6d");
  XCTAssertEqual([frames[2][@"line"] intValue], 201);
  XCTAssertEqual([frames[2][@"offset"] intValue], 0);
  XCTAssertEqual([frames[2][@"pc"] intValue], 0);
  XCTAssertEqualObjects(frames[2][@"symbol"], @"6d61696e2829");
}

@end
