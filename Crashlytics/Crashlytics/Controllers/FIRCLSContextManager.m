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

#import "Crashlytics/Crashlytics/Controllers/FIRCLSContextManager.h"

#import "Crashlytics/Crashlytics/Components/FIRCLSContext.h"

@interface FIRCLSContextManager ()

@property(nonatomic, assign) BOOL hasInitializedContext;

@property(nonatomic, strong) FIRCLSInternalReport *report;
@property(nonatomic, strong) FIRCLSSettings *settings;
@property(nonatomic, strong) FIRCLSFileManager *fileManager;

@end

@implementation FIRCLSContextManager

- (instancetype)init {
  self = [super init];
  if (!self) {
    return self;
  }

  _appQualitySessionId = @"";

  return self;
}

- (BOOL)setupContextWithReport:(FIRCLSInternalReport *)report
                      settings:(FIRCLSSettings *)settings
                   fileManager:(FIRCLSFileManager *)fileManager {
  _report = report;
  _settings = settings;
  _fileManager = fileManager;

  _hasInitializedContext = true;

  FIRCLSContextInitData initDataObj = self.buildInitData;
  return FIRCLSContextInitialize(&initDataObj, self.fileManager);
}

- (void)setAppQualitySessionId:(NSString *)appQualitySessionId {
  _appQualitySessionId = appQualitySessionId;

  // This may be called before the context is originally initialized. In that case
  // skip the write because it will be written as soon as the context is initialized.
  // On future Session ID updates, this will be true and the context metadata will be
  // rewritten.
  if (!self.hasInitializedContext) {
    return;
  }

  FIRCLSContextInitData initDataObj = self.buildInitData;
  if (!FIRCLSContextRecordMetadata(self.report.path, &initDataObj)) {
    FIRCLSErrorLog(@"Failed to write context file while updating App Quality Session ID");
  }
}

- (FIRCLSContextInitData)buildInitData {
  return FIRCLSContextBuildInitData(self.report, self.settings, self.fileManager,
                                    self.appQualitySessionId);
}

@end
