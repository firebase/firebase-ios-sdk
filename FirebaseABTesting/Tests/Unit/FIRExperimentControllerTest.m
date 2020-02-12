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
#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIROptionsInternal.h>
#import <OCMock/OCMock.h>
#import "FirebaseABTesting/Sources/ABTConditionalUserPropertyController.h"
#import "FirebaseABTesting/Sources/ABTConstants.h"
#import "FirebaseABTesting/Tests/Unit/ABTFakeFIRAConditionalUserPropertyController.h"
#import "FirebaseABTesting/Tests/Unit/ABTTestUniversalConstants.h"

extern ABTExperimentPayload *ABTDeserializeExperimentPayload(NSData *payload);

extern NSArray<ABTExperimentPayload *> *ABTExperimentsToSetFromPayloads(
    NSArray<NSData *> *payloads,
    NSArray<NSDictionary<NSString *, NSString *> *> *experiments,
    id<FIRAnalyticsInterop> _Nullable analytics);
extern NSArray *ABTExperimentsToClearFromPayloads(
    NSArray<NSData *> *payloads,
    NSArray<NSDictionary<NSString *, NSString *> *> *experiments,
    id<FIRAnalyticsInterop> _Nullable analytics);

@interface FIRExperimentController (ExposedForTest)
- (void)
    updateExperimentsInBackgroundQueueWithServiceOrigin:(NSString *)origin
                                                 events:(FIRLifecycleEvents *)events
                                                 policy:
                                                     (ABTExperimentPayload_ExperimentOverflowPolicy)
                                                         policy
                                          lastStartTime:(NSTimeInterval)lastStartTime
                                               payloads:(NSArray<NSData *> *)payloads
                                      completionHandler:
                                          (nullable void (^)(NSError *_Nullable error))
                                              completionHandler;

/// Surface internal initializer to avoid singleton usage during tests.
- (instancetype)initWithAnalytics:(nullable id<FIRAnalyticsInterop>)analytics;
@end

@interface ABTConditionalUserPropertyController (ExposedForTest)
- (void)maxNumberOfExperimentsOfOrigin:(NSString *)origin
                     completionHandler:(void (^)(int32_t))completionHandler;
- (int32_t)maxNumberOfExperimentsOfOrigin:(NSString *)origin;
- (id)createExperimentFromOrigin:(NSString *)origin
                         payload:(ABTExperimentPayload *)payload
                          events:(FIRLifecycleEvents *)events;
- (ABTExperimentPayload_ExperimentOverflowPolicy)
    overflowPolicyWithPayload:(ABTExperimentPayload *)payload
               originalPolicy:(ABTExperimentPayload_ExperimentOverflowPolicy)originalPolicy;
@end

@interface FIRExperimentControllerTest : XCTestCase {
  FIRExperimentController *_experimentController;
  ABTFakeFIRAConditionalUserPropertyController *_fakeController;
  id _mockCUPController;
}
@end

@implementation FIRExperimentControllerTest

- (void)setUp {
  [super setUp];
  _fakeController = [ABTFakeFIRAConditionalUserPropertyController sharedInstance];
  id<FIRAnalyticsInterop> fakeAnalytics =
      [[FakeAnalytics alloc] initWithFakeController:_fakeController];
  _experimentController = [[FIRExperimentController alloc] initWithAnalytics:fakeAnalytics];

  ABTConditionalUserPropertyController *controller =
      [ABTConditionalUserPropertyController sharedInstanceWithAnalytics:fakeAnalytics];
  _mockCUPController = OCMPartialMock(controller);
  OCMStub([_mockCUPController maxNumberOfExperimentsOfOrigin:[OCMArg any]]).andReturn(3);
}

- (void)tearDown {
  [_fakeController resetExperiments];
  [_mockCUPController stopMocking];
  [super tearDown];
}

- (void)testDeserializeInvalidPayload {
  FIRExperimentController *controller = _experimentController;
  XCTAssertNotNil(controller);
  NSString *sampleString = @"sample_invalid_payload";
  NSData *invalidData = [sampleString dataUsingEncoding:NSUTF8StringEncoding];
  XCTAssertNil(ABTDeserializeExperimentPayload(invalidData));
  XCTAssertNotNil(ABTDeserializeExperimentPayload(nil));
}

