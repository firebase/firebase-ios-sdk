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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockExistingReportManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Private/FIRCrashlyticsReport_Private.h"
#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRCrashlyticsReport.h"

@interface FIRCLSMockExistingReportManager ()

@property(nonatomic, strong) FIRCLSFileManager *fileManager;
@property(nonatomic) BOOL shouldHaveExistingReport;

@end

@implementation FIRCLSMockExistingReportManager

- (instancetype)initWithManagerData:(FIRCLSManagerData *)managerData
                     reportUploader:(FIRCLSReportUploader *)reportUploader {
  self = [super initWithManagerData:managerData reportUploader:reportUploader];
  if (!self) {
    return nil;
  }

  _fileManager = managerData.fileManager;
  _shouldHaveExistingReport = NO;

  return self;
}

- (FIRCrashlyticsReport *)newestUnsentReport {
  if (!self.shouldHaveExistingReport) return [super newestUnsentReport];
  NSString *reportPath =
      [self.fileManager.activePath stringByAppendingPathComponent:@"my_session_id"];
  FIRCLSInternalReport *report = [[FIRCLSInternalReport alloc] initWithPath:reportPath
                                                        executionIdentifier:@"my_session_id"];
  return [[FIRCrashlyticsReport alloc] initWithInternalReport:report];
}

- (void)setShouldHaveExistingReport {
  self.shouldHaveExistingReport = YES;
}

@end
