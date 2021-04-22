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

#import "OCMock.h"

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckSettings.h"
#import "FirebaseAppCheck/Sources/Core/TokenRefresh/FIRAppCheckTokenRefresher.h"
#import "FirebaseAppCheck/Tests/Unit/Utils/FIRFakeTimer.h"

@interface FIRAppCheckTokenRefresherTests : XCTestCase

@property(nonatomic) FIRFakeTimer *fakeTimer;

@property(nonatomic) OCMockObject<FIRAppCheckSettingsProtocol> *mockSettings;

@property(nonatomic) NSDate *initialTokenExpirationDate;
@property(nonatomic) NSTimeInterval tokenExpirationThreshold;

@end

@implementation FIRAppCheckTokenRefresherTests

- (void)setUp {
  self.mockSettings = OCMProtocolMock(@protocol(FIRAppCheckSettingsProtocol));
  self.fakeTimer = [[FIRFakeTimer alloc] init];
  self.initialTokenExpirationDate = [NSDate dateWithTimeIntervalSinceNow:1000];
  self.tokenExpirationThreshold = 1 * 60;
}

- (void)tearDown {
  self.fakeTimer = nil;
  [self.mockSettings stopMocking];
  self.mockSettings = nil;
}

#pragma mark - Auto refresh is allowed

- (void)testInitialRefreshWhenAutoRefreshAllowed {
  FIRAppCheckTokenRefresher *refresher = [self createRefresher];

  // 1. Expect checking if auto-refresh allowed before scheduling initial refresh.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 2. Expect timer to be scheduled.
  NSDate *expectedTimerFireDate =
      [self.initialTokenExpirationDate dateByAddingTimeInterval:-self.tokenExpirationThreshold];
  XCTestExpectation *timerCreateExpectation = [self expectationWithDescription:@"create timer"];

  __auto_type weakSelf = self;
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    weakSelf.fakeTimer.createHandler = nil;
    XCTAssertEqualObjects(fireDate, expectedTimerFireDate);
    [timerCreateExpectation fulfill];
  };

  // 3. Expect refresh handler to be called.
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

  // 4. Check if the handler is not fired before the timer.
  [self waitForExpectations:@[ timerCreateExpectation, noEarlyRefreshExpectation ] timeout:1];

  // 5. Expect checking if auto-refresh allowed before refreshing.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 6. Fire the timer and wait for completion.
  [self fireTimer];

  [self waitForExpectations:@[ initialRefreshExpectation ] timeout:0.5];

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
      [self.initialTokenExpirationDate dateByAddingTimeInterval:60 * 60];

  // 1. Expect checking if auto-refresh allowed before scheduling initial refresh.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 2. Expect refresh handler.
  XCTestExpectation *initialRefreshExpectation =
      [self expectationWithDescription:@"initial refresh"];
  refresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
    [initialRefreshExpectation fulfill];

    // Call completion in a while.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     completion(YES, refreshedTokenExpirationDate);
                   });
  };

  // 3. Expect for new timer to be created.
  NSDate *expectedFireDate =
      [refreshedTokenExpirationDate dateByAddingTimeInterval:-self.tokenExpirationThreshold];
  XCTestExpectation *createTimerExpectation = [self expectationWithDescription:@"create timer"];
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    [createTimerExpectation fulfill];
    XCTAssertEqualObjects(fireDate, expectedFireDate);
  };

  // 4. Expect checking if auto-refresh allowed before refreshing.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 5. Fire initial timer and wait for expectations.
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
    // 2. Expect refresh handler.
    XCTestExpectation *initialRefreshExpectation =
        [self expectationWithDescription:@"initial refresh"];
    refresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
      [initialRefreshExpectation fulfill];

      // Call completion in a while.
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
                       completion(NO, nil);
                     });
    };

    // 3. Expect for new timer to be created.
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

    // 4. Expect checking if auto-refresh allowed before refreshing.
    [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

    // 5. Fire initial timer and wait for expectations.
    [self fireTimer];

    [self waitForExpectations:@[ initialRefreshExpectation, createTimerExpectation ]
                      timeout:1
                 enforceOrder:YES];
  }

  OCMVerifyAll(self.mockSettings);
}

#pragma mark - Auto refresh is not allowed

