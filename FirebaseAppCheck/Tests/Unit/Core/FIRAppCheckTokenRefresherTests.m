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

#import <OCMock/OCMock.h>

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckSettings.h"
#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTokenRefreshResult.h"
#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTokenRefresher.h"
#import "FirebaseAppCheck/Tests/Unit/Utils/FIRFakeTimer.h"
#import "SharedTestUtilities/Date/FIRDateTestUtils.h"

@interface FIRAppCheckTokenRefresherTests : XCTestCase

@property(nonatomic) FIRFakeTimer *fakeTimer;

@property(nonatomic) OCMockObject<FIRAppCheckSettingsProtocol> *mockSettings;

@property(nonatomic) FIRAppCheckTokenRefreshResult *initialTokenRefreshResult;

@end

@implementation FIRAppCheckTokenRefresherTests

- (void)setUp {
  self.mockSettings = OCMProtocolMock(@protocol(FIRAppCheckSettingsProtocol));
  self.fakeTimer = [[FIRFakeTimer alloc] init];

  NSDate *receivedAtDate = [NSDate date];
  self.initialTokenRefreshResult = [[FIRAppCheckTokenRefreshResult alloc]
      initWithStatusSuccessAndExpirationDate:[receivedAtDate dateByAddingTimeInterval:1000]
                              receivedAtDate:receivedAtDate];
}

- (void)tearDown {
  self.fakeTimer = nil;
  [self.mockSettings stopMocking];
  self.mockSettings = nil;
}

#pragma mark - Auto refresh is allowed

- (void)testInitialRefreshWhenAutoRefreshAllowed {
  __auto_type weakSelf = self;

  self.initialTokenRefreshResult = [[FIRAppCheckTokenRefreshResult alloc] initWithStatusNever];
  FIRAppCheckTokenRefresher *refresher = [self createRefresher];

  // 1. Expect checking if auto-refresh allowed before scheduling the initial refresh.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 2. Don't expect the timer to be scheduled for the first refresh as the refresh should be
  // triggered straight away.
  XCTestExpectation *initialTimerCreatedExpectation =
      [self expectationWithDescription:@"initial refresh timer created"];
  initialTimerCreatedExpectation.inverted = YES;
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    weakSelf.fakeTimer.createHandler = nil;
    [initialTimerCreatedExpectation fulfill];
  };

  // 3. Expect checking if auto-refresh allowed before triggering the initial refresh.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 4. Expect initial refresh handler to be called.
  __block FIRAppCheckTokenRefreshCompletion initialRefreshCompletion;
  XCTestExpectation *initialRefreshExpectation =
      [self expectationWithDescription:@"initial refresh"];
  refresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
    // Save completion to be called later.
    initialRefreshCompletion = completion;

    [initialRefreshExpectation fulfill];
  };

  NSDate *initialTokenExpirationDate = [NSDate dateWithTimeIntervalSinceNow:60 * 60];
  NSDate *initialTokenReceivedDate = [NSDate date];
  __auto_type initialRefreshResult = [[FIRAppCheckTokenRefreshResult alloc]
      initWithStatusSuccessAndExpirationDate:initialTokenExpirationDate
                              receivedAtDate:initialTokenReceivedDate];

  [self waitForExpectations:@[ initialTimerCreatedExpectation, initialRefreshExpectation ]
                    timeout:1];

  // 5. Expect checking if auto-refresh allowed before scheduling next refresh.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 6. Expect a next refresh timer to be scheduled on initial refresh completion.
  NSDate *expectedRefreshDate =
      [self expectedRefreshDateWithReceivedDate:initialTokenReceivedDate
                                 expirationDate:initialTokenExpirationDate];
  XCTestExpectation *nextTimerCreateExpectation =
      [self expectationWithDescription:@"next refresh create timer"];
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    weakSelf.fakeTimer.createHandler = nil;
    XCTAssertEqualObjects(fireDate, expectedRefreshDate);
    [nextTimerCreateExpectation fulfill];
  };

  // 7. Call initial refresh completion and wait for next refresh timer to be scheduled.
  initialRefreshCompletion(initialRefreshResult);
  [self waitForExpectations:@[ nextTimerCreateExpectation ] timeout:0.5];

  // 8. Expect checking if auto-refresh allowed before triggering the next refresh.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 9. Expect refresh handler to be called for the next refresh.
  __auto_type nextRefreshResult = [[FIRAppCheckTokenRefreshResult alloc]
      initWithStatusSuccessAndExpirationDate:[expectedRefreshDate dateByAddingTimeInterval:60 * 60]
                              receivedAtDate:expectedRefreshDate];
  XCTestExpectation *nextRefreshExpectation = [self expectationWithDescription:@"next refresh"];
  refresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
    [nextRefreshExpectation fulfill];

    // Call completion.
    completion(nextRefreshResult);
  };

  // 10. Fire the timer.
  [self fireTimer];

  // 11. Wait for the next refresh handler to be called.
  [self waitForExpectations:@[ nextRefreshExpectation ] timeout:1];

  OCMVerifyAll(self.mockSettings);
}

