// Copyright 2019 Google
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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseABTesting/Sources/ABTConditionalUserPropertyController.h"
#import "FirebaseABTesting/Sources/ABTConstants.h"
#import "FirebaseABTesting/Sources/Private/ABTExperimentPayload.h"
#import "FirebaseABTesting/Sources/Public/FirebaseABTesting/FIRExperimentController.h"
#import "FirebaseABTesting/Sources/Public/FirebaseABTesting/FIRLifecycleEvents.h"
#import "FirebaseABTesting/Tests/Unit/ABTFakeFIRAConditionalUserPropertyController.h"
#import "FirebaseABTesting/Tests/Unit/ABTTestUniversalConstants.h"
#import "FirebaseABTesting/Tests/Unit/Utilities/ABTTestUtilities.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

@interface ABTConditionalUserPropertyController (ExposedForTest)
- (NSInteger)maxNumberOfExperimentsOfOrigin:(NSString *)origin;
- (void)maxNumberOfExperimentsOfOrigin:(NSString *)origin
                     completionHandler:(void (^)(int32_t))completionHandler;
- (id)createExperimentFromOrigin:(NSString *)origin
                         payload:(ABTExperimentPayload *)payload
                          events:(FIRLifecycleEvents *)events;
- (ABTExperimentPayloadExperimentOverflowPolicy)
    overflowPolicyWithPayload:(ABTExperimentPayload *)payload
               originalPolicy:(ABTExperimentPayloadExperimentOverflowPolicy)originalPolicy;
/// Surface internal initializer to avoid singleton usage during tests.
- (instancetype)initWithAnalytics:(nullable id<FIRAnalyticsInterop>)analytics;
@end

typedef void (^FakeAnalyticsLogEventWithOriginNameParametersHandler)(
    NSString *origin, NSString *name, NSDictionary<NSString *, id> *parameters);

@interface ABTConditionalUserPropertyControllerTest : XCTestCase {
  ABTConditionalUserPropertyController *_ABTCUPController;
  ABTFakeFIRAConditionalUserPropertyController *_fakeController;
  id _mockCUPController;
}
@end

@interface ABTExperimentPayload (Testing)
@property(nonatomic, readwrite) ABTExperimentPayloadExperimentOverflowPolicy overflowPolicy;
@end

@implementation ABTConditionalUserPropertyControllerTest
- (void)setUp {
  [super setUp];

  _fakeController = [ABTFakeFIRAConditionalUserPropertyController sharedInstance];
  _ABTCUPController = [[ABTConditionalUserPropertyController alloc]
      initWithAnalytics:[[FakeAnalytics alloc] initWithFakeController:_fakeController]];
  _mockCUPController = OCMPartialMock(_ABTCUPController);
  OCMStub([_mockCUPController maxNumberOfExperimentsOfOrigin:[OCMArg any]]).andReturn(3);

  // Must initialize FIRApp before calling set experiment as Firebase Analytics internal event
  // logging requires it.
  NSDictionary *optionsDictionary = @{
    kFIRGoogleAppID : @"1:123456789012:ios:1234567890123456",
    @"GCM_SENDER_ID" : @"123456789012"
  };
  FIROptions *options = [[FIROptions alloc] initInternalWithOptionsDictionary:optionsDictionary];
  [FIRApp configureWithOptions:options];
}

- (void)tearDown {
  [_fakeController resetExperiments];
  [_mockCUPController stopMocking];
  [FIRApp resetApps];
  [super tearDown];
}

#pragma mark - test proxy methods on Firebase Analytics
- (void)testSetExperiment {
  id payload = OCMClassMock([ABTExperimentPayload class]);
  OCMStub([payload experimentId]).andReturn(@"exp_0");
  OCMStub([payload variantId]).andReturn(@"v1");
  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload
                       events:events
                       policy:ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest];

  NSArray *experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 1);
}