- (void)testLifecycleEvents {
  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  XCTAssertEqualObjects(FIRSetExperimentEventName, events.setExperimentEventName);
  XCTAssertEqualObjects(FIRActivateExperimentEventName, events.activateExperimentEventName);
  XCTAssertEqualObjects(FIRTimeoutExperimentEventName, events.timeoutExperimentEventName);
  XCTAssertEqualObjects(FIRExpireExperimentEventName, events.expireExperimentEventName);
  XCTAssertEqualObjects(FIRClearExperimentEventName, events.clearExperimentEventName);

  // Should be able to override event name values.
  events.setExperimentEventName = @"_new_set_experiment";
  XCTAssertEqualObjects(events.setExperimentEventName, @"_new_set_experiment");
  events.setExperimentEventName = @"name_without_prefix";
  XCTAssertEqualObjects(FIRSetExperimentEventName, events.setExperimentEventName);

  events.activateExperimentEventName = @"_new_activate_experiment";
  XCTAssertEqualObjects(events.activateExperimentEventName, @"_new_activate_experiment");
  events.activateExperimentEventName = @"";
  XCTAssertEqualObjects(FIRActivateExperimentEventName, events.activateExperimentEventName);

  events.timeoutExperimentEventName = @"__";
  XCTAssertEqualObjects(events.timeoutExperimentEventName, @"__");
  events.timeoutExperimentEventName = @"name_with_";
  XCTAssertEqualObjects(FIRTimeoutExperimentEventName, events.timeoutExperimentEventName);

  events.expireExperimentEventName = @"_";
  XCTAssertEqualObjects(events.expireExperimentEventName, @"_");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  events.expireExperimentEventName = nil;
#pragma clang diagnostic pop
  XCTAssertEqualObjects(FIRExpireExperimentEventName, events.expireExperimentEventName);

  events.clearExperimentEventName = @"_new_set_experiment";
  XCTAssertEqualObjects(events.clearExperimentEventName, @"_new_set_experiment");
  events.clearExperimentEventName = @"";
  XCTAssertEqualObjects(FIRClearExperimentEventName, events.clearExperimentEventName);
}

- (void)testSetExperimentWithBadPayload {
  [[_mockCUPController reject]
      setExperimentWithOrigin:[OCMArg any]
                      payload:[OCMArg any]
                       events:[OCMArg any]
                       policy:ABTExperimentPayload_ExperimentOverflowPolicy_DiscardOldest];
  NSString *sampleString = @"sample_invalid_payload";
  NSData *invalidData = [sampleString dataUsingEncoding:NSUTF8StringEncoding];
  XCTAssertNil(ABTDeserializeExperimentPayload(invalidData));
}

