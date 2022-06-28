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

#import "FIRCLSSharedContext.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockFileManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockSettings.h"
#import "Crashlytics/UnitTests/Mocks/FABMockApplicationIdentifierModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Components/FIRCLSContext.h"

@implementation FIRCLSSharedContext

- (instancetype)initWithFileManager:(FIRCLSMockFileManager *)fileManager
                       mockSettings:(FIRCLSMockSettings *)mockSettings
                         reportPath:(NSString *)reportPath {
  self = [super init];
  _mockSettings = mockSettings;
  _fileManager = fileManager;
  _reportPath = reportPath;
  return self;
}

+ (instancetype)shared
{
  static FIRCLSSharedContext *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    FABMockApplicationIdentifierModel *appIDModel = [[FABMockApplicationIdentifierModel alloc] init];
    FIRCLSMockFileManager *fileManager = [[FIRCLSMockFileManager alloc] init];
    FIRCLSMockSettings *settings = [[FIRCLSMockSettings alloc] initWithFileManager:fileManager
                                                                        appIDModel:appIDModel];
    NSString *name = @"exception_model_report";
    NSString *reportPath = [fileManager.rootPath stringByAppendingPathComponent:name];
    [fileManager createDirectoryAtPath:reportPath];

    FIRCLSInternalReport *report = [[FIRCLSInternalReport alloc] initWithPath:reportPath
                                                          executionIdentifier:@"TEST_EXECUTION_IDENTIFIER"];

    FIRCLSContextInitialize(report, settings, fileManager);
    sharedInstance = [[FIRCLSSharedContext alloc] initWithFileManager:fileManager
                                                         mockSettings:settings
                                                           reportPath:reportPath];
  });
  return sharedInstance;
}

- (void)reset {
  [self.fileManager reset];
  [self.fileManager createDirectoryAtPath:self.reportPath];
}

@end