- (void)testSetExperimentWhenOverflow {
  id payload1 = OCMClassMock([ABTExperimentPayload class]);
  OCMStub([payload1 experimentId]).andReturn(@"exp_1");
  OCMStub([payload1 variantId]).andReturn(@"v1");
  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload1
                       events:events
                       policy:ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest];

  NSArray *experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 1);

  id payload2 = OCMClassMock([ABTExperimentPayload class]);
  OCMStub([payload2 experimentId]).andReturn(@"exp_2");
  OCMStub([payload2 variantId]).andReturn(@"v1");
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload2
                       events:events
                       policy:ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest];

  experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 2);

  id payload3 = OCMClassMock([ABTExperimentPayload class]);
  OCMStub([payload3 experimentId]).andReturn(@"exp_3");
  OCMStub([payload3 variantId]).andReturn(@"v1");
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload3
                       events:events
                       policy:ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest];

  experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 3);

  // Now it's overflowed, try setting a new experiment exp_4.
  id payload4 = OCMClassMock([ABTExperimentPayload class]);
  OCMStub([payload4 experimentId]).andReturn(@"exp_4");
  OCMStub([payload4 variantId]).andReturn(@"v1");
  // Try setting a new experiment with ignore newest policy.
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload4
                       events:events
                       policy:ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest];

  experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 3);

  XCTAssertTrue([self isExperimentID:@"exp_1" variantID:@"v1" inExperiments:experiments]);
  XCTAssertTrue([self isExperimentID:@"exp_2" variantID:@"v1" inExperiments:experiments]);
  XCTAssertTrue([self isExperimentID:@"exp_3" variantID:@"v1" inExperiments:experiments]);
  XCTAssertFalse([self isExperimentID:@"exp_4" variantID:@"v1" inExperiments:experiments]);

  // Try setting a new experiment with discard oldest policy.
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload4
                       events:events
                       policy:ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest];
  experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 3);
  XCTAssertFalse([self isExperimentID:@"exp_1" variantID:@"v1" inExperiments:experiments]);
  XCTAssertTrue([self isExperimentID:@"exp_4" variantID:@"v1" inExperiments:experiments]);

  // Try setting a new experiment with unspecified policy
  id payload5 = OCMClassMock([ABTExperimentPayload class]);
  OCMStub([payload5 experimentId]).andReturn(@"exp_5");
  OCMStub([payload5 variantId]).andReturn(@"v1");
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload5
                       events:events
                       policy:ABTExperimentPayloadExperimentOverflowPolicyUnspecified];

  experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 3);
  XCTAssertFalse([self isExperimentID:@"exp_2" variantID:@"v1" inExperiments:experiments]);
  XCTAssertTrue([self isExperimentID:@"exp_3" variantID:@"v1" inExperiments:experiments]);
  XCTAssertTrue([self isExperimentID:@"exp_4" variantID:@"v1" inExperiments:experiments]);
  XCTAssertTrue([self isExperimentID:@"exp_5" variantID:@"v1" inExperiments:experiments]);
}

- (void)testSetExperimentWithTheSameVariantID {
  id payload1 = OCMClassMock([ABTExperimentPayload class]);
  OCMStub([payload1 experimentId]).andReturn(@"exp_1");
  OCMStub([payload1 variantId]).andReturn(@"v1");
  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload1
                       events:events
                       policy:ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest];

  NSArray *experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 1);
  XCTAssertTrue([self isExperimentID:@"exp_1" variantID:@"v1" inExperiments:experiments]);

  id payload2 = OCMClassMock([ABTExperimentPayload class]);
  OCMStub([payload2 experimentId]).andReturn(@"exp_1");
  OCMStub([payload2 variantId]).andReturn(@"v2");
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload2
                       events:events
                       policy:ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest];

  experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 1);
  XCTAssertTrue([self isExperimentID:@"exp_1" variantID:@"v2" inExperiments:experiments]);
}

- (BOOL)isExperimentID:(NSString *)experimentID
             variantID:(NSString *)variantID
         inExperiments:(NSArray *)experiments {
  for (NSDictionary<NSString *, NSString *> *experiment in experiments) {
    if ([experiment[@"name"] isEqualToString:experimentID] &&
        [experiment[@"value"] isEqualToString:variantID]) {
      return YES;
    }
  }
  return NO;
}

