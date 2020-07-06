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

// The mock file manager class should not write out to the file system as it causes reliability
// issues in tests. Instead, FIRCLSMockFileManager should be used. This class cannot be removed yet
// because the file system is tightly coupled throughout the SDK code. File system manipulations are
// done through NSFileManager, NSData, NSString and other APIs.
//
// Once the experiment to upload to the new reporting endpoint using GDT is complete,
// old legacy classes and logic (ie FIRCLSInternalReport, FIRCLSPackageReportsOperation) used for
// processing reports can be removed. At that point, this mock class should be removed.

#import "Crashlytics/UnitTests/Mocks/FIRCLSTempMockFileManager.h"

@implementation FIRCLSTempMockFileManager

- (instancetype)init {
  self = [super init];
  if (!self) {
    return nil;
  }

  // Should be set by the tests when needed
  _removeExpectation = nil;

  return self;
}

- (BOOL)removeItemAtPath:(NSString *)path {
  self.removedItemAtPath_path = path;

  [super removeItemAtPath:path];

  self.removeCount += 1;

  // If we set up the expectation, and we went over the expected count or removes, fulfill the
  // expectation
  if (self.removeExpectation && self.removeCount >= self.expectedRemoveCount) {
    [self.removeExpectation fulfill];
  }

  return YES;
}

- (NSNumber *)fileSizeAtPath:(NSString *)path {
  if (self.fileSizeAtPathResult != nil) {
    return self.fileSizeAtPathResult;
  }

  return [super fileSizeAtPath:path];
}

- (BOOL)moveItemAtPath:(NSString *)path toDirectory:(NSString *)destDir {
  self.moveItemAtPath_path = path;
  self.moveItemAtPath_destDir = destDir;

  if (self.moveItemAtPathResult != nil) {
    return self.moveItemAtPathResult.intValue > 0;
  }

  return [super moveItemAtPath:path toDirectory:destDir];
}

@end
