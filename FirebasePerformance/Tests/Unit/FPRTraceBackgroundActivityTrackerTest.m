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
  XCTestExpectation *expectation = [self expectationWithDescription:@"Application state change"];

  FPRTraceBackgroundActivityTracker *tracker = [[FPRTraceBackgroundActivityTracker alloc] init];
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  dispatch_async(dispatch_get_main_queue(), ^{
    [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                                 object:[UIApplication sharedApplication]];
    [defaultCenter postNotificationName:UIApplicationDidEnterBackgroundNotification
                                 object:[UIApplication sharedApplication]];
    [expectation fulfill];
  });

  [self waitForExpectationsWithTimeout:5.0
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation failed with error: %@", error);
                                 } else {
                                   XCTAssertEqual(tracker.traceBackgroundState,
                                                  FPRTraceStateBackgroundAndForeground);
                                 }
                               }];
}

/** Tests that synchronous observer registration works correctly and observers are immediately
 * available. */
- (void)testObservers_synchronousRegistrationAddsObserver {
  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  FPRTraceBackgroundActivityTracker *tracker = [[FPRTraceBackgroundActivityTracker alloc] init];
  XCTAssertNotNil(tracker);

  [notificationCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                                    object:[UIApplication sharedApplication]];
  XCTAssertEqual(tracker.traceBackgroundState, FPRTraceStateForegroundOnly);

  tracker = nil;
  XCTAssertNil(tracker);
  XCTAssertNoThrow([notificationCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                                                     object:[UIApplication sharedApplication]]);
  XCTAssertNoThrow([notificationCenter
      postNotificationName:UIApplicationDidEnterBackgroundNotification
                    object:[UIApplication sharedApplication]]);
}

/** Tests rapid creation and deallocation to verify race condition. */
- (void)testRapidCreationAndDeallocation_noRaceCondition {
  for (int i = 0; i < 100; i++) {
    @autoreleasepool {
      FPRTraceBackgroundActivityTracker *tracker = [[FPRTraceBackgroundActivityTracker alloc] init];
      XCTAssertNotNil(tracker);

      [[NSNotificationCenter defaultCenter]
          postNotificationName:UIApplicationDidBecomeActiveNotification
                        object:[UIApplication sharedApplication]];
    }
  }

  XCTAssertNoThrow([[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationDidBecomeActiveNotification
                    object:[UIApplication sharedApplication]]);
  XCTAssertNoThrow([[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationDidEnterBackgroundNotification
                    object:[UIApplication sharedApplication]]);
}

/** Tests observer registration when created from background thread. */
- (void)testObservers_registrationFromBackgroundThread {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Background thread creation"];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    FPRTraceBackgroundActivityTracker *tracker = [[FPRTraceBackgroundActivityTracker alloc] init];
    XCTAssertNotNil(tracker);

    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter]
          postNotificationName:UIApplicationDidBecomeActiveNotification
                        object:[UIApplication sharedApplication]];

      XCTAssertEqual(tracker.traceBackgroundState, FPRTraceStateForegroundOnly);
      [expectation fulfill];
    });
  });

  [self waitForExpectationsWithTimeout:5.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error, @"Test timed out");
                               }];
}

@end
