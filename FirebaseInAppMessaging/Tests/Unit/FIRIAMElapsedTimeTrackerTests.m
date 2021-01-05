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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseInAppMessaging/Sources/Util/FIRIAMElapsedTimeTracker.h"

@interface FIRIAMElapsedTimeTrackerTests : XCTestCase
@property id<FIRIAMTimeFetcher> mockTimeFetcher;
@property FIRIAMElapsedTimeTracker *tracker;

@end

@implementation FIRIAMElapsedTimeTrackerTests

- (void)setUp {
  [super setUp];
  self.mockTimeFetcher = OCMProtocolMock(@protocol(FIRIAMTimeFetcher));
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
  [super tearDown];
}

- (void)testTrackingTimeWithPauses {
  // This is an example of a functional test case.
  // Use XCTAssert and related functions to verify your tests produce the correct results.

  // set up the time moments to be returned
  // 0 start
  // 15 pause
  // 20 resume
  // 30 measure the total tracked time
  // given the above sequence,
  // at time = 30 seconds, we expect the tracked time to be 15 + (30 - 20) = 25 seconds

  NSArray<NSNumber *> *currentTimes = @[
    [NSNumber numberWithDouble:0], [NSNumber numberWithDouble:15], [NSNumber numberWithDouble:20],
    [NSNumber numberWithDouble:30]
  ];
  __block int nextTimeToReturn = 0;

  // start with timestamp as 0
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andDo(^(NSInvocation *invocation) {
    NSTimeInterval time = [currentTimes[nextTimeToReturn++] doubleValue];
    [invocation setReturnValue:&time];
  });

  self.tracker = [[FIRIAMElapsedTimeTracker alloc] initWithTimeFetcher:_mockTimeFetcher];
  [self.tracker pause];
  [self.tracker resume];

  NSTimeInterval trackedTime = [self.tracker trackedTimeSoFar];
  XCTAssertEqualWithAccuracy(25, trackedTime, 0.01);
}
@end
