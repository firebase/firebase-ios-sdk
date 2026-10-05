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

#import "FirebaseABTesting/Sources/ABTConstants.h"
#import "FirebaseABTesting/Sources/Private/ABTExperimentPayload.h"
#import "FirebaseABTesting/Tests/Unit/Utilities/ABTTestUtilities.h"

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

/// Verifies that we initialize the payload if it has a start time parameter with millis, rather
/// than a date string.
- (void)testPayloadInitializesStartTimeWithMillis {
  ABTExperimentPayload *testPayload = [ABTTestUtilities payloadFromTestFilename:@"TestABTPayload5"];
  XCTAssertEqual(testPayload.experimentStartTimeMillis, 143);
}

- (void)testPayloadInitializationWithString {
  ABTExperimentPayload *unrecognizedOverflowPolicyString =
      [[ABTExperimentPayload alloc] initWithDictionary:@{@"overflowPolicy" : @"WWDC"}];
  XCTAssertEqual(unrecognizedOverflowPolicyString.overflowPolicy,
                 ABTExperimentPayloadExperimentOverflowPolicyUnrecognizedValue);

  ABTExperimentPayload *ignoreNewestOverflowPolicyString =
      [[ABTExperimentPayload alloc] initWithDictionary:@{@"overflowPolicy" : @"IGNORE_NEWEST"}];
  XCTAssertEqual(ignoreNewestOverflowPolicyString.overflowPolicy,
                 ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest);

  ABTExperimentPayload *discardOldestOverflowPolicyString =
      [[ABTExperimentPayload alloc] initWithDictionary:@{@"overflowPolicy" : @"DISCARD_OLDEST"}];
  XCTAssertEqual(discardOldestOverflowPolicyString.overflowPolicy,
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

#pragma mark - Malformed payloads

- (void)testParseFromNilOrEmptyData {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  XCTAssertNil([ABTExperimentPayload parseFromData:nil]);
#pragma clang diagnostic pop
  XCTAssertNil([ABTExperimentPayload parseFromData:[NSData data]]);
}

- (void)testParseFromNonDataObject {
  // Callers pass objects out of untyped arrays; a non-NSData object must not crash.
  XCTAssertNil([ABTExperimentPayload parseFromData:(NSData *)[NSNull null]]);
  XCTAssertNil([ABTExperimentPayload parseFromData:(NSData *)@"{\"experimentId\":\"exp_1\"}"]);
}

- (void)testParseFromGarbageData {
  NSData *garbage = [@"{\"experimentId\": \"exp_1\", " dataUsingEncoding:NSUTF8StringEncoding];
  XCTAssertNil([ABTExperimentPayload parseFromData:garbage]);
}

- (void)testParseFromNonObjectJSON {
  // Valid JSON whose top level is not an object must be rejected rather than crash.
  for (NSString *json in
       @[ @"[]", @"[{\"experimentId\":\"exp_1\"}]", @"\"exp_1\"", @"42", @"null", @"true" ]) {
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNil([ABTExperimentPayload parseFromData:data], @"%@", json);
  }
}

- (void)testInitWithNonDictionary {
  // In-App Messaging hands the server's `experimentPayload` node straight to this initializer.
  for (id notADictionary in @[ @"exp_1", @[ @"exp_1" ], @42, [NSNull null] ]) {
    ABTExperimentPayload *payload =
        [[ABTExperimentPayload alloc] initWithDictionary:(NSDictionary *)notADictionary];
    XCTAssertNotNil(payload);
    XCTAssertNil(payload.experimentId);
    XCTAssertNil(payload.variantId);
    XCTAssertEqual(payload.experimentStartTimeMillis, 0);
    XCTAssertEqual(payload.ongoingExperiments.count, 0);
    XCTAssertFalse([payload overflowPolicyIsValid]);
  }
}

- (void)testInitWithNullValues {
  NSNull *null = [NSNull null];
  NSDictionary *dictionary = @{
    @"experimentId" : null,
    @"variantId" : null,
    @"experimentStartTime" : null,
    @"triggerEvent" : null,
    @"triggerTimeoutMillis" : null,
    @"timeToLiveMillis" : null,
    @"setEventToLog" : null,
    @"activateEventToLog" : null,
    @"clearEventToLog" : null,
    @"timeoutEventToLog" : null,
    @"ttlExpiryEventToLog" : null,
    @"overflowPolicy" : null,
    @"ongoingExperiments" : null,
  };
  ABTExperimentPayload *payload = [[ABTExperimentPayload alloc] initWithDictionary:dictionary];
  XCTAssertNil(payload.experimentId);
  XCTAssertNil(payload.variantId);
  XCTAssertNil(payload.triggerEvent);
  XCTAssertNil(payload.setEventToLog);
  XCTAssertNil(payload.activateEventToLog);
  XCTAssertNil(payload.clearEventToLog);
  XCTAssertNil(payload.timeoutEventToLog);
  XCTAssertNil(payload.ttlExpiryEventToLog);
  XCTAssertEqual(payload.experimentStartTimeMillis, 0);
  XCTAssertEqual(payload.triggerTimeoutMillis, 0);
  XCTAssertEqual(payload.timeToLiveMillis, 0);
  XCTAssertEqual(payload.overflowPolicy, ABTExperimentPayloadExperimentOverflowPolicyUnspecified);
  XCTAssertEqual(payload.ongoingExperiments.count, 0);
}

- (void)testInitWithWrongValueTypes {
  NSDictionary *dictionary = @{
    @"experimentId" : @123,
    @"variantId" : @[ @"v1" ],
    @"experimentStartTime" : @456,
    @"experimentStartTimeMillis" : @{},
    @"triggerEvent" : @7,
    @"triggerTimeoutMillis" : @[ @1 ],
    @"timeToLiveMillis" : @{@"a" : @"b"},
    @"setEventToLog" : @1,
    @"activateEventToLog" : @[],
    @"clearEventToLog" : @{},
    @"timeoutEventToLog" : @YES,
    @"ttlExpiryEventToLog" : @2.5,
    @"overflowPolicy" : @[ @"DISCARD_OLDEST" ],
    @"ongoingExperiments" : @"exp_1",
  };
  ABTExperimentPayload *payload = [[ABTExperimentPayload alloc] initWithDictionary:dictionary];
  XCTAssertNil(payload.experimentId);
  XCTAssertNil(payload.variantId);
  XCTAssertNil(payload.triggerEvent);
  XCTAssertNil(payload.setEventToLog);
  XCTAssertNil(payload.activateEventToLog);
  XCTAssertNil(payload.clearEventToLog);
  XCTAssertNil(payload.timeoutEventToLog);
  XCTAssertNil(payload.ttlExpiryEventToLog);
  XCTAssertEqual(payload.experimentStartTimeMillis, 0);
  XCTAssertEqual(payload.triggerTimeoutMillis, 0);
  XCTAssertEqual(payload.timeToLiveMillis, 0);
  XCTAssertEqual(payload.overflowPolicy, ABTExperimentPayloadExperimentOverflowPolicyUnspecified);
  XCTAssertEqual(payload.ongoingExperiments.count, 0);
}

- (void)testInitWithNumericStrings {
  // Int64 JSON values are commonly encoded as strings; keep accepting them.
  ABTExperimentPayload *payload = [[ABTExperimentPayload alloc] initWithDictionary:@{
    @"experimentStartTimeMillis" : @"143",
    @"triggerTimeoutMillis" : @"1000",
    @"timeToLiveMillis" : @2000,
    @"overflowPolicy" : @2,
  }];
  XCTAssertEqual(payload.experimentStartTimeMillis, 143);
  XCTAssertEqual(payload.triggerTimeoutMillis, 1000);
  XCTAssertEqual(payload.timeToLiveMillis, 2000);
  XCTAssertEqual(payload.overflowPolicy, ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest);
}

- (void)testInitWithUnparseableStartTimeString {
  ABTExperimentPayload *payload = [[ABTExperimentPayload alloc]
      initWithDictionary:@{@"experimentId" : @"exp_1", @"experimentStartTime" : @"not a date"}];
  XCTAssertEqualObjects(payload.experimentId, @"exp_1");
  XCTAssertEqual(payload.experimentStartTimeMillis, 0);
}

- (void)testInitWithMalformedOngoingExperiments {
  NSDictionary *dictionary = @{
    @"experimentId" : @"exp_1",
    @"ongoingExperiments" : @[
      [NSNull null], @"exp_2", @42, @[ @"exp_3" ], @{}, @{@"experimentId" : [NSNull null]},
      @{@"experimentId" : @99}, @{@"experimentId" : @"exp_4"}
    ],
  };
  ABTExperimentPayload *payload = [[ABTExperimentPayload alloc] initWithDictionary:dictionary];
  XCTAssertEqual(payload.ongoingExperiments.count, 1);
  XCTAssertEqualObjects(payload.ongoingExperiments.firstObject.experimentId, @"exp_4");

  // A dictionary instead of an array must not be enumerated.
  payload = [[ABTExperimentPayload alloc]
      initWithDictionary:@{@"ongoingExperiments" : @{@"experimentId" : @"exp_5"}}];
  XCTAssertEqual(payload.ongoingExperiments.count, 0);
}

- (NSDate *)dateFromFormattedDateString:(NSString *)dateString {
  return [[ABTExperimentPayload experimentStartTimeFormatter] dateFromString:dateString];
}

@end
