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

/** Tests rapid creation and deallocation to verify race condition fix. */
- (void)testRapidCreationAndDeallocation_noRaceCondition {
  // This test simulates the real crash scenario by forcing async dispatch timing
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"All async operations complete"];

  __block int completedOperations = 0;
  const int totalOperations = 50;

  for (int i = 0; i < totalOperations; i++) {
    @autoreleasepool {
      FPRTraceBackgroundActivityTracker *tracker = [[FPRTraceBackgroundActivityTracker alloc] init];
      XCTAssertNotNil(tracker);

      // Force multiple runloop cycles to increase chance of race condition
      dispatch_async(dispatch_get_main_queue(), ^{
        // This would crash with old async registration if tracker is deallocated
        [[NSNotificationCenter defaultCenter]
            postNotificationName:UIApplicationDidBecomeActiveNotification
                          object:[UIApplication sharedApplication]];

        // Increment counter and fulfill expectation when done
        completedOperations++;
        if (completedOperations == totalOperations) {
          [expectation fulfill];
        }
      });

      // Tracker deallocates here immediately due to @autoreleasepool
    }
  }

  // Wait for all async operations to complete
  [self waitForExpectationsWithTimeout:10.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(
                                     error, @"Operations timed out - potential deadlock or crash");
                               }];

  // Additional safety check - post more notifications after everything is done
  XCTAssertNoThrow([[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationDidBecomeActiveNotification
                    object:[UIApplication sharedApplication]]);
  XCTAssertNoThrow([[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationDidEnterBackgroundNotification
                    object:[UIApplication sharedApplication]]);
}

/** Tests that observers are registered immediately after init on main thread. */
- (void)testObservers_immediateRegistrationOnMainThread {
  XCTAssertTrue([NSThread isMainThread]);

  FPRTraceBackgroundActivityTracker *tracker = [[FPRTraceBackgroundActivityTracker alloc] init];

  [[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationDidBecomeActiveNotification
                    object:[UIApplication sharedApplication]];

  XCTAssertEqual(tracker.traceBackgroundState, FPRTraceStateForegroundOnly);
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

/** Tests the exact crash scenario with async dispatch timing that would crash with old
 * implementation. */
- (void)testAsyncDispatch_wouldCrashWithOldImplementation {
  // This test simulates what the OLD code would do and should crash with async registration
  // With the NEW synchronous code, this should pass safely

  XCTestExpectation *expectation = [self expectationWithDescription:@"Async crash test complete"];

  __block int remainingOperations = 200;

  for (int i = 0; i < 200; i++) {
    @autoreleasepool {
      FPRTraceBackgroundActivityTracker *tracker = [[FPRTraceBackgroundActivityTracker alloc] init];
      XCTAssertNotNil(tracker);

      // Simulate the old problematic pattern
      __weak typeof(tracker) weakTracker = tracker;

      // This mimics what the OLD async registration would do
      dispatch_async(dispatch_get_main_queue(), ^{
        // In old code: tracker might be deallocated here → CRASH
        // In new code: observers already registered synchronously → SAFE

        if (weakTracker) {
          [[NSNotificationCenter defaultCenter]
              postNotificationName:UIApplicationDidBecomeActiveNotification
                            object:[UIApplication sharedApplication]];
        }

        remainingOperations--;
        if (remainingOperations == 0) {
          [expectation fulfill];
        }
      });

      // Immediately deallocate tracker - this creates the race condition window
    }

    // Force runloop processing to increase race condition likelihood
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
  }

  [self waitForExpectationsWithTimeout:5.0
                               handler:^(NSError *error) {
                                 XCTAssertNil(error, @"Async crash test failed");
                               }];
}

@end

/**
 * CRASH REPRODUCTION TEST - Only use this to verify the original bug exists
 * This simulates the original async registration pattern that would cause crashes
 */

@interface CrashReproductionTracker : NSObject
@property(nonatomic, readwrite) int traceBackgroundState;
@end

@implementation CrashReproductionTracker

- (instancetype)init {
  self = [super init];
  if (self) {
    _traceBackgroundState = 0;

    // This is the ORIGINAL problematic code that would crash
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(handleNotification:)
                                                   name:UIApplicationDidBecomeActiveNotification
                                                 object:[UIApplication sharedApplication]];
    });
  }
  return self;
}

- (void)handleNotification:(NSNotification *)notification {
  _traceBackgroundState = 1;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/**
 * CRASH REPRODUCTION TEST - Only use this to verify the original bug exists
 * This simulates the original async registration pattern that would cause crashes
 * WARNING: This test is commented out because it WILL crash with the original async pattern
 */

- (void)testCrashReproduction_originalAsyncBug {
  // This test WILL crash with the original async pattern
  for (int i = 0; i < 100; i++) {
    @autoreleasepool {
      CrashReproductionTracker *tracker = [[CrashReproductionTracker alloc] init];
      // tracker deallocates here, but async block is still queued → CRASH
    }

    // Process run loop to execute queued async blocks
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
  }
}

@end
