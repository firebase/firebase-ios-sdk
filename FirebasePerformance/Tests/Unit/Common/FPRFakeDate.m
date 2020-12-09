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

#import "FirebasePerformance/Tests/Unit/Common/FPRFakeDate.h"

@interface FPRFakeDate ()

// The date that will be reported for but the -now method.
@property(nonatomic) NSDate *currentDate;

@end

@implementation FPRFakeDate

- (instancetype)init {
  self = [super init];
  if (self) {
    _currentDate = [NSDate dateWithTimeIntervalSince1970:0];
  }
  return self;
}

- (NSDate *)now {
  return self.currentDate;
}

- (NSTimeInterval)timeIntervalSinceDate:(NSDate *)date {
  return [self.now timeIntervalSinceDate:date];
}

- (void)incrementTime:(NSTimeInterval)interval {
  [self setCurrentDate:[[self currentDate] dateByAddingTimeInterval:interval]];
}

@end