- (void)testClearExperiment {
  id payload = OCMClassMock([ABTExperimentPayload class]);
  OCMStub([payload experimentId]).andReturn(@"exp_1");
  OCMStub([payload variantId]).andReturn(@"v1");
  OCMStub([payload clearEventToLog]).andReturn(@"override_clear_event");
  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload
                       events:events
                       policy:ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest];

  NSArray *experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 1);

  [_ABTCUPController clearExperiment:@"exp_1"
                           variantID:@"v1"
                          withOrigin:gABTTestOrigin
                             payload:payload
                              events:events];
  experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 0);
}

- (void)testMaxNumberOfExperiments {
  XCTAssertEqual([_ABTCUPController maxNumberOfExperimentsOfOrigin:gABTTestOrigin], 3);
}

- (void)testCreateExperiment {
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

  id payload = OCMClassMock([ABTExperimentPayload class]);
  OCMStub([payload experimentId]).andReturn(@"exp_1");
  OCMStub([payload variantId]).andReturn(@"variant_B");
  int64_t startTimeMillis = now * ABT_MSEC_PER_SEC;
  OCMStub([payload experimentStartTimeMillis]).andReturn(startTimeMillis);
  OCMStub([payload triggerEvent]).andReturn(@"");
  int64_t triggerTimeoutMillis = (now + 1500) * ABT_MSEC_PER_SEC;
  OCMStub([payload triggerTimeoutMillis]).andReturn(triggerTimeoutMillis);
  int64_t timeToLiveMillis = (now + 60000) * ABT_MSEC_PER_SEC;
  OCMStub([payload timeToLiveMillis]).andReturn(timeToLiveMillis);

  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  events.activateExperimentEventName = @"_lifecycle_override_activate";
  events.expireExperimentEventName = @"lifecycle_override_time_to_live";

  NSDictionary<NSString *, id> *experiment =
      [_ABTCUPController createExperimentFromOrigin:gABTTestOrigin payload:payload events:events];

  NSDictionary<NSString *, id> *triggeredEvent = [experiment objectForKey:@"triggeredEvent"];
  XCTAssertEqualObjects([experiment objectForKey:@"name"], @"exp_1");
  XCTAssertEqualObjects([experiment objectForKey:@"value"], @"variant_B");
  XCTAssertEqualObjects(gABTTestOrigin, [experiment objectForKey:@"origin"]);
  XCTAssertEqualWithAccuracy(now, [[experiment objectForKey:@"creationTimestamp"] longLongValue],
                             1.0);

  // Trigger event
  XCTAssertEqualObjects(gABTTestOrigin, triggeredEvent[@"origin"]);
  XCTAssertEqualObjects(triggeredEvent[@"name"], @"_lifecycle_override_activate",
                        @"Activate event name is overrided by lifecycle events.");

  // Timeout event
  NSDictionary<NSString *, id> *timedOutEvent = [experiment objectForKey:@"timedOutEvent"];
  XCTAssertEqualObjects(gABTTestOrigin, timedOutEvent[@"origin"]);
  XCTAssertEqualObjects(FIRTimeoutExperimentEventName, timedOutEvent[@"name"],
                        @"payload doesn't have timeout event name, use default one");

  // Expired event
  NSDictionary<NSString *, id> *expiredEvent = [experiment objectForKey:@"expiredEvent"];
  XCTAssertEqualObjects(gABTTestOrigin, expiredEvent[@"origin"]);
  XCTAssertEqualObjects(
      @"lifecycle_override_time_to_live", expiredEvent[@"name"],
      @"payload doesn't have expiry event name, but lifecycle event does, use lifecycle event");

  // Trigger event name
  XCTAssertEqualObjects(nil, [experiment objectForKey:@"triggerEventName"],
                        @"Empty trigger event must be set to nil");

  // trigger timeout
  XCTAssertEqualWithAccuracy(now + 1500,
                             [[experiment objectForKey:@"triggerTimeout"] longLongValue], 1.0);

  // time to live
  XCTAssertEqualWithAccuracy(now + 60000, [[experiment objectForKey:@"timeToLive"] longLongValue],
                             1.0);

  // Overwrite all event names
  id payloadWithCustomEventNames = OCMClassMock([ABTExperimentPayload class]);
  OCMStub([payloadWithCustomEventNames experimentId]).andReturn(@"exp_1");
  OCMStub([payloadWithCustomEventNames variantId]).andReturn(@"variant_B");
  OCMStub([payloadWithCustomEventNames activateEventToLog]).andReturn(@"payload_override_activate");
  OCMStub([payloadWithCustomEventNames ttlExpiryEventToLog])
      .andReturn(@"payload_override_time_to_live");
  OCMStub([payloadWithCustomEventNames timeoutEventToLog]).andReturn(@"payload_override_timeout");
  OCMStub([payloadWithCustomEventNames triggerEvent]).andReturn(@"payload_override_trigger_event");

  experiment = [_ABTCUPController createExperimentFromOrigin:gABTTestOrigin
                                                     payload:payloadWithCustomEventNames
                                                      events:events];
  triggeredEvent = [experiment objectForKey:@"triggeredEvent"];
  XCTAssertEqual(triggeredEvent[@"name"], @"payload_override_activate");
  timedOutEvent = [experiment objectForKey:@"timedOutEvent"];
  XCTAssertEqualObjects(timedOutEvent[@"name"], @"payload_override_timeout");
  expiredEvent = [experiment objectForKey:@"expiredEvent"];
  XCTAssertEqual(expiredEvent[@"name"], @"payload_override_time_to_live");
  XCTAssertEqualObjects([experiment objectForKey:@"triggerEventName"],
                        @"payload_override_trigger_event");
}

