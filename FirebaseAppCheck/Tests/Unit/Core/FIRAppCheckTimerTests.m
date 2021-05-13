/*
 * Copyright 2021 Google LLC
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

#import <XCTest/XCTest.h>

#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTimer.h"

@interface FIRAppCheckTimerTests : XCTestCase

@end

@implementation FIRAppCheckTimerTests

- (void)testTimerProvider {
  dispatch_queue_t queue =
      dispatch_queue_create("FIRAppCheckTimerTests.testInit", DISPATCH_QUEUE_SERIAL);
  NSTimeInterval fireTimerIn = 1;
  NSDate *startTime = [NSDate date];
  NSDate *fireDate = [NSDate dateWithTimeIntervalSinceNow:fireTimerIn];

  FIRTimerProvider timerProvider = [FIRAppCheckTimer timerProvider];

  XCTestExpectation *timerExpectation = [self expectationWithDescription:@"timer"];
  FIRAppCheckTimer *timer = timerProvider(fireDate, queue, ^{
    NSTimeInterval actuallyFiredIn = [[NSDate date] timeIntervalSinceDate:startTime];
    // Check that fired at proper time (allowing some timer drift).
    XCTAssertLessThan(ABS(actuallyFiredIn - fireTimerIn), 0.5);

    [timerExpectation fulfill];
  });

  XCTAssertNotNil(timer);

  [self waitForExpectations:@[ timerExpectation ] timeout:fireTimerIn + 1];
}

- (void)testInit {
  dispatch_queue_t queue =
      dispatch_queue_create("FIRAppCheckTimerTests.testInit", DISPATCH_QUEUE_SERIAL);
  NSTimeInterval fireTimerIn = 2;
  NSDate *startTime = [NSDate date];
  NSDate *fireDate = [NSDate dateWithTimeIntervalSinceNow:fireTimerIn];

  XCTestExpectation *timerExpectation = [self expectationWithDescription:@"timer"];
  FIRAppCheckTimer *timer = [[FIRAppCheckTimer alloc]
      initWithFireDate:fireDate
         dispatchQueue:queue
                 block:^{
                   NSTimeInterval actuallyFiredIn = [[NSDate date] timeIntervalSinceDate:startTime];
                   // Check that fired at proper time (allowing some timer drift).
                   XCTAssertLessThan(ABS(actuallyFiredIn - fireTimerIn), 0.5);

                   [timerExpectation fulfill];
                 }];

  XCTAssertNotNil(timer);

  [self waitForExpectations:@[ timerExpectation ] timeout:fireTimerIn + 1];
}

@end
