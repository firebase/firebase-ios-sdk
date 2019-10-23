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

#import <XCTest/XCTest.h>

#import <FirebaseABTesting/FIRExperimentController.h>
#import <FirebaseABTesting/FIRLifecycleEvents.h>
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIROptionsInternal.h>
#import <OCMock/OCMock.h>
#import "FirebaseABTesting/Sources/ABTConditionalUserPropertyController.h"
#import "FirebaseABTesting/Sources/ABTConstants.h"
#import "FirebaseABTesting/Tests/Unit/ABTFakeFIRAConditionalUserPropertyController.h"
#import "FirebaseABTesting/Tests/Unit/ABTTestUniversalConstants.h"

@interface ABTConditionalUserPropertyController (ExposedForTest)
- (NSInteger)maxNumberOfExperimentsOfOrigin:(NSString *)origin;
- (void)maxNumberOfExperimentsOfOrigin:(NSString *)origin
                     completionHandler:(void (^)(int32_t))completionHandler;
- (id)createExperimentFromOrigin:(NSString *)origin
                         payload:(ABTExperimentPayload *)payload
                          events:(FIRLifecycleEvents *)events;
- (ABTExperimentPayload_ExperimentOverflowPolicy)
    overflowPolicyWithPayload:(ABTExperimentPayload *)payload
               originalPolicy:(ABTExperimentPayload_ExperimentOverflowPolicy)originalPolicy;
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
  ABTExperimentPayload *payload = [[ABTExperimentPayload alloc] init];
  payload.experimentId = @"exp_0";
  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload
                       events:events
                       policy:ABTExperimentPayload_ExperimentOverflowPolicy_IgnoreNewest];

  NSArray *experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 1);
}

- (void)testSetExperimentWhenOverflow {
  ABTExperimentPayload *payload = [[ABTExperimentPayload alloc] init];
  payload.experimentId = @"exp_1";
  payload.variantId = @"v1";
  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload
                       events:events
                       policy:ABTExperimentPayload_ExperimentOverflowPolicy_IgnoreNewest];

  NSArray *experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 1);

  payload.experimentId = @"exp_2";
  payload.variantId = @"v1";
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload
                       events:events
                       policy:ABTExperimentPayload_ExperimentOverflowPolicy_IgnoreNewest];

  experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 2);

  payload.experimentId = @"exp_3";
  payload.variantId = @"v1";
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload
                       events:events
                       policy:ABTExperimentPayload_ExperimentOverflowPolicy_IgnoreNewest];

  experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 3);

  // Now it's overflowed, try setting a new experiment exp_4.
  payload.experimentId = @"exp_4";
  payload.variantId = @"v1";
  // Try setting a new experiment with ignore newest policy.
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload
                       events:events
                       policy:ABTExperimentPayload_ExperimentOverflowPolicy_IgnoreNewest];

  experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 3);

  XCTAssertTrue([self isExperimentID:@"exp_1" variantID:@"v1" inExperiments:experiments]);
  XCTAssertTrue([self isExperimentID:@"exp_2" variantID:@"v1" inExperiments:experiments]);
  XCTAssertTrue([self isExperimentID:@"exp_3" variantID:@"v1" inExperiments:experiments]);
  XCTAssertFalse([self isExperimentID:@"exp_4" variantID:@"v1" inExperiments:experiments]);

  // Try setting a new experiment with discard oldest policy.
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload
                       events:events
                       policy:ABTExperimentPayload_ExperimentOverflowPolicy_DiscardOldest];
  experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 3);
  XCTAssertFalse([self isExperimentID:@"exp_1" variantID:@"v1" inExperiments:experiments]);
  XCTAssertTrue([self isExperimentID:@"exp_4" variantID:@"v1" inExperiments:experiments]);

  // Try setting a new experiment with unspecified policy
  payload.experimentId = @"exp_5";
  payload.variantId = @"v1";
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload
                       events:events
                       policy:ABTExperimentPayload_ExperimentOverflowPolicy_PolicyUnspecified];

  experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 3);
  XCTAssertFalse([self isExperimentID:@"exp_2" variantID:@"v1" inExperiments:experiments]);
  XCTAssertTrue([self isExperimentID:@"exp_3" variantID:@"v1" inExperiments:experiments]);
  XCTAssertTrue([self isExperimentID:@"exp_4" variantID:@"v1" inExperiments:experiments]);
  XCTAssertTrue([self isExperimentID:@"exp_5" variantID:@"v1" inExperiments:experiments]);
}

