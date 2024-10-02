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

#import <XCTest/XCTest.h>

#import "FirebasePerformance/Sources/AppActivity/FPRTraceBackgroundActivityTracker.h"

@interface FPRTraceBackgroundActivityTrackerTest : XCTestCase

@end

@implementation FPRTraceBackgroundActivityTrackerTest

/** Validate instance creation. */
- (void)testInstanceCreation {
  XCTAssertNotNil([[FPRTraceBackgroundActivityTracker alloc] init]);
}

/** Validates if the foreground state is captured correctly. */
- (void)testForegroundTracking {
  FPRTraceBackgroundActivityTracker *tracker = [[FPRTraceBackgroundActivityTracker alloc] init];
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];
  XCTAssertEqual(tracker.traceBackgroundState, FPRTraceStateForegroundOnly);
}

/** Validates if the foreground & background state is captured correctly. */
- (void)testBackgroundTracking {
  FPRTraceBackgroundActivityTracker *tracker = [[FPRTraceBackgroundActivityTracker alloc] init];
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationDidEnterBackgroundNotification
                               object:[UIApplication sharedApplication]];
  XCTAssertEqual(tracker.traceBackgroundState, FPRTraceStateBackgroundAndForeground);
}

@end