- (void)testNoTimeScheduledUntilHandlerSet {
  // 1. Don't expect timer to be scheduled.
  XCTestExpectation *timerCreateExpectation1 = [self expectationWithDescription:@"create timer 1"];
  timerCreateExpectation1.inverted = YES;
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    [timerCreateExpectation1 fulfill];
  };

  // 2. Create a publisher.
  FIRAppCheckTokenRefresher *refresher = [self createRefresher];

  XCTAssertNotNil(refresher);

  [self waitForExpectations:@[ timerCreateExpectation1 ] timeout:0.5];

  // 3. Expect timer to be created after the handler has been set.
  // 3.1. Expect checking if auto-refresh allowed one more time when timer fires.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 3.2. Expect timer to fire.
  XCTestExpectation *timerCreateExpectation2 = [self expectationWithDescription:@"create timer 2"];
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    [timerCreateExpectation2 fulfill];
  };

  // 3.3. Set handler.
  refresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
  };

  [self waitForExpectations:@[ timerCreateExpectation2 ] timeout:0.5];

  OCMVerifyAll(self.mockSettings);
}

- (void)testNextRefreshOnRefreshSuccess {
  FIRAppCheckTokenRefresher *refresher = [self createRefresher];

  NSDate *refreshedTokenExpirationDate =
      [self.initialTokenRefreshResult.tokenExpirationDate dateByAddingTimeInterval:60 * 60];
  __auto_type refreshResult = [[FIRAppCheckTokenRefreshResult alloc]
      initWithStatusSuccessAndExpirationDate:refreshedTokenExpirationDate
                              receivedAtDate:self.initialTokenRefreshResult.tokenExpirationDate];

  // 1. Expect checking if auto-refresh allowed before scheduling initial refresh.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 2. Expect checking if auto-refresh allowed before calling the refresh handler.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 3. Expect refresh handler.
  XCTestExpectation *initialRefreshExpectation =
      [self expectationWithDescription:@"initial refresh"];
  refresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
    [initialRefreshExpectation fulfill];

    // Call completion in a while.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     completion(refreshResult);
                   });
  };

  // 4. Expect for new timer to be created.
  NSDate *expectedFireDate =
      [self expectedRefreshDateWithReceivedDate:refreshResult.tokenReceivedAtDate
                                 expirationDate:refreshResult.tokenExpirationDate];
  XCTestExpectation *createTimerExpectation = [self expectationWithDescription:@"create timer"];
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    [createTimerExpectation fulfill];
    XCTAssertEqualObjects(fireDate, expectedFireDate);
  };

  // 5. Expect checking if auto-refresh allowed before refreshing.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 6. Fire initial timer and wait for expectations.
  [self fireTimer];

  [self waitForExpectations:@[ initialRefreshExpectation, createTimerExpectation ]
                    timeout:1
               enforceOrder:YES];

  OCMVerifyAll(self.mockSettings);
}

- (void)testBackoff {
  FIRAppCheckTokenRefresher *refresher = [self createRefresher];

  // Initial backoff interval.
  NSTimeInterval expectedBackoffTime = 0;
  NSTimeInterval maximumBackoffTime = 16 * 60;  // 16 min.

  // 1. Expect checking if auto-refresh allowed before scheduling initial refresh.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  for (NSInteger i = 0; i < 10; i++) {
    // 2. Expect checking if auto-refresh allowed before calling the refresh handler.
    [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

    // 3. Expect refresh handler.
    XCTestExpectation *initialRefreshExpectation =
        [self expectationWithDescription:@"initial refresh"];
    refresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
      [initialRefreshExpectation fulfill];

      // Call completion in a while.
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
                       __auto_type refreshFailure =
                           [[FIRAppCheckTokenRefreshResult alloc] initWithStatusFailure];
                       completion(refreshFailure);
                     });
    };

    // 4. Expect for new timer to be created.
    // No backoff initially, 1st backoff 30sec, double backoff on each next attempt until 16min.
    expectedBackoffTime = expectedBackoffTime == 0 ? 30 : expectedBackoffTime * 2;
    expectedBackoffTime = MIN(expectedBackoffTime, maximumBackoffTime);
    NSDate *expectedFireDate = [[NSDate date] dateByAddingTimeInterval:expectedBackoffTime];

    XCTestExpectation *createTimerExpectation = [self expectationWithDescription:@"create timer"];
    self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
      [createTimerExpectation fulfill];

      // Check expected and actual fire date are not too different (account for the random part
      // and request attempt delay).
      XCTAssertLessThan(ABS([expectedFireDate timeIntervalSinceDate:fireDate]), 2);
    };

    // 5. Expect checking if auto-refresh allowed before refreshing.
    [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

    // 6. Fire initial timer and wait for expectations.
    [self fireTimer];

    [self waitForExpectations:@[ initialRefreshExpectation, createTimerExpectation ]
                      timeout:1
                 enforceOrder:YES];
  }

  OCMVerifyAll(self.mockSettings);
}

