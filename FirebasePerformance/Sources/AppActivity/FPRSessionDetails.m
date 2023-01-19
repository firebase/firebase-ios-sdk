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

#import "FirebasePerformance/Sources/AppActivity/FPRSessionDetails.h"

@interface FPRSessionDetails ()

/** @brief Time at which the session was created. */
@property(nonatomic) NSDate *sessionCreationTime;

@end

@implementation FPRSessionDetails

- (instancetype)initWithSessionId:(NSString *)sessionId options:(FPRSessionOptions)options {
  self = [super init];
  if (self) {
    _sessionId = sessionId;
    _options = options;
    _sessionCreationTime = [NSDate date];
  }
  return self;
}

- (FPRSessionDetails *)copyWithZone:(NSZone *)zone {
  FPRSessionDetails *detailsCopy = [[[self class] allocWithZone:zone] initWithSessionId:_sessionId
                                                                                options:_options];
  detailsCopy.sessionCreationTime = _sessionCreationTime;
  return detailsCopy;
}

- (NSUInteger)sessionLengthInMinutesFromDate:(NSDate *)now {
  NSTimeInterval sessionLengthInSeconds = ABS([now timeIntervalSinceDate:self.sessionCreationTime]);
  return (NSUInteger)(sessionLengthInSeconds / 60);
}

- (BOOL)isEqual:(FPRSessionDetails *)detailsObject {
  if (self.sessionId == detailsObject.sessionId) {
    return YES;
  }
  return NO;
}

- (BOOL)isVerbose {
  return (self.options > FPRSessionOptionsNone);
}

@end
