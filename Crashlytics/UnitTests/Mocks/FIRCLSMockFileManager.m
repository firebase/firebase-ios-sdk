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

#import "FIRCLSMockFileManager.h"

@implementation FIRCLSMockFileManager

@synthesize pathNamespace;

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
  [super removeItemAtPath:path];

  self.removeCount += 1;

  // If we set up the expectation, and we went over the expected count or removes, fulfill the
  // expectation
  if (self.removeExpectation && self.removeCount >= self.expectedRemoveCount) {
    [self.removeExpectation fulfill];
  }

  return YES;
}

@end