- (void)testUpdateExperiments {
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

  ABTExperimentPayload *payload2 = [[ABTExperimentPayload alloc] init];
  payload2.experimentId = @"exp_2";
  payload2.variantId = @"v200";
  payload2.experimentStartTimeMillis =
      (now + 1500) * ABT_MSEC_PER_SEC;  // start time > last start time, do set
  ABTExperimentLite *ongoingExperiment = [[ABTExperimentLite alloc] init];
  ongoingExperiment.experimentId = @"exp_1";
  [payload2.ongoingExperimentsArray addObject:ongoingExperiment];

  ABTExperimentPayload *payload3 = [[ABTExperimentPayload alloc] init];
  payload3.experimentId = @"exp_3";
  payload3.variantId = @"v200";
  payload3.experimentStartTimeMillis =
      (now + 900) * ABT_MSEC_PER_SEC;  // start time > last start time, do set
  ongoingExperiment = [[ABTExperimentLite alloc] init];
  ongoingExperiment.experimentId = @"exp_2";
  [payload3.ongoingExperimentsArray addObject:ongoingExperiment];

  ABTExperimentPayload *payload4 = [[ABTExperimentPayload alloc] init];
  payload4.experimentId = @"exp_4";
  payload4.variantId = @"v200";
  payload4.experimentStartTimeMillis =
      (now - 900) * ABT_MSEC_PER_SEC;  // start time < last start time, do not set.
  ongoingExperiment = [[ABTExperimentLite alloc] init];
  ongoingExperiment.experimentId = @"exp_2";
  [payload4.ongoingExperimentsArray addObject:ongoingExperiment];

  __block BOOL completionHandlerCalled = NO;

  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  NSArray *payloads = @[ [payload2 data], [payload3 data], [payload4 data] ];
  [_experimentController
      updateExperimentsInBackgroundQueueWithServiceOrigin:gABTTestOrigin
                                                   events:events
                                                   policy:
                                                       ABTExperimentPayload_ExperimentOverflowPolicy_DiscardOldest  // NOLINT
                                            lastStartTime:now
                                                 payloads:payloads
                                        completionHandler:^(NSError *_Nullable error) {
                                          completionHandlerCalled = YES;
                                        }];

  XCTAssertEqual([_mockCUPController experimentsWithOrigin:gABTTestOrigin].count, 2);
  XCTAssertTrue(completionHandlerCalled);

  // Second time update exp_1 no longer exist, should be cleared from experiments.
  payloads = @[ [payload3 data], [payload4 data] ];
  [_experimentController
      updateExperimentsInBackgroundQueueWithServiceOrigin:gABTTestOrigin
                                                   events:events
                                                   policy:
                                                       ABTExperimentPayload_ExperimentOverflowPolicy_DiscardOldest  // NOLINT
                                            lastStartTime:now
                                                 payloads:payloads
                                        completionHandler:nil];

  XCTAssertEqual([_mockCUPController experimentsWithOrigin:gABTTestOrigin].count, 1);
}

- (void)testLatestExperimentStartTimestamps {
  // Mock incoming payloads
  NSMutableArray<NSData *> *payloads = [[NSMutableArray alloc] init];
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

  ABTExperimentPayload *payload1 = [[ABTExperimentPayload alloc] init];
  payload1.experimentId = @"exp_1";
  payload1.variantId = @"v3";
  payload1.experimentStartTimeMillis = now * ABT_MSEC_PER_SEC;
  [payloads addObject:[payload1 data]];

  ABTExperimentPayload *payload2 = [[ABTExperimentPayload alloc] init];
  payload2.experimentId = @"exp_2";
  payload2.variantId = @"v2";
  payload2.experimentStartTimeMillis = (now + 500) * ABT_MSEC_PER_SEC;
  [payloads addObject:[payload2 data]];

  NSString *sampleString = @"sample_invalid_payload";
  NSData *invalidPayload = [sampleString dataUsingEncoding:NSUTF8StringEncoding];
  [payloads addObject:invalidPayload];

  XCTAssertEqualWithAccuracy(
      now + 500,
      [_experimentController latestExperimentStartTimestampBetweenTimestamp:now + 200
                                                                andPayloads:payloads],
      1);
  XCTAssertEqualWithAccuracy(
      now + 1000,
      [_experimentController latestExperimentStartTimestampBetweenTimestamp:now + 1000
                                                                andPayloads:payloads],
      1);
  XCTAssertEqualWithAccuracy(
      now + 500,
      [_experimentController latestExperimentStartTimestampBetweenTimestamp:now - 10000
                                                                andPayloads:payloads],
      1);
}

- (void)testExperimentsToSetFromPayloads {
  // Mock conditional user property objects in experiments.
  NSMutableArray *currentExperiments = [[NSMutableArray alloc] init];

  NSDictionary<NSString *, NSString *> *CUP1 = @{@"name" : @"exp_1", @"value" : @"v1"};
  [currentExperiments addObject:CUP1];

  NSDictionary<NSString *, NSString *> *CUP2 = @{@"name" : @"exp_2", @"value" : @"v2"};
  [currentExperiments addObject:CUP2];

  // Mock incoming payloads
  NSMutableArray<NSData *> *payloads = [[NSMutableArray alloc] init];
  ABTExperimentPayload *payload1 = [[ABTExperimentPayload alloc] init];
  payload1.experimentId = @"exp_1";
  payload1.variantId = @"v3";
  [payloads addObject:[payload1 data]];

  ABTExperimentPayload *payload2 = [[ABTExperimentPayload alloc] init];
  payload2.experimentId = @"exp_2";
  payload2.variantId = @"v2";
  [payloads addObject:[payload2 data]];

  NSString *sampleString = @"sample_invalid_payload";
  NSData *invalidPayload = [sampleString dataUsingEncoding:NSUTF8StringEncoding];
  [payloads addObject:invalidPayload];

  NSArray<ABTExperimentPayload *> *experimentsToSet =
      ABTExperimentsToSetFromPayloads(payloads, currentExperiments, nil);

  XCTAssertEqual(experimentsToSet.count, 1);
  ABTExperimentPayload *payloadToAdd = experimentsToSet.firstObject;
  XCTAssertEqualObjects(payloadToAdd.experimentId, @"exp_1");
  XCTAssertEqualObjects(payloadToAdd.variantId, @"v3");
}

