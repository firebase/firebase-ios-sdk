/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseInAppMessaging/Sources/Util/FIRIAMElapsedTimeTracker.h"
@interface FIRIAMElapsedTimeTracker ()
@property(nonatomic) NSTimeInterval totalTrackedTimeSoFar;
@property(nonatomic) NSTimeInterval lastTrackingStartPoint;
@property(nonatomic, nonnull) id<FIRIAMTimeFetcher> timeFetcher;
@property(nonatomic) BOOL tracking;
@end

@implementation FIRIAMElapsedTimeTracker

- (NSTimeInterval)trackedTimeSoFar {
  if (_tracking) {
    return self.totalTrackedTimeSoFar + [self.timeFetcher currentTimestampInSeconds] -
           self.lastTrackingStartPoint;
  } else {
    return self.totalTrackedTimeSoFar;
  }
}

- (void)pause {
  self.tracking = NO;
  self.totalTrackedTimeSoFar +=
      [self.timeFetcher currentTimestampInSeconds] - self.lastTrackingStartPoint;
}

- (void)resume {
  self.tracking = YES;
  self.lastTrackingStartPoint = [self.timeFetcher currentTimestampInSeconds];
}

- (instancetype)initWithTimeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher {
  if (self = [super init]) {
    _tracking = YES;
    _timeFetcher = timeFetcher;
    _totalTrackedTimeSoFar = 0;
    _lastTrackingStartPoint = [timeFetcher currentTimestampInSeconds];
  }
  return self;
}
@end

#endif  // TARGET_OS_IOS
