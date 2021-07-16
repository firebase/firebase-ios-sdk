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
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

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
    updateExperimentConditionalUserPropertiesWithServiceOrigin:(NSString *)origin
                                                        events:(FIRLifecycleEvents *)events
                                                        policy:
                                                            (ABTExperimentPayloadExperimentOverflowPolicy)
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
- (ABTExperimentPayloadExperimentOverflowPolicy)
    overflowPolicyWithPayload:(ABTExperimentPayload *)payload
               originalPolicy:(ABTExperimentPayloadExperimentOverflowPolicy)originalPolicy;
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
                       policy:ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest];
  NSString *sampleString = @"sample_invalid_payload";
  NSData *invalidData = [sampleString dataUsingEncoding:NSUTF8StringEncoding];
  XCTAssertNil(ABTDeserializeExperimentPayload(invalidData));
}

- (void)testUpdateExperiments {
  NSDate *now = [NSDate date];

  NSData *payload2Data =
      [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload2"
                              modifiedStartTime:[now dateByAddingTimeInterval:1500]];
  NSData *payload3Data =
      [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload3"
                              modifiedStartTime:[now dateByAddingTimeInterval:900]];
  NSData *payload4Data =
      [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload4"
                              modifiedStartTime:[now dateByAddingTimeInterval:-900]];

  __block BOOL completionHandlerCalled = NO;

  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  NSArray *payloads = @[ payload2Data, payload3Data, payload4Data ];
  [_experimentController
      updateExperimentConditionalUserPropertiesWithServiceOrigin:gABTTestOrigin
                                                          events:events
                                                          policy:
                                                              ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest  // NOLINT
                                                   lastStartTime:[now timeIntervalSince1970]
                                                        payloads:payloads
                                               completionHandler:^(NSError *_Nullable error) {
                                                 completionHandlerCalled = YES;
                                               }];

  XCTAssertEqual([_mockCUPController experimentsWithOrigin:gABTTestOrigin].count, 2);
  XCTAssertTrue(completionHandlerCalled);

  // Second time update exp_1 no longer exist, should be cleared from experiments.
  payloads = @[ payload3Data, payload4Data ];
  [_experimentController
      updateExperimentConditionalUserPropertiesWithServiceOrigin:gABTTestOrigin
                                                          events:events
                                                          policy:
                                                              ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest  // NOLINT
                                                   lastStartTime:[now timeIntervalSince1970]
                                                        payloads:payloads
                                               completionHandler:nil];

  XCTAssertEqual([_mockCUPController experimentsWithOrigin:gABTTestOrigin].count, 1);
}

- (void)testLatestExperimentStartTimestamps {
  // Mock incoming payloads
  NSMutableArray<NSData *> *payloads = [[NSMutableArray alloc] init];

  NSDate *now = [NSDate date];
  NSTimeInterval nowInterval = [now timeIntervalSince1970];

  NSData *payload2Data = [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload2"
                                                 modifiedStartTime:now];
  [payloads addObject:payload2Data];
  NSData *payload3Data =
      [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload3"
                              modifiedStartTime:[now dateByAddingTimeInterval:500]];
  [payloads addObject:payload3Data];

  NSString *sampleString = @"sample_invalid_payload";
  NSData *invalidPayload = [sampleString dataUsingEncoding:NSUTF8StringEncoding];
  [payloads addObject:invalidPayload];

  XCTAssertEqualWithAccuracy(
      [now timeIntervalSince1970] + 500,
      [_experimentController latestExperimentStartTimestampBetweenTimestamp:nowInterval + 200
                                                                andPayloads:payloads],
      1);
  XCTAssertEqualWithAccuracy(
      [now timeIntervalSince1970] + 1000,
      [_experimentController latestExperimentStartTimestampBetweenTimestamp:nowInterval + 1000
                                                                andPayloads:payloads],
      1);
  XCTAssertEqualWithAccuracy(
      [now timeIntervalSince1970] + 500,
      [_experimentController latestExperimentStartTimestampBetweenTimestamp:nowInterval - 10000
                                                                andPayloads:payloads],
      1);
}

