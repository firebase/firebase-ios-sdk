/*
 * Copyright 2020 Google LLC
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

#import "FirebaseInstallations/Source/Library/InstallationsIDController/FIRInstallationsBackoffController.h"

#import "FirebaseInstallations/Source/Tests/Utils/FIRTestCurrentDateProvider.h"

@interface FIRInstallationsBackoffControllerTests : XCTestCase

@property(nonatomic) FIRInstallationsBackoffController *backoffController;

@property(nonatomic) FIRTestCurrentDateProvider *testDateProvider;
@property(nonatomic) NSDate *initialCurrentDate;

@end

@implementation FIRInstallationsBackoffControllerTests

- (void)setUp {
  self.initialCurrentDate = [NSDate date];
  self.testDateProvider = [[FIRTestCurrentDateProvider alloc] init];
  self.testDateProvider.date = self.initialCurrentDate;
  self.backoffController = [[FIRInstallationsBackoffController alloc]
      initWithCurrentDateProvider:[self.testDateProvider currentDateProvider]];
}

- (void)tearDown {
  self.backoffController = nil;
  self.testDateProvider = nil;
}

- (void)testIsNextRequestAllowed_WhenNoEvents {
  XCTAssertTrue([self.backoffController isNextRequestAllowed]);
}

- (void)testIsNextRequestAllowed_AfterUnrecoverableError {
  XCTAssertTrue([self.backoffController isNextRequestAllowed]);

  [self.backoffController registerEvent:FIRInstallationsBackoffEventUnrecoverableFailure];

  [self assertBackoffTimeInterval:24 * 60 * 60];  // 24h
}

- (void)testIsNextRequestAllowed_AfterRecoverableError {
  XCTAssertTrue([self.backoffController isNextRequestAllowed]);

  for (NSInteger attempt = 1; attempt < 21; attempt++) {
    NSTimeInterval expectedBackoffInterval = MIN(pow(2, attempt), 30 * 60 /*30min*/);

    [self.backoffController registerEvent:FIRInstallationsBackoffEventRecoverableFailure];
    [self assertBackoffTimeInterval:expectedBackoffInterval];
  }

  [self.backoffController registerEvent:FIRInstallationsBackoffEventUnrecoverableFailure];
  [self assertBackoffTimeInterval:24 * 60 * 60];  // 24h
}

- (void)testIsNextRequestAllowed_WhenSuccessAfterError {
  [self.backoffController registerEvent:FIRInstallationsBackoffEventRecoverableFailure];
  XCTAssertFalse([self.backoffController isNextRequestAllowed]);

  // Expect request allowed after success.
  [self.backoffController registerEvent:FIRInstallationsBackoffEventSuccess];
  XCTAssertTrue([self.backoffController isNextRequestAllowed]);

  [self.backoffController registerEvent:FIRInstallationsBackoffEventUnrecoverableFailure];
  XCTAssertFalse([self.backoffController isNextRequestAllowed]);

  // Expect request allowed after success.
  [self.backoffController registerEvent:FIRInstallationsBackoffEventSuccess];
  XCTAssertTrue([self.backoffController isNextRequestAllowed]);
}

#pragma mark - Helpers

- (void)assertBackoffTimeInterval:(NSTimeInterval)expectedBackoffTimeInterval {
  // Expect request denied right after the event.
  self.testDateProvider.date = self.initialCurrentDate;
  XCTAssertFalse([self.backoffController isNextRequestAllowed], @"Test: %@, interval: %f",
                 self.name, expectedBackoffTimeInterval);

  // Expect request denied in the middle of backoff time interval.
  NSTimeInterval halfBackoffInterval = expectedBackoffTimeInterval * 0.5;
  self.testDateProvider.date =
      [self.initialCurrentDate dateByAddingTimeInterval:halfBackoffInterval];
  XCTAssertFalse([self.backoffController isNextRequestAllowed], @"Test: %@, interval: %f",
                 self.name, expectedBackoffTimeInterval);

  // Expect request denied close to the end of backoff time interval.
  NSTimeInterval rightBeforeBackoffInterval = expectedBackoffTimeInterval - 1;
  self.testDateProvider.date =
      [self.initialCurrentDate dateByAddingTimeInterval:rightBeforeBackoffInterval];
  XCTAssertFalse([self.backoffController isNextRequestAllowed], @"Test: %@, interval: %f",
                 self.name, expectedBackoffTimeInterval);

  // Expect request allowed right after backoff time interval.
  NSTimeInterval rightAfterBackoffInterval = expectedBackoffTimeInterval + 1.1;
  self.testDateProvider.date =
      [self.initialCurrentDate dateByAddingTimeInterval:rightAfterBackoffInterval];
  XCTAssertTrue([self.backoffController isNextRequestAllowed], @"Test: %@, interval: %f", self.name,
                expectedBackoffTimeInterval);

  self.testDateProvider.date = self.initialCurrentDate;
}

@end