- (void)testSetExperimentWithTheSameVariantID {
  ABTExperimentPayload *payload = [[ABTExperimentPayload alloc] init];
  payload.experimentId = @"exp_1";
  payload.variantId = @"v1";
  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload
                       events:events
                       policy:ABTExperimentPayload_ExperimentOverflowPolicy_IgnoreNewest];

  NSArray *experiments = [_ABTCUPController experimentsWithOrigin:gABTTestOrigin];
  XCTAssertEqual(experiments.count, 1);
  XCTAssertTrue([self isExperimentID:@"exp_1" variantID:@"v1" inExperiments:experiments]);

  payload.experimentId = @"exp_1";
  payload.variantId = @"v2";
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload
                       events:events
                       policy:ABTExperimentPayload_ExperimentOverflowPolicy_IgnoreNewest];

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
  ABTExperimentPayload *payload = [[ABTExperimentPayload alloc] init];
  payload.experimentId = @"exp_1";
  payload.variantId = @"v1";
  // TODO(chliang) to check this name is logged in scion.
  payload.clearEventToLog = @"override_clear_event";
  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  [_ABTCUPController
      setExperimentWithOrigin:gABTTestOrigin
                      payload:payload
                       events:events
                       policy:ABTExperimentPayload_ExperimentOverflowPolicy_IgnoreNewest];

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
  ABTExperimentPayload *payload = [[ABTExperimentPayload alloc] init];
  payload.experimentId = @"exp_1";
  payload.variantId = @"variant_B";
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  payload.experimentStartTimeMillis = now * ABT_MSEC_PER_SEC;
  payload.triggerEvent = @"";
  int64_t triggerTimeout = now + 1500;
  payload.triggerTimeoutMillis = triggerTimeout * ABT_MSEC_PER_SEC;
  payload.timeToLiveMillis = (now + 60000) * ABT_MSEC_PER_SEC;

  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  events.activateExperimentEventName = @"_lifecycle_override_activate";
  events.expireExperimentEventName = @"lifecycle_override_time_to_live";

  NSDictionary<NSString *, id> *experiment =
      [_ABTCUPController createExperimentFromOrigin:gABTTestOrigin payload:payload events:events];

  NSDictionary<NSString *, id> *triggeredEvent = [experiment objectForKey:@"triggeredEvent"];
  XCTAssertEqualObjects([experiment objectForKey:@"name"], @"exp_1");
  XCTAssertEqualObjects([experiment objectForKey:@"value"], @"variant_B");
  XCTAssertEqualObjects(gABTTestOrigin, [experiment objectForKey:@"origin"]);
  XCTAssertEqualWithAccuracy(
      now, [(NSNumber *)[experiment objectForKey:@"creationTimestamp"] doubleValue], 1.0);

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
  XCTAssertEqualWithAccuracy(
      now + 1500, [(NSNumber *)([experiment objectForKey:@"triggerTimeout"]) doubleValue], 1.0);

  // time to live
  XCTAssertEqualWithAccuracy(
      now + 60000, [(NSNumber *)[experiment objectForKey:@"timeToLive"] doubleValue], 1.0);

  // Overwrite all event names
  payload.activateEventToLog = @"payload_override_activate";
  payload.ttlExpiryEventToLog = @"payload_override_time_to_live";
  payload.timeoutEventToLog = @"payload_override_timeout";
  payload.triggerEvent = @"payload_override_trigger_event";

  experiment = [_ABTCUPController createExperimentFromOrigin:gABTTestOrigin
                                                     payload:payload
                                                      events:events];
  triggeredEvent = [experiment objectForKey:@"triggeredEvent"];
  XCTAssertEqual(triggeredEvent[@"name"], @"payload_override_activate");
  timedOutEvent = [experiment objectForKey:@"timedOutEvent"];
  XCTAssertEqualObjects(timedOutEvent[@"name"], @"payload_override_timeout");
  expiredEvent = [experiment objectForKey:@"expiredEvent"];
  XCTAssertEqual(expiredEvent[@"name"], @"payload_override_time_to_live");
  XCTAssertEqual([experiment objectForKey:@"triggerEventName"], @"payload_override_trigger_event");
}

#pragma mark - helpers

- (void)testIsExperimentTheSameAsPayload {
  NSDictionary<NSString *, NSString *> *experiment =
      @{@"name" : @"exp_1", @"value" : @"variant_control_group"};

  ABTExperimentPayload *payload = [[ABTExperimentPayload alloc] init];
  payload.experimentId = @"exp_2";
  payload.variantId = @"variant_group_A";

  XCTAssertFalse([_ABTCUPController isExperiment:experiment theSameAsPayload:payload]);

  payload.experimentId = @"exp_1";
  XCTAssertFalse([_ABTCUPController isExperiment:experiment theSameAsPayload:payload]);

  payload.variantId = @"variant_control_group";
  XCTAssertTrue([_ABTCUPController isExperiment:experiment theSameAsPayload:payload]);
}

- (void)testOverflowPolicyWithPayload {
  ABTExperimentPayload *payload = [[ABTExperimentPayload alloc] init];

  XCTAssertEqual(ABTExperimentPayload_ExperimentOverflowPolicy_DiscardOldest,
                 [_ABTCUPController overflowPolicyWithPayload:payload originalPolicy:-1000],
                 @"Payload policy is unspecified, original policy is invalid, should return "
                 @"default: DiscardOldest.");

  XCTAssertEqual(
      ABTExperimentPayload_ExperimentOverflowPolicy_IgnoreNewest,
      [_ABTCUPController
          overflowPolicyWithPayload:payload
                     originalPolicy:ABTExperimentPayload_ExperimentOverflowPolicy_IgnoreNewest],
      @"Payload policy is unspecified, original policy is valid, use "
      @"original policy.");

  payload.overflowPolicy = ABTExperimentPayload_ExperimentOverflowPolicy_DiscardOldest;
  XCTAssertEqual(
      ABTExperimentPayload_ExperimentOverflowPolicy_DiscardOldest,
      [_ABTCUPController
          overflowPolicyWithPayload:payload
                     originalPolicy:ABTExperimentPayload_ExperimentOverflowPolicy_IgnoreNewest],
      @"Payload policy is specified, original policy is valid, but "
      @"use Payload because Payload always wins.");
}

@end