- (void)testExperimentsToSetFromPayloads {
  // Mock conditional user property objects in experiments.
  NSMutableArray *currentExperiments = [[NSMutableArray alloc] init];

  NSDictionary<NSString *, NSString *> *CUP1 = @{@"name" : @"exp_1", @"value" : @"v1"};
  [currentExperiments addObject:CUP1];

  NSDictionary<NSString *, NSString *> *CUP2 = @{@"name" : @"exp_2", @"value" : @"v200"};
  [currentExperiments addObject:CUP2];

  NSMutableArray<NSData *> *payloads = [[NSMutableArray alloc] init];
  NSData *payload1Data = [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload1"
                                                 modifiedStartTime:nil];
  [payloads addObject:payload1Data];
  NSData *payload2Data = [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload2"
                                                 modifiedStartTime:nil];
  [payloads addObject:payload2Data];

  NSString *sampleString = @"sample_invalid_payload";
  NSData *invalidPayload = [sampleString dataUsingEncoding:NSUTF8StringEncoding];
  [payloads addObject:invalidPayload];

  NSArray<ABTExperimentPayload *> *experimentsToSet =
      ABTExperimentsToSetFromPayloads(payloads, currentExperiments, nil);

  XCTAssertEqual(experimentsToSet.count, 1);
  ABTExperimentPayload *payloadToAdd = experimentsToSet.firstObject;
  XCTAssertEqualObjects(payloadToAdd.experimentId, @"exp_1");
  XCTAssertEqualObjects(payloadToAdd.variantId, @"var_1");
}

