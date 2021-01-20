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

#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTokenRefresher.h"
#import "FirebaseAppCheck/Tests/Unit/Utils/FIRFakeTimer.h"

@interface FIRAppCheckTokenRefresherTests : XCTestCase

@property(nonatomic) FIRAppCheckTokenRefresher *refresher;
@property(nonatomic) FIRFakeTimer *fakeTimer;

@property(nonatomic) NSDate *initialTokenExpirationDate;
@property(nonatomic) NSTimeInterval tokenExpirationThreshold;

@end

@implementation FIRAppCheckTokenRefresherTests

- (void)setUp {
  self.fakeTimer = [[FIRFakeTimer alloc] init];
  self.initialTokenExpirationDate = [NSDate dateWithTimeIntervalSinceNow:1000];
  self.tokenExpirationThreshold = 1 * 60;
  self.refresher = [[FIRAppCheckTokenRefresher alloc]
      initWithTokenExpirationDate:self.initialTokenExpirationDate
         tokenExpirationThreshold:self.tokenExpirationThreshold
                    timerProvider:[self.fakeTimer fakeTimerProvider]];
}

- (void)tearDown {
  self.refresher = nil;
  self.fakeTimer = nil;
}

- (void)testInitialRefresh {
  // 1. Expect timer to be scheduled.
  NSDate *expectedTimerFireDate =
      [self.initialTokenExpirationDate dateByAddingTimeInterval:-self.tokenExpirationThreshold];
  XCTestExpectation *timerCreateExpectation = [self expectationWithDescription:@"create timer"];
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    XCTAssertEqualObjects(fireDate, expectedTimerFireDate);
    [timerCreateExpectation fulfill];
  };

  FIRAppCheckTokenRefresher *refresher = [[FIRAppCheckTokenRefresher alloc]
      initWithTokenExpirationDate:self.initialTokenExpirationDate
         tokenExpirationThreshold:self.tokenExpirationThreshold
                    timerProvider:[self.fakeTimer fakeTimerProvider]];

  [self waitForExpectations:@[ timerCreateExpectation ] timeout:0.5];
  self.fakeTimer.createHandler = nil;

  // 2. Expect refresh handler to be called.
  NSDate *refreshedTokenExpirationDate = [expectedTimerFireDate dateByAddingTimeInterval:60 * 60];
  XCTestExpectation *initialRefreshExpectation =
      [self expectationWithDescription:@"initial refresh"];
  XCTestExpectation *noEarlyRefreshExpectation =
      [self expectationWithDescription:@"no early refresh"];
  noEarlyRefreshExpectation.inverted = YES;
  refresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
    [initialRefreshExpectation fulfill];
    [noEarlyRefreshExpectation fulfill];

    // Call completion.
    completion(YES, refreshedTokenExpirationDate);
  };

  // 3. Check if the handler is not fired before the timer.
  [self waitForExpectations:@[ noEarlyRefreshExpectation ] timeout:1];

  // 4. Fire the timer and wait for completion.
  [self fireTimer];

  [self waitForExpectations:@[ initialRefreshExpectation ] timeout:0.5];
}

- (void)testNextRefreshOnRefreshSuccess {
  NSDate *refreshedTokenExpirationDate =
      [self.initialTokenExpirationDate dateByAddingTimeInterval:60 * 60];

  // 1. Expect refresh handler.
  XCTestExpectation *initialRefreshExpectation =
      [self expectationWithDescription:@"initial refresh"];
  self.refresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
    [initialRefreshExpectation fulfill];

    // Call completion in a while.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     completion(YES, refreshedTokenExpirationDate);
                   });
  };

  // 2. Expect for new timer to be created.
  NSDate *expectedFireDate =
      [refreshedTokenExpirationDate dateByAddingTimeInterval:-self.tokenExpirationThreshold];
  XCTestExpectation *createTimerExpectation = [self expectationWithDescription:@"create timer"];
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    [createTimerExpectation fulfill];
    XCTAssertEqualObjects(fireDate, expectedFireDate);
  };

  // 3. Fire initial timer and wait for expectations.
  [self fireTimer];

  [self waitForExpectations:@[ initialRefreshExpectation, createTimerExpectation ]
                    timeout:1
               enforceOrder:YES];
}

- (void)testBackoff {
  // Initial backoff interval.
  NSTimeInterval expectedBackoffTime = 30;
  NSTimeInterval maximumBackoffTime = 16 * 60;  // 16 min.

  for (NSInteger i = 0; i < 10; i++) {
    // 1. Expect refresh handler.
    XCTestExpectation *initialRefreshExpectation =
        [self expectationWithDescription:@"initial refresh"];
    self.refresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
      [initialRefreshExpectation fulfill];

      // Call completion in a while.
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
                       completion(NO, nil);
                     });
    };

    // 2. Expect for new timer to be created.
    expectedBackoffTime = expectedBackoffTime * 2;
    expectedBackoffTime = MIN(expectedBackoffTime, maximumBackoffTime);
    NSDate *expectedFireDate = [[NSDate date] dateByAddingTimeInterval:expectedBackoffTime];

    XCTestExpectation *createTimerExpectation = [self expectationWithDescription:@"create timer"];
    self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
      [createTimerExpectation fulfill];

      // Check expected and actual fire date are not too different (account for the random part
      // and request attempt delay).
      XCTAssertLessThan(ABS([expectedFireDate timeIntervalSinceDate:fireDate]), 2);
    };

    // 3. Fire initial timer and wait for expectations.
    [self fireTimer];

    [self waitForExpectations:@[ initialRefreshExpectation, createTimerExpectation ]
                      timeout:1
                 enforceOrder:YES];
  }
}

#pragma mark - Helpers

- (void)fireTimer {
  if (self.fakeTimer.handler) {
    self.fakeTimer.handler();
  } else {
    XCTFail(@"handler must not be nil!");
  }
}

@end