//- (void)test

#pragma mark - Auto refresh is not allowed

- (void)testNoInitialRefreshWhenAutoRefreshIsNotAllowed {
  FIRAppCheckTokenRefresher *refresher = [self createRefresher];

  // 1. Expect checking if auto-refresh allowed before scheduling initial refresh.
  [[[self.mockSettings expect] andReturnValue:@(NO)] isTokenAutoRefreshEnabled];

  // 2. Don't expect timer to be scheduled.
  XCTestExpectation *timerCreateExpectation = [self expectationWithDescription:@"create timer"];
  timerCreateExpectation.inverted = YES;

  __auto_type weakSelf = self;
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    weakSelf.fakeTimer.createHandler = nil;
    [timerCreateExpectation fulfill];
  };

  // 3. Don't expect refresh handler to be called.
  __auto_type refreshResult = [[FIRAppCheckTokenRefreshResult alloc]
      initWithStatusSuccessAndExpirationDate:[NSDate dateWithTimeIntervalSinceNow:60 * 60]
                              receivedAtDate:[NSDate date]];
  XCTestExpectation *refreshExpectation = [self expectationWithDescription:@"refresh"];
  refreshExpectation.inverted = YES;

  refresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
    [refreshExpectation fulfill];

    // Call completion.
    completion(refreshResult);
  };

  // 4. Check if the handler is not fired before the timer.
  [self waitForExpectations:@[ timerCreateExpectation, refreshExpectation ] timeout:1];

  OCMVerifyAll(self.mockSettings);
}

- (void)testNoRefreshWhenAutoRefreshWasDisabledAfterInit {
  FIRAppCheckTokenRefresher *refresher = [self createRefresher];

  // 1. Expect checking if auto-refresh allowed before scheduling initial refresh.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 2. Expect timer to be scheduled.
  NSDate *expectedTimerFireDate =
      [self expectedRefreshDateWithReceivedDate:self.initialTokenRefreshResult.tokenReceivedAtDate
                                 expirationDate:self.initialTokenRefreshResult.tokenExpirationDate];
  XCTestExpectation *timerCreateExpectation = [self expectationWithDescription:@"create timer"];

  __auto_type weakSelf = self;
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    weakSelf.fakeTimer.createHandler = nil;
    XCTAssertEqualObjects(fireDate, expectedTimerFireDate);
    [timerCreateExpectation fulfill];
  };

  // 3. Expect refresh handler to be called.
  __auto_type refreshResult = [[FIRAppCheckTokenRefreshResult alloc]
      initWithStatusSuccessAndExpirationDate:[expectedTimerFireDate
                                                 dateByAddingTimeInterval:60 * 60]
                              receivedAtDate:expectedTimerFireDate];
  XCTestExpectation *noRefreshExpectation = [self expectationWithDescription:@"initial refresh"];
  noRefreshExpectation.inverted = YES;
  refresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
    [noRefreshExpectation fulfill];

    // Call completion.
    completion(refreshResult);
  };

  // 4. Check if the handler is not fired before the timer.
  [self waitForExpectations:@[ timerCreateExpectation ] timeout:1];

  // 5. Expect checking if auto-refresh allowed before refreshing.
  [[[self.mockSettings expect] andReturnValue:@(NO)] isTokenAutoRefreshEnabled];

  // 6. Fire the timer and wait for completion.
  [self fireTimer];

  [self waitForExpectations:@[ noRefreshExpectation ] timeout:1];

  OCMVerifyAll(self.mockSettings);
}

#pragma mark - Update token expiration