- (void)testExperimentsToClearFromPayloads {
  // Mock conditional user property objects in experiments.
  NSMutableArray *currentExperiments = [[NSMutableArray alloc] init];

  NSDictionary<NSString *, NSString *> *CUP1 = @{@"name" : @"exp_1", @"value" : @"v1"};
  [currentExperiments addObject:CUP1];

  NSDictionary<NSString *, NSString *> *CUP2 = @{@"name" : @"exp_2", @"value" : @"v2"};
  [currentExperiments addObject:CUP2];

  NSMutableArray<NSData *> *payloads = [[NSMutableArray alloc] init];
  NSData *payload1Data = [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload4"
                                                 modifiedStartTime:nil];
  [payloads addObject:payload1Data];
  NSData *payload2Data = [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload5"
                                                 modifiedStartTime:nil];
  [payloads addObject:payload2Data];

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
                       policy:ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest];
  [[_mockCUPController reject]
      setExperimentWithOrigin:[OCMArg any]
                      payload:[OCMArg any]
                       events:[OCMArg any]
                       policy:ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest];

  OCMStub([_mockCUPController experimentsWithOrigin:gABTTestOrigin]).andReturn(nil);
  NSMutableArray<NSData *> *payloads = [[NSMutableArray alloc] init];

  __block BOOL completionHandlerWithErrorCalled = NO;

  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  [_experimentController
      updateExperimentConditionalUserPropertiesWithServiceOrigin:gABTTestOrigin
                                                          events:events
                                                          policy:
                                                              ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest  // NOLINT
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

- (void)testValidateRunningExperimentsWithEmptyArray {
  NSDate *now = [NSDate date];

  NSData *payload2Data =
      [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload2"
                              modifiedStartTime:[now dateByAddingTimeInterval:1500]];
  NSData *payload3Data =
      [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload3"
                              modifiedStartTime:[now dateByAddingTimeInterval:900]];

  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  NSArray *payloads = @[ payload2Data, payload3Data ];
  [_experimentController
      updateExperimentConditionalUserPropertiesWithServiceOrigin:gABTTestOrigin
                                                          events:events
                                                          policy:
                                                              ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest  // NOLINT
                                                   lastStartTime:[now timeIntervalSince1970]
                                                        payloads:payloads
                                               completionHandler:nil];

  XCTAssertEqual([_mockCUPController experimentsWithOrigin:gABTTestOrigin].count, 2);

  [_experimentController validateRunningExperimentsForServiceOrigin:gABTTestOrigin
                                          runningExperimentPayloads:[NSArray array]];

  // Expect all experiments have been cleared.
  XCTAssertEqual([_mockCUPController experimentsWithOrigin:gABTTestOrigin].count, 0);
}

- (void)testValidateRunningExperimentsClearingOne {
  NSDate *now = [NSDate date];

  NSData *payload2Data =
      [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload2"
                              modifiedStartTime:[now dateByAddingTimeInterval:1500]];
  NSData *payload3Data =
      [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload3"
                              modifiedStartTime:[now dateByAddingTimeInterval:900]];

  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  NSArray *payloads = @[ payload2Data, payload3Data ];
  [_experimentController
      updateExperimentConditionalUserPropertiesWithServiceOrigin:gABTTestOrigin
                                                          events:events
                                                          policy:
                                                              ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest  // NOLINT
                                                   lastStartTime:[now timeIntervalSince1970]
                                                        payloads:payloads
                                               completionHandler:nil];

  XCTAssertEqual([_mockCUPController experimentsWithOrigin:gABTTestOrigin].count, 2);

  ABTExperimentPayload *validatingPayload2 =
      [ABTTestUtilities payloadFromTestFilename:@"TestABTPayload2"];

  [_experimentController validateRunningExperimentsForServiceOrigin:gABTTestOrigin
                                          runningExperimentPayloads:@[ validatingPayload2 ]];

  // Expect no experiments have been cleared.
  XCTAssertEqual([_mockCUPController experimentsWithOrigin:gABTTestOrigin].count, 1);
}

- (void)testValidateRunningExperimentsKeepingAll {
  NSDate *now = [NSDate date];

  NSData *payload2Data =
      [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload2"
                              modifiedStartTime:[now dateByAddingTimeInterval:1500]];
  NSData *payload3Data =
      [ABTTestUtilities payloadJSONDataFromFile:@"TestABTPayload3"
                              modifiedStartTime:[now dateByAddingTimeInterval:900]];

  FIRLifecycleEvents *events = [[FIRLifecycleEvents alloc] init];
  NSArray *payloads = @[ payload2Data, payload3Data ];
  [_experimentController
      updateExperimentConditionalUserPropertiesWithServiceOrigin:gABTTestOrigin
                                                          events:events
                                                          policy:
                                                              ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest  // NOLINT
                                                   lastStartTime:[now timeIntervalSince1970]
                                                        payloads:payloads
                                               completionHandler:nil];

  XCTAssertEqual([_mockCUPController experimentsWithOrigin:gABTTestOrigin].count, 2);

  ABTExperimentPayload *validatingPayload2 =
      [ABTTestUtilities payloadFromTestFilename:@"TestABTPayload2"];
  ABTExperimentPayload *validatingPayload3 =
      [ABTTestUtilities payloadFromTestFilename:@"TestABTPayload3"];

  [_experimentController
      validateRunningExperimentsForServiceOrigin:gABTTestOrigin
                       runningExperimentPayloads:@[ validatingPayload2, validatingPayload3 ]];

  // Expect no experiments have been cleared.
  XCTAssertEqual([_mockCUPController experimentsWithOrigin:gABTTestOrigin].count, 2);
}

- (void)testActivateExperiment {
  ABTExperimentPayload *activeExperiment =
      [ABTTestUtilities payloadFromTestFilename:@"TestABTPayload1"];

  [_experimentController activateExperiment:activeExperiment forServiceOrigin:gABTTestOrigin];

  NSArray *experiments = [_mockCUPController experimentsWithOrigin:gABTTestOrigin];

  NSDictionary *userPropertyForExperiment = [experiments firstObject];

  // Verify that the triggerEventName is cleared, making this experiment active.
  XCTAssertNil([userPropertyForExperiment valueForKeyPath:@"triggerEventName"]);
}

@end
