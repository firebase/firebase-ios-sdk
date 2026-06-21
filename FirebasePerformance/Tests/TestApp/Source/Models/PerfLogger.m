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

// Non-google3 relative import to support building with Xcode.
#import "PerfLogger.h"

static NSString *const kPerfLogPrefix = @"PerfTestAppLog_";

@implementation PerfLogger

#pragma mark - Initialization

+ (instancetype)sharedInstance {
  static PerfLogger *logger = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    logger = [[self alloc] init];
  });
  return logger;
}

#pragma mark - Public methods

- (void)log:(NSString *)string {
  NSLog(@"%@%@", kPerfLogPrefix, string);
}

@end