#pragma mark - helpers

- (void)testIsExperimentTheSameAsPayload {
  NSDictionary<NSString *, NSString *> *experiment =
      @{@"name" : @"exp_1", @"value" : @"variant_control_group"};

  id payload2 = OCMClassMock([ABTExperimentPayload class]);
  OCMStub([payload2 experimentId]).andReturn(@"exp_2");
  OCMStub([payload2 variantId]).andReturn(@"variant_group_A");

  XCTAssertFalse([_ABTCUPController isExperiment:experiment theSameAsPayload:payload2]);

  id payload1 = OCMClassMock([ABTExperimentPayload class]);
  OCMStub([payload1 experimentId]).andReturn(@"exp_1");
  OCMStub([payload1 variantId]).andReturn(@"variant_group_A");

  XCTAssertFalse([_ABTCUPController isExperiment:experiment theSameAsPayload:payload1]);

  id payloadJustRight = OCMClassMock([ABTExperimentPayload class]);
  OCMStub([payloadJustRight experimentId]).andReturn(@"exp_1");
  OCMStub([payloadJustRight variantId]).andReturn(@"variant_control_group");
  XCTAssertTrue([_ABTCUPController isExperiment:experiment theSameAsPayload:payloadJustRight]);
}

- (void)testOverflowPolicyWithPayload {
  ABTExperimentPayload *payloadUnspecifiedPolicy =
      [ABTTestUtilities payloadFromTestFilename:@"TestABTPayload3"];

  XCTAssertEqual(ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest,
                 [_ABTCUPController overflowPolicyWithPayload:payloadUnspecifiedPolicy
                                               originalPolicy:-1000],
                 @"Payload policy is unspecified, original policy is invalid, should return "
                 @"default: DiscardOldest.");

  XCTAssertEqual(
      ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest,
      [_ABTCUPController
          overflowPolicyWithPayload:payloadUnspecifiedPolicy
                     originalPolicy:ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest],
      @"Payload policy is unspecified, original policy is valid, use "
      @"original policy.");

  ABTExperimentPayload *payloadDiscardOldest =
      [ABTTestUtilities payloadFromTestFilename:@"TestABTPayload1"];
  payloadDiscardOldest.overflowPolicy = ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest;
  XCTAssertEqual(
      ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest,
      [_ABTCUPController
          overflowPolicyWithPayload:payloadDiscardOldest
                     originalPolicy:ABTExperimentPayloadExperimentOverflowPolicyIgnoreNewest],
      @"Payload policy is specified, original policy is valid, but "
      @"use Payload because Payload always wins.");
}

@end