- (void)testUpdateWithRefreshResultWhenAutoRefreshIsAllowed {
  FIRAppCheckTokenRefresher *refresher = [self createRefresher];

  NSDate *newExpirationDate =
      [self.initialTokenRefreshResult.tokenExpirationDate dateByAddingTimeInterval:10 * 60];
  __auto_type newRefreshResult = [[FIRAppCheckTokenRefreshResult alloc]
      initWithStatusSuccessAndExpirationDate:newExpirationDate
                              receivedAtDate:self.initialTokenRefreshResult.tokenExpirationDate];

  // 1. Expect checking if auto-refresh allowed before scheduling refresh.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 2. Expect timer to be scheduled.
  NSDate *expectedTimerFireDate =
      [self expectedRefreshDateWithReceivedDate:newRefreshResult.tokenReceivedAtDate
                                 expirationDate:newRefreshResult.tokenExpirationDate];
  XCTestExpectation *timerCreateExpectation = [self expectationWithDescription:@"create timer"];

  __auto_type weakSelf = self;
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    weakSelf.fakeTimer.createHandler = nil;
    XCTAssertEqualObjects(fireDate, expectedTimerFireDate);
    [timerCreateExpectation fulfill];
  };

  // 3. Update token expiration date.
  [refresher updateWithRefreshResult:newRefreshResult];

  // 4. Wait for timer to be created.
  [self waitForExpectations:@[ timerCreateExpectation ] timeout:1];

  OCMVerifyAll(self.mockSettings);
}

- (void)testUpdateWithRefreshResultWhenAutoRefreshIsNotAllowed {
  FIRAppCheckTokenRefresher *refresher = [self createRefresher];

  __auto_type newRefreshResult = [[FIRAppCheckTokenRefreshResult alloc]
      initWithStatusSuccessAndExpirationDate:[NSDate dateWithTimeIntervalSinceNow:60 * 60]
                              receivedAtDate:self.initialTokenRefreshResult.tokenExpirationDate];

  // 1. Expect checking if auto-refresh allowed before scheduling initial refresh.
  [[[self.mockSettings expect] andReturnValue:@(NO)] isTokenAutoRefreshEnabled];

  // 2. Don't expect timer to be scheduled.
  XCTestExpectation *timerCreateExpectation = [self expectationWithDescription:@"create timer"];
  timerCreateExpectation.inverted = YES;

  __auto_type weakSelf = self;
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    weakSelf.fakeTimer.createHandler = nil;
    [timerCreateExpectation fulfill];
  };

  // 3. Update token expiration date.
  [refresher updateWithRefreshResult:newRefreshResult];

  // 4. Wait for timer to be created.
  [self waitForExpectations:@[ timerCreateExpectation ] timeout:1];

  OCMVerifyAll(self.mockSettings);
}

- (void)testUpdateWithRefreshResult_WhenTokenExpiresLessThanIn1Minute {
  FIRAppCheckTokenRefresher *refresher = [self createRefresher];

  NSDate *newExpirationDate = [NSDate dateWithTimeIntervalSinceNow:0.5 * 60];
  __auto_type newRefreshResult = [[FIRAppCheckTokenRefreshResult alloc]
      initWithStatusSuccessAndExpirationDate:newExpirationDate
                              receivedAtDate:[NSDate date]];

  // 1. Expect checking if auto-refresh allowed before scheduling refresh.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 2. Expect timer to be scheduled in at least 1 minute.
  XCTestExpectation *timerCreateExpectation = [self expectationWithDescription:@"create timer"];

  __auto_type weakSelf = self;
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    weakSelf.fakeTimer.createHandler = nil;

    // 1 minute is the minimal interval between successful refreshes.
    XCTAssert([FIRDateTestUtils isDate:fireDate
        approximatelyEqualCurrentPlusTimeInterval:60
                                        precision:1]);
    [timerCreateExpectation fulfill];
  };

  // 3. Update token expiration date.
  [refresher updateWithRefreshResult:newRefreshResult];

  // 4. Wait for timer to be created.
  [self waitForExpectations:@[ timerCreateExpectation ] timeout:1];

  OCMVerifyAll(self.mockSettings);
}

#pragma mark - Helpers

- (void)fireTimer {
  if (self.fakeTimer.handler) {
    self.fakeTimer.handler();
  } else {
    XCTFail(@"handler must not be nil!");
  }
}

- (FIRAppCheckTokenRefresher *)createRefresher {
  return [[FIRAppCheckTokenRefresher alloc] initWithRefreshResult:self.initialTokenRefreshResult
                                                    timerProvider:[self.fakeTimer fakeTimerProvider]
                                                         settings:self.mockSettings];
}

- (NSDate *)expectedRefreshDateWithReceivedDate:(NSDate *)receivedDate
                                 expirationDate:(NSDate *)expirationDate {
  NSTimeInterval timeToLive = [expirationDate timeIntervalSinceDate:receivedDate];
  XCTAssertGreaterThanOrEqual(timeToLive, 0);

  NSTimeInterval timeToRefresh = timeToLive / 2 + 5 * 60;  // 50% or TTL + 5 min

  NSTimeInterval minimalAutoRefreshInterval = 60;  // 1 min
  timeToRefresh = MAX(timeToRefresh, minimalAutoRefreshInterval);

  NSDate *refreshDate = [receivedDate dateByAddingTimeInterval:timeToRefresh];

  NSDate *now = [NSDate date];

  return [refreshDate laterDate:now];
}

@end
