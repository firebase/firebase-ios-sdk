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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockOnDemandModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"

@interface FIRCLSMockOnDemandModel ()

@property(nonatomic, readonly) FIRCLSSettings *settings;
@property(nonatomic, readonly) FIRCLSFileManager *fileManager;

@end

@implementation FIRCLSMockOnDemandModel

- (instancetype)initWithFIRCLSSettings:(FIRCLSSettings *)settings
                           fileManager:(FIRCLSFileManager *)fileManager
                            sleepBlock:(void (^)(int))sleepBlock {
  self = [super initWithFIRCLSSettings:settings fileManager:fileManager];
  if (!self) {
    return nil;
  }
  _settings = settings;
  _fileManager = fileManager;
  _sleepBlock = sleepBlock;
  return self;
}
- (void)setQueueToFull {
  [self setQueuedOperationsCount:self.settings.onDemandUploadRate];
}

- (void)setQueueToEmpty {
  [self setQueuedOperationsCount:0];
}

- (int)getQueueMax {
  return self.settings.onDemandUploadRate;
}

- (void)implementOnDemandUploadDelay:(int)delay {
  _sleepBlock(delay);
}

- (NSString *)recordOnDemandExceptionWithModel:(FIRExceptionModel *)exceptionModel {
  int randomSuffix = arc4random_uniform(10000);
  NSString *activePath = [_fileManager activePath];
  NSString *exceptionName =
      [activePath stringByAppendingPathComponent:[NSString stringWithFormat:@"test_exception_%d",
                                                                            randomSuffix]];
  NSData *data = [exceptionName dataUsingEncoding:NSUTF8StringEncoding];
  [self.fileManager createFileAtPath:exceptionName contents:data attributes:nil];
  return exceptionName;
}

@end