- (void)testNoInitialRefreshWhenAutoRefreshIsNotAllowed {
  FIRAppCheckTokenRefresher *refresher = [self createRefresher];

  // 1. Expect checking if auto-refresh allowed before scheduling initial refresh.
  [[[self.mockSettings expect] andReturnValue:@(NO)] isTokenAutoRefreshEnabled];

  // 2. Don't expect timer to be scheduled.
  NSDate *expectedTimerFireDate =
      [self.initialTokenExpirationDate dateByAddingTimeInterval:-self.tokenExpirationThreshold];
  XCTestExpectation *timerCreateExpectation = [self expectationWithDescription:@"create timer"];
  timerCreateExpectation.inverted = YES;

  __auto_type weakSelf = self;
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    weakSelf.fakeTimer.createHandler = nil;
    XCTAssertEqualObjects(fireDate, expectedTimerFireDate);
    [timerCreateExpectation fulfill];
  };

  // 3. Don't expect refresh handler to be called.
  NSDate *refreshedTokenExpirationDate = [expectedTimerFireDate dateByAddingTimeInterval:60 * 60];
  XCTestExpectation *refreshExpectation = [self expectationWithDescription:@"refresh"];
  refreshExpectation.inverted = YES;

  refresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
    [refreshExpectation fulfill];

    // Call completion.
    completion(YES, refreshedTokenExpirationDate);
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
      [self.initialTokenExpirationDate dateByAddingTimeInterval:-self.tokenExpirationThreshold];
  XCTestExpectation *timerCreateExpectation = [self expectationWithDescription:@"create timer"];

  __auto_type weakSelf = self;
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    weakSelf.fakeTimer.createHandler = nil;
    XCTAssertEqualObjects(fireDate, expectedTimerFireDate);
    [timerCreateExpectation fulfill];
  };

  // 3. Expect refresh handler to be called.
  NSDate *refreshedTokenExpirationDate = [expectedTimerFireDate dateByAddingTimeInterval:60 * 60];
  XCTestExpectation *noRefreshExpectation = [self expectationWithDescription:@"initial refresh"];
  noRefreshExpectation.inverted = YES;
  refresher.tokenRefreshHandler = ^(FIRAppCheckTokenRefreshCompletion _Nonnull completion) {
    [noRefreshExpectation fulfill];

    // Call completion.
    completion(YES, refreshedTokenExpirationDate);
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

- (void)testUpdateTokenExpirationDateWhenAutoRefreshIsAllowed {
  FIRAppCheckTokenRefresher *refresher = [self createRefresher];

  NSDate *newExpirationDate = [self.initialTokenExpirationDate dateByAddingTimeInterval:10 * 60];

  // 1. Expect checking if auto-refresh allowed before scheduling initial refresh.
  [[[self.mockSettings expect] andReturnValue:@(YES)] isTokenAutoRefreshEnabled];

  // 2. Expect timer to be scheduled.
  NSDate *expectedTimerFireDate =
      [newExpirationDate dateByAddingTimeInterval:-self.tokenExpirationThreshold];
  XCTestExpectation *timerCreateExpectation = [self expectationWithDescription:@"create timer"];

  __auto_type weakSelf = self;
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    weakSelf.fakeTimer.createHandler = nil;
    XCTAssertEqualObjects(fireDate, expectedTimerFireDate);
    [timerCreateExpectation fulfill];
  };

  // 3. Update token expiration date.
  [refresher updateTokenExpirationDate:newExpirationDate];

  // 4. Wait for timer to be created.
  [self waitForExpectations:@[ timerCreateExpectation ] timeout:1];

  OCMVerifyAll(self.mockSettings);
}

- (void)testUpdateTokenExpirationDateWhenAutoRefreshIsNotAllowed {
  FIRAppCheckTokenRefresher *refresher = [self createRefresher];

  NSDate *newExpirationDate = [self.initialTokenExpirationDate dateByAddingTimeInterval:10 * 60];

  // 1. Expect checking if auto-refresh allowed before scheduling initial refresh.
  [[[self.mockSettings expect] andReturnValue:@(NO)] isTokenAutoRefreshEnabled];

  // 2. Don't expect timer to be scheduled.
  NSDate *expectedTimerFireDate =
      [newExpirationDate dateByAddingTimeInterval:-self.tokenExpirationThreshold];
  XCTestExpectation *timerCreateExpectation = [self expectationWithDescription:@"create timer"];
  timerCreateExpectation.inverted = YES;

  __auto_type weakSelf = self;
  self.fakeTimer.createHandler = ^(NSDate *_Nonnull fireDate) {
    weakSelf.fakeTimer.createHandler = nil;
    XCTAssertEqualObjects(fireDate, expectedTimerFireDate);
    [timerCreateExpectation fulfill];
  };

  // 3. Update token expiration date.
  [refresher updateTokenExpirationDate:newExpirationDate];

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
  return [[FIRAppCheckTokenRefresher alloc]
      initWithTokenExpirationDate:self.initialTokenExpirationDate
         tokenExpirationThreshold:self.tokenExpirationThreshold
                    timerProvider:[self.fakeTimer fakeTimerProvider]
                         settings:self.mockSettings];
}

@end
