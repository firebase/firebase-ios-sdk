// Copyright 2020 Google
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

#import <FirebaseABTesting/ABTExperimentPayload.h>
#import "ABTConstants.h"
#import "ABTTestUtilities.h"

@interface ABTExperimentPayload (ClassTesting)

+ (NSDateFormatter *)experimentStartTimeFormatter;

@end

@interface ABTExperimentPayloadTest : XCTestCase

@end

@implementation ABTExperimentPayloadTest

- (void)testPayloadWithTrigger {
  ABTExperimentPayload *testPayload = [ABTTestUtilities payloadFromTestFilename:@"TestABTPayload1"];
  XCTAssertEqualObjects(testPayload.experimentId, @"exp_1");
  XCTAssertEqualObjects(testPayload.variantId, @"var_1");
  XCTAssertEqualObjects(testPayload.triggerEvent, @"customTrigger");

  // From the experiment resource file.
  NSString *startTimeString = @"2020-04-08T16:44:39.023Z";
  NSDate *startTime = [self dateFromFormattedDateString:startTimeString];
  NSTimeInterval startTimeInterval = [startTime timeIntervalSince1970];
  XCTAssertEqual(testPayload.experimentStartTimeMillis, startTimeInterval * ABT_MSEC_PER_SEC);

  XCTAssertEqual(testPayload.triggerTimeoutMillis, 15552000000);
  XCTAssertEqual(testPayload.timeToLiveMillis, 15552000000);
  XCTAssertEqualObjects(testPayload.setEventToLog, @"set_event");
  XCTAssertEqualObjects(testPayload.activateEventToLog, @"activate_event");
  XCTAssertEqualObjects(testPayload.clearEventToLog, @"clear_event");
  XCTAssertEqualObjects(testPayload.timeoutEventToLog, @"timeout_event");
  XCTAssertEqualObjects(testPayload.ttlExpiryEventToLog, @"ttl_expiry_event");
  XCTAssertEqual(testPayload.overflowPolicy,
                 ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest);
  XCTAssertEqual(testPayload.ongoingExperiments.count, 1);
  ABTExperimentLite *liteExperiment = testPayload.ongoingExperiments.firstObject;
  XCTAssertEqualObjects(liteExperiment.experimentId, @"exp_1");
}

- (void)testPayloadWithoutTrigger {
  ABTExperimentPayload *testPayload = [ABTTestUtilities payloadFromTestFilename:@"TestABTPayload2"];
  XCTAssertEqualObjects(testPayload.experimentId, @"exp_2");
  XCTAssertEqualObjects(testPayload.variantId, @"v200");
  XCTAssertNil(testPayload.triggerEvent);

  // From the experiment resource file.
  NSString *startTimeString = @"2020-06-01T16:00:00.000Z";
  NSDate *startTime = [self dateFromFormattedDateString:startTimeString];
  NSTimeInterval startTimeInterval = [startTime timeIntervalSince1970];
  XCTAssertEqual(testPayload.experimentStartTimeMillis, startTimeInterval * ABT_MSEC_PER_SEC);

  XCTAssertEqual(testPayload.triggerTimeoutMillis, 15452000000);
  XCTAssertEqual(testPayload.timeToLiveMillis, 15452000000);
  XCTAssertEqualObjects(testPayload.setEventToLog, @"set_event_override");
  XCTAssertEqualObjects(testPayload.activateEventToLog, @"activate_event_override");
  XCTAssertEqualObjects(testPayload.clearEventToLog, @"clear_event_override");
  XCTAssertEqualObjects(testPayload.timeoutEventToLog, @"timeout_event_override");
  XCTAssertEqualObjects(testPayload.ttlExpiryEventToLog, @"ttl_expiry_event_override");
  XCTAssertEqual(testPayload.overflowPolicy,
                 ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest);
}

- (void)testUtilityMethods {
  ABTExperimentPayload *testPayload1 =
      [ABTTestUtilities payloadFromTestFilename:@"TestABTPayload1"];
  XCTAssertTrue([testPayload1 overflowPolicyIsValid]);

  // Clear trigger event and make sure it's now nil.
  [testPayload1 clearTriggerEvent];

  // This one has an unspecified overflow policy.
  ABTExperimentPayload *testPayload3 =
      [ABTTestUtilities payloadFromTestFilename:@"TestABTPayload3"];
  XCTAssertFalse([testPayload3 overflowPolicyIsValid]);
}

- (NSDate *)dateFromFormattedDateString:(NSString *)dateString {
  return [[ABTExperimentPayload experimentStartTimeFormatter] dateFromString:dateString];
}

@end