- (void)testExperimentsToClearFromPaylods {
  // Mock conditional user property objects in experiments.
  NSMutableArray *currentExperiments = [[NSMutableArray alloc] init];

  NSDictionary<NSString *, NSString *> *CUP1 = @{@"name" : @"exp_1", @"value" : @"v1"};
  [currentExperiments addObject:CUP1];

  NSDictionary<NSString *, NSString *> *CUP2 = @{@"name" : @"exp_2", @"value" : @"v2"};
  [currentExperiments addObject:CUP2];

  // Mock incoming payloads
  NSMutableArray<NSData *> *payloads = [[NSMutableArray alloc] init];
  ABTExperimentPayload *payload1 = [[ABTExperimentPayload alloc] init];
  payload1.experimentId = @"exp_1";
  payload1.variantId = @"v3";
  [payloads addObject:[payload1 data]];

  ABTExperimentPayload *payload2 = [[ABTExperimentPayload alloc] init];
  payload2.experimentId = @"exp_2";
  payload2.variantId = @"v2";
  [payloads addObject:[payload2 data]];

  NSString *sampleString = @"sample_invalid_payload";
  NSData *invalidPayload = [sampleString dataUsingEncoding:NSUTF8StringEncoding];
  [payloads addObject:invalidPayload];

  NSArray<NSDictionary<NSString *, NSString *> *> *experimentsToClear =
      ABTExperimentsToClearFromPayloads(payloads, currentExperiments, nil);

  XCTAssertEqual(experimentsToClear.count, 1);
  NSDictionary<NSString *, NSString *> *experimentToRemove = experimentsToClear.firstObject;
  XCTAssertEqualObjects(experimentToRemove[@"name"], @"exp_1");
  XCTAssertEqualObjects(experimentToRemove[@"value"], @"v1");
}

- (void)testInvalidExperiments {
  [[_mockCUPController reject]
      setExperimentWithOrigin:[OCMArg any]
                      payload:[OCMArg any]
                       events:[OCMArg any]
                       policy:ABTExperimentPayload_ExperimentOverflowPolicy_DiscardOldest];
  [[_mockCUPController reject]
      setExperimentWithOrigin:[OCMArg any]
                      payload:[OCMArg any]
                       events:[OCMArg any]
                       policy:ABTExperimentPayload_ExperimentOverflowPolicy_DiscardOldest];

  OCMStub([_mockCUPController experimentsWithOrigin:gABTTestOrigin]).andReturn(nil);
  NSMutableArray<NSData *> *payloads = [[NSMutableArray alloc] init];

  __block BOOL completionHandlerWithErrorCalled = NO;

  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  [_experimentController
      updateExperimentsInBackgroundQueueWithServiceOrigin:gABTTestOrigin
                                                   events:events
                                                   policy:
                                                       ABTExperimentPayload_ExperimentOverflowPolicy_DiscardOldest  // NOLINT
                                            lastStartTime:-1
                                                 payloads:payloads
                                        completionHandler:^(NSError *_Nullable error) {
                                          if (error &&
                                              error.code ==
                                                  kABTInternalErrorFailedToFetchConditionalUserProperties) {
                                            completionHandlerWithErrorCalled = YES;
                                          }
                                        }];

  // Verify completion handler is still called.
  XCTAssertTrue(completionHandlerWithErrorCalled);
}
@end
