/*
 * Copyright 2019 Google
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

#import "FirebaseRemoteConfig/Sources/RCNConfigExperiment.h"

#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"
#import "FirebaseRemoteConfig/Sources/Public/FirebaseRemoteConfig/FIRRemoteConfig.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDefines.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigValue_Internal.h"
#import "FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.h"

#import "FirebaseABTesting/Sources/Private/FirebaseABTestingInternal.h"

#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

// Surface the internal FIRExperimentController initializer.
@interface FIRExperimentController ()
- (instancetype)initWithAnalytics:(nullable id<FIRAnalyticsInterop>)analytics;
@end

@interface RCNConfigDBManager (ExperimentTest)
- (void)waitForDatabaseOperationQueue;
@end

@interface RCNControllableExperimentDBManager : RCNConfigDBManager
@property(nonatomic, copy) NSString *pendingExperimentKey;
@property(nonatomic, copy) NSArray<NSData *> *pendingExperimentValues;
@property(nonatomic, copy) RCNDBCompletion pendingExperimentCompletion;
@property(nonatomic) BOOL loadsPersistedExperiments;
- (void)persistPendingExperiments;
@end

@implementation RCNControllableExperimentDBManager

- (void)loadExperimentWithCompletionHandler:(RCNDBCompletion)handler {
  if (_loadsPersistedExperiments) {
    [super loadExperimentWithCompletionHandler:handler];
  } else {
    handler(YES, @{
      @RCNExperimentTableKeyPayload : @[],
      @RCNExperimentTableKeyMetadata : @{},
      @RCNExperimentTableKeyActivePayload : @[]
    });
  }
}

- (void)replaceExperimentTableWithKey:(NSString *)key
                               values:(NSArray<NSData *> *)values
                    completionHandler:(RCNDBCompletion)handler {
  _pendingExperimentKey = [key copy];
  _pendingExperimentValues = [values copy];
  _pendingExperimentCompletion = [handler copy];
}

- (void)persistPendingExperiments {
  NSString *key = _pendingExperimentKey;
  NSArray<NSData *> *values = _pendingExperimentValues;
  RCNDBCompletion completion = _pendingExperimentCompletion;
  _pendingExperimentKey = nil;
  _pendingExperimentValues = nil;
  _pendingExperimentCompletion = nil;
  [super replaceExperimentTableWithKey:key values:values completionHandler:completion];
}

@end

@interface RCNConfigExperiment ()
@property(nonatomic, copy) NSArray<NSData *> *experimentPayloads;
@property(nonatomic, copy) NSDictionary<NSString *, id> *experimentMetadata;
@property(nonatomic, copy) NSArray<NSData *> *activeExperimentPayloads;
@property(nonatomic, strong) RCNConfigDBManager *DBManager;
- (void)updateExperimentStartTime;
- (void)loadExperimentFromTable;
@end

@interface RCNConfigExperimentTest : XCTestCase {
  NSTimeInterval _expectationTimeout;
  FIRExperimentController *_experimentController;
  RCNConfigExperiment *_configExperiment;
  id _DBManagerMock;
  NSArray<NSDictionary<NSString *, id> *> *_payloads;
  NSArray<NSData *> *_payloadsData;
  NSDictionary<NSString *, NSNumber *> *_metadata;
  NSString *_DBPath;
}
@end

@implementation RCNConfigExperimentTest
- (void)setUp {
  [super setUp];
  _expectationTimeout = 1.0;
  _DBPath = [RCNTestUtilities remoteConfigPathForTestDatabase];
  _DBManagerMock = OCMClassMock([RCNConfigDBManager class]);
  OCMStub([_DBManagerMock remoteConfigPathForDatabase]).andReturn(_DBPath);

  // Mock all database operations.
  NSDictionary<NSString *, id> *payload1 = @{@"experimentId" : @"DBValue1"};
  NSDictionary<NSString *, id> *payload2 = @{@"experimentId" : @"DBValue2"};
  _payloads = @[ payload1, payload2 ];
  NSError *error;
  NSData *payloadData1 = [NSJSONSerialization dataWithJSONObject:payload1 options:0 error:&error];
  NSData *payloadData2 = [NSJSONSerialization dataWithJSONObject:payload2 options:0 error:&error];
  _payloadsData = @[ payloadData1, payloadData2 ];
  _metadata = @{@"last_know_start_time" : @12348765};
  NSDictionary<NSString *, id> *mockResults = @{
    @RCNExperimentTableKeyPayload : _payloadsData,
    @RCNExperimentTableKeyMetadata : _metadata,
  };
  OCMStub([_DBManagerMock
      loadExperimentWithCompletionHandler:([OCMArg invokeBlockWithArgs:@YES, mockResults, nil])]);
  OCMStub([_DBManagerMock deleteExperimentTableForKey:[OCMArg any]]).andDo(nil);
  OCMStub([_DBManagerMock insertExperimentTableWithKey:[OCMArg any]
                                                 value:[OCMArg any]
                                     completionHandler:nil])
      .andDo(nil);
  OCMStub([_DBManagerMock replaceExperimentTableWithKey:[OCMArg any]
                                                 values:[OCMArg any]
                                      completionHandler:[OCMArg any]])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained RCNDBCompletion completionHandler;
        [invocation getArgument:&completionHandler atIndex:4];
        if (completionHandler) {
          completionHandler(YES, nil);
        }
      });

  FIRExperimentController *experimentController =
      [[FIRExperimentController alloc] initWithAnalytics:nil];
  _configExperiment = [[RCNConfigExperiment alloc] initWithDBManager:_DBManagerMock
                                                experimentController:experimentController];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testInitMethod {
  OCMVerify([_DBManagerMock loadExperimentWithCompletionHandler:[OCMArg any]]);
}

- (void)testLoadExperimentFromTable {
  [_configExperiment loadExperimentFromTable];

  int payloadIndex = 0;
  for (NSData *payload in _configExperiment.experimentPayloads) {
    ABTExperimentPayload *experimentPayload = [self deserializeABTData:payload];
    XCTAssertNotNil(experimentPayload);
    XCTAssertEqualObjects(experimentPayload.experimentId,
                          _payloads[payloadIndex++][@"experimentId"]);
  }

  XCTAssertEqualObjects(_payloadsData, _configExperiment.experimentPayloads);
  XCTAssertEqualObjects(_metadata, _configExperiment.experimentMetadata);
}

- (void)testUpdateExperiment {
  NSDictionary<NSString *, NSString *> *payload1 = @{@"experimentId" : @"exp1"};
  NSDictionary<NSString *, NSString *> *payload2 = @{@"experimentId" : @"exp2"};
  NSDictionary<NSString *, NSString *> *payload3 = @{@"experimentId" : @"exp3"};
  NSArray<NSDictionary<NSString *, id> *> *originalPayloads = @[ payload1, payload2, payload3 ];

  NSArray<NSDictionary<NSString *, id> *> *response = @[ payload1, payload2, payload3 ];
  [_configExperiment updateExperimentsWithResponse:response];

  // Serialized proto data.
  int payloadIndex = 0;
  for (NSData *payload in _configExperiment.experimentPayloads) {
    ABTExperimentPayload *experimentPayload = [self deserializeABTData:payload];
    XCTAssertNotNil(experimentPayload);
    XCTAssertEqualObjects(experimentPayload.experimentId,
                          originalPayloads[payloadIndex++][@"experimentId"]);
  }
}

- (void)testDatabaseLoadDoesNotOverwriteNewerFetchedExperiments {
  __block RCNDBCompletion databaseLoadCompletion;
  id dbManagerMock = OCMClassMock([RCNConfigDBManager class]);
  OCMStub([dbManagerMock loadExperimentWithCompletionHandler:[OCMArg any]])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained RCNDBCompletion completion;
        [invocation getArgument:&completion atIndex:2];
        databaseLoadCompletion = [completion copy];
      });
  OCMStub([dbManagerMock replaceExperimentTableWithKey:[OCMArg any]
                                                values:[OCMArg any]
                                     completionHandler:[OCMArg any]])
      .andDo(nil);

  RCNConfigExperiment *experiment = [[RCNConfigExperiment alloc] initWithDBManager:dbManagerMock
                                                              experimentController:nil];
  NSDictionary<NSString *, NSString *> *newPayload = @{@"experimentId" : @"new"};
  [experiment updateExperimentsWithResponse:@[ newPayload ]];

  NSDictionary<NSString *, NSString *> *stalePayload = @{@"experimentId" : @"stale"};
  NSData *stalePayloadData = [NSJSONSerialization dataWithJSONObject:stalePayload
                                                             options:0
                                                               error:nil];
  NSDictionary<NSString *, NSNumber *> *storedMetadata = @{@"last_experiment_start_time" : @123};
  databaseLoadCompletion(YES, @{
    @RCNExperimentTableKeyPayload : @[ stalePayloadData ],
    @RCNExperimentTableKeyMetadata : storedMetadata,
    @RCNExperimentTableKeyActivePayload : @[]
  });

  NSData *newPayloadData = [NSJSONSerialization dataWithJSONObject:newPayload options:0 error:nil];
  XCTAssertEqualObjects(experiment.experimentPayloads, @[ newPayloadData ]);
  XCTAssertEqualObjects(experiment.experimentMetadata, storedMetadata);
  [dbManagerMock stopMocking];
}

- (void)testDatabaseLoadDoesNotOverwriteNewerActivatedExperiments {
  __block RCNDBCompletion databaseLoadCompletion;
  id dbManagerMock = OCMClassMock([RCNConfigDBManager class]);
  OCMStub([dbManagerMock loadExperimentWithCompletionHandler:[OCMArg any]])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained RCNDBCompletion completion;
        [invocation getArgument:&completion atIndex:2];
        databaseLoadCompletion = [completion copy];
      });
  OCMStub([dbManagerMock insertExperimentTableWithKey:[OCMArg any]
                                                value:[OCMArg any]
                                    completionHandler:nil]);
  OCMStub([dbManagerMock replaceExperimentTableWithKey:[OCMArg any]
                                                values:[OCMArg any]
                                     completionHandler:[OCMArg any]])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained RCNDBCompletion completion;
        [invocation getArgument:&completion atIndex:4];
        if (completion) {
          completion(YES, nil);
        }
      });

  RCNConfigExperiment *experiment = [[RCNConfigExperiment alloc] initWithDBManager:dbManagerMock
                                                              experimentController:nil];
  NSDictionary<NSString *, NSString *> *newPayload = @{@"experimentId" : @"new"};
  [experiment updateExperimentsWithResponse:@[ newPayload ]];
  [experiment updateExperimentsWithHandler:nil];

  NSDictionary<NSString *, NSString *> *stalePayload = @{@"experimentId" : @"stale"};
  NSData *stalePayloadData = [NSJSONSerialization dataWithJSONObject:stalePayload
                                                             options:0
                                                               error:nil];
  databaseLoadCompletion(YES, @{
    @RCNExperimentTableKeyPayload : @[ stalePayloadData ],
    @RCNExperimentTableKeyMetadata : @{@"last_experiment_start_time" : @123},
    @RCNExperimentTableKeyActivePayload : @[ stalePayloadData ]
  });

  NSData *newPayloadData = [NSJSONSerialization dataWithJSONObject:newPayload options:0 error:nil];
  XCTAssertEqualObjects(experiment.experimentPayloads, @[ newPayloadData ]);
  XCTAssertEqualObjects(experiment.experimentMetadata[@"last_experiment_start_time"], @0);
  XCTAssertEqualObjects(experiment.activeExperimentPayloads, @[ newPayloadData ]);
  [dbManagerMock stopMocking];
}

- (void)testActivationRetriesWhenDatabaseLoadPublishesNewerMetadata {
  __block RCNDBCompletion databaseLoadCompletion;
  id dbManagerMock = OCMClassMock([RCNConfigDBManager class]);
  OCMStub([dbManagerMock loadExperimentWithCompletionHandler:[OCMArg any]])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained RCNDBCompletion completion;
        [invocation getArgument:&completion atIndex:2];
        databaseLoadCompletion = [completion copy];
      });
  OCMStub([dbManagerMock insertExperimentTableWithKey:[OCMArg any]
                                                value:[OCMArg any]
                                    completionHandler:nil]);
  OCMStub([dbManagerMock replaceExperimentTableWithKey:[OCMArg any]
                                                values:[OCMArg any]
                                     completionHandler:[OCMArg any]])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained RCNDBCompletion completion;
        [invocation getArgument:&completion atIndex:4];
        if (completion) {
          completion(YES, nil);
        }
      });

  FIRExperimentController *experimentController =
      [[FIRExperimentController alloc] initWithAnalytics:nil];
  id mockExperimentController = OCMPartialMock(experimentController);
  dispatch_semaphore_t calculationStarted = dispatch_semaphore_create(0);
  dispatch_semaphore_t continueCalculation = dispatch_semaphore_create(0);
  NSTimeInterval testTimeout = _expectationTimeout;
  __block NSUInteger calculationCount = 0;
  __block intptr_t calculationWaitResult = 0;
  OCMStub([mockExperimentController latestExperimentStartTimestampBetweenTimestamp:0
                                                                       andPayloads:[OCMArg any]])
      .ignoringNonObjectArgs()
      .andDo(^(NSInvocation *invocation) {
        NSTimeInterval existingLastStartTime;
        [invocation getArgument:&existingLastStartTime atIndex:2];
        calculationCount += 1;
        if (calculationCount == 1) {
          dispatch_semaphore_signal(calculationStarted);
          calculationWaitResult = dispatch_semaphore_wait(
              continueCalculation,
              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(testTimeout * NSEC_PER_SEC)));
        }
        NSTimeInterval result = existingLastStartTime + 1;
        [invocation setReturnValue:&result];
      });
  OCMStub(
      [mockExperimentController
          updateExperimentsWithServiceOrigin:[OCMArg any]
                                      events:[OCMArg any]
                                      policy:
                                          ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest  // NOLINT
                               lastStartTime:0
                                    payloads:[OCMArg any]
                           completionHandler:([OCMArg invokeBlockWithArgs:[NSNull null], nil])])
      .ignoringNonObjectArgs();

  RCNConfigExperiment *experiment =
      [[RCNConfigExperiment alloc] initWithDBManager:dbManagerMock
                                experimentController:mockExperimentController];
  NSDictionary<NSString *, NSString *> *newPayload = @{@"experimentId" : @"new"};
  [experiment updateExperimentsWithResponse:@[ newPayload ]];

  XCTestExpectation *activationExpectation =
      [self expectationWithDescription:@"Activation uses the loaded metadata"];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
    [experiment updateExperimentsWithHandler:^(NSError *_Nullable error) {
      XCTAssertNil(error);
      [activationExpectation fulfill];
    }];
  });

  XCTAssertEqual(dispatch_semaphore_wait(
                     calculationStarted,
                     dispatch_time(DISPATCH_TIME_NOW, (int64_t)(testTimeout * NSEC_PER_SEC))),
                 0);
  NSDictionary<NSString *, NSString *> *stalePayload = @{@"experimentId" : @"stale"};
  NSData *stalePayloadData = [NSJSONSerialization dataWithJSONObject:stalePayload
                                                             options:0
                                                               error:nil];
  databaseLoadCompletion(YES, @{
    @RCNExperimentTableKeyPayload : @[ stalePayloadData ],
    @RCNExperimentTableKeyMetadata : @{@"last_experiment_start_time" : @100},
    @RCNExperimentTableKeyActivePayload : @[ stalePayloadData ]
  });
  dispatch_semaphore_signal(continueCalculation);

  [self waitForExpectationsWithTimeout:testTimeout handler:nil];
  NSData *newPayloadData = [NSJSONSerialization dataWithJSONObject:newPayload options:0 error:nil];
  XCTAssertEqual(calculationWaitResult, 0, @"Activation calculation timed out");
  XCTAssertEqual(calculationCount, 2);
  XCTAssertEqualObjects(experiment.experimentMetadata[@"last_experiment_start_time"], @101);
  XCTAssertEqualObjects(experiment.activeExperimentPayloads, @[ newPayloadData ]);
  [dbManagerMock stopMocking];
}

- (void)testUpdateLastExperimentStartTime {
  [_configExperiment updateExperimentStartTime];
  XCTAssertEqualObjects(_configExperiment.experimentMetadata[@"last_experiment_start_time"], @(0));

  NSDictionary<NSString *, NSString *> *payload =
      @{@"experimentStartTime" : @"2019-04-04T21:54:38.555Z"};
  [_configExperiment updateExperimentsWithResponse:@[ payload ]];
  [_configExperiment updateExperimentStartTime];

  int64_t originalTime = [self convertTimeToMillis:@"2019-04-04T21:54:38.555Z"] / 1000;
  int64_t time =
      ([_configExperiment.experimentMetadata[@"last_experiment_start_time"] doubleValue]);
  XCTAssertEqual(time, originalTime);
}

- (void)testMultipleUpdatesToLastExperimentStartTime {
  [_configExperiment updateExperimentStartTime];
  XCTAssertEqualObjects(_configExperiment.experimentMetadata[@"last_experiment_start_time"], @(0));

  NSDictionary<NSString *, NSString *> *payload =
      @{@"experimentStartTime" : @"2019-04-04T21:54:38.555Z"};
  [_configExperiment updateExperimentsWithResponse:@[ payload ]];
  [_configExperiment updateExperimentStartTime];

  int64_t originalTime = [self convertTimeToMillis:@"2019-04-04T21:54:38.555Z"] / 1000;
  int64_t time =
      ([_configExperiment.experimentMetadata[@"last_experiment_start_time"] doubleValue]);
  XCTAssertEqual(time, originalTime);

  // Update start time again.
  payload = @{@"experimentStartTime" : @"2019-04-04T21:55:38.555Z"};
  [_configExperiment updateExperimentsWithResponse:@[ payload ]];
  [_configExperiment updateExperimentStartTime];

  originalTime = [self convertTimeToMillis:@"2019-04-04T21:55:38.555Z"] / 1000;
  time = ([_configExperiment.experimentMetadata[@"last_experiment_start_time"] doubleValue]);
  XCTAssertEqual(time, originalTime);
}

- (void)testUpdateLastExperimentStartTimeInThePast {
  NSDictionary<NSString *, NSString *> *payload =
      @{@"experimentStartTime" : @"2019-04-04T21:55:38.555Z"};
  [_configExperiment updateExperimentsWithResponse:@[ payload ]];
  [_configExperiment updateExperimentStartTime];

  int64_t originalTime = [self convertTimeToMillis:@"2019-04-04T21:55:38.555Z"] / 1000;
  int64_t time =
      ([_configExperiment.experimentMetadata[@"last_experiment_start_time"] doubleValue]);
  XCTAssertEqual(time, originalTime);

  payload = @{@"experimentStartTime" : @"2018-04-04T21:55:38.555Z"};
  [_configExperiment updateExperimentsWithResponse:@[ payload ]];
  [_configExperiment updateExperimentStartTime];

  originalTime = [self convertTimeToMillis:@"2019-04-04T21:55:38.555Z"] / 1000;
  time = ([_configExperiment.experimentMetadata[@"last_experiment_start_time"] doubleValue]);
  XCTAssertEqual(time, originalTime);
}

- (void)testUpdateLastExperimentStartTimeInTheFuture {
  NSDictionary<NSString *, NSString *> *payload =
      @{@"experimentStartTime" : @"2020-04-04T21:55:38.555Z"};
  [_configExperiment updateExperimentsWithResponse:@[ payload ]];
  [_configExperiment updateExperimentStartTime];

  int64_t originalTime = [self convertTimeToMillis:@"2020-04-04T21:55:38.555Z"] / 1000;
  int64_t time =
      ([_configExperiment.experimentMetadata[@"last_experiment_start_time"] doubleValue]);
  XCTAssertEqual(time, originalTime);
}

- (void)testUpdateExperiments {
  FIRExperimentController *experimentController =
      [[FIRExperimentController alloc] initWithAnalytics:nil];
  id mockExperimentController = OCMPartialMock(experimentController);
  RCNConfigExperiment *experiment =
      [[RCNConfigExperiment alloc] initWithDBManager:_DBManagerMock
                                experimentController:mockExperimentController];

  NSTimeInterval lastStartTime =
      [experiment.experimentMetadata[@"last_experiment_start_time"] doubleValue];
  OCMStub([mockExperimentController
      updateExperimentsWithServiceOrigin:[OCMArg any]
                                  events:[OCMArg any]
                                  policy:
                                      ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest  // NOLINT
                           lastStartTime:lastStartTime
                                payloads:[OCMArg any]
                       completionHandler:([OCMArg invokeBlockWithArgs:[NSNull null], nil])]);

  NSData *payloadData = [[self class] payloadDataFromTestFile];

  experiment.experimentPayloads = [@[ payloadData ] mutableCopy];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Experiments are updated after persistence"];
  [experiment updateExperimentsWithHandler:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(experiment.experimentMetadata[@"last_experiment_start_time"],
                          @(12345678));
    XCTAssertEqualObjects(experiment.activeExperimentPayloads, @[ payloadData ]);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
  OCMVerify([_DBManagerMock replaceExperimentTableWithKey:@RCNExperimentTableKeyActivePayload
                                                   values:@[ payloadData ]
                                        completionHandler:[OCMArg any]]);
}

- (void)testAnalyticsUpdateWaitsForActiveExperimentPersistence {
  RCNControllableExperimentDBManager *dbManager = [[RCNControllableExperimentDBManager alloc] init];
  [dbManager waitForDatabaseOperationQueue];
  FIRExperimentController *experimentController =
      [[FIRExperimentController alloc] initWithAnalytics:nil];
  id mockExperimentController = OCMPartialMock(experimentController);
  RCNConfigExperiment *experiment =
      [[RCNConfigExperiment alloc] initWithDBManager:dbManager
                                experimentController:mockExperimentController];
  NSData *payloadData = [[self class] payloadDataFromTestFile];
  experiment.experimentPayloads = @[ payloadData ];

  __block BOOL didUpdateAnalytics = NO;
  OCMStub(
      [mockExperimentController
          updateExperimentsWithServiceOrigin:[OCMArg any]
                                      events:[OCMArg any]
                                      policy:
                                          ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest  // NOLINT
                               lastStartTime:0
                                    payloads:[OCMArg any]
                           completionHandler:[OCMArg any]])
      .ignoringNonObjectArgs()
      .andDo(^(NSInvocation *invocation) {
        didUpdateAnalytics = YES;
        __unsafe_unretained void (^completionHandler)(NSError *_Nullable error);
        [invocation getArgument:&completionHandler atIndex:7];
        void (^completionHandlerCopy)(NSError *_Nullable error) = [completionHandler copy];
        dbManager.loadsPersistedExperiments = YES;
        [dbManager loadExperimentWithCompletionHandler:^(BOOL success,
                                                         NSDictionary<NSString *, id> *state) {
          XCTAssertTrue(success);
          XCTAssertEqualObjects(state[@RCNExperimentTableKeyActivePayload], @[ payloadData ]);
          XCTAssertEqualObjects(
              state[@RCNExperimentTableKeyMetadata][@"last_experiment_start_time"], @(12345678));
          completionHandlerCopy(nil);
        }];
      });

  XCTestExpectation *expectation = [self expectationWithDescription:@"Analytics update completes"];
  [experiment updateExperimentsWithHandler:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];

  XCTAssertEqualObjects(dbManager.pendingExperimentKey, @RCNExperimentTableKeyActivePayload);
  XCTAssertEqualObjects(dbManager.pendingExperimentValues, @[ payloadData ]);
  XCTAssertFalse(didUpdateAnalytics);
  [dbManager persistPendingExperiments];

  [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
  XCTAssertTrue(didUpdateAnalytics);
}

- (void)testUpdateExperimentsWithNilExperimentController {
  RCNConfigExperiment *experiment = [[RCNConfigExperiment alloc] initWithDBManager:_DBManagerMock
                                                              experimentController:nil];

  NSData *payloadData = [[self class] payloadDataFromTestFile];
  experiment.experimentPayloads = [@[ payloadData ] mutableCopy];

  XCTestExpectation *expectation = [self
      expectationWithDescription:@"Completion handler is called when experimentController is nil"];

  [experiment updateExperimentsWithHandler:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(experiment.experimentMetadata[@"last_experiment_start_time"], @(0));
    XCTAssertEqualObjects(experiment.activeExperimentPayloads, @[ payloadData ]);
    [expectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
}

#pragma mark Helpers.

- (ABTExperimentPayload *)deserializeABTData:(NSData *)payload {
  return [ABTExperimentPayload parseFromData:payload];
}

- (int64_t)convertTimeToMillis:(NSString *)time {
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
  [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
  // Locale needs to be hardcoded. See
  // https://developer.apple.com/library/ios/#qa/qa1480/_index.html for more details.
  [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
  [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
  NSDate *experimentStartTime = [dateFormatter dateFromString:time];
  return [@([experimentStartTime timeIntervalSince1970] * 1000) longLongValue];
}

+ (NSData *)payloadDataFromTestFile {
#if SWIFT_PACKAGE
  NSBundle *bundle = SWIFTPM_MODULE_BUNDLE;
#else
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
#endif
  NSString *testJsonDataFilePath = [bundle pathForResource:@"TestABTPayload" ofType:@"txt"];
  NSError *readTextError = nil;
  NSString *fileText = [[NSString alloc] initWithContentsOfFile:testJsonDataFilePath
                                                       encoding:NSUTF8StringEncoding
                                                          error:&readTextError];

  NSData *fileData = [fileText dataUsingEncoding:kCFStringEncodingUTF8];

  NSError *jsonDictionaryError = nil;
  NSMutableDictionary *jsonDictionary =
      [[NSJSONSerialization JSONObjectWithData:fileData
                                       options:kNilOptions
                                         error:&jsonDictionaryError] mutableCopy];
  NSError *jsonDataError = nil;
  return [NSJSONSerialization dataWithJSONObject:jsonDictionary
                                         options:kNilOptions
                                           error:&jsonDataError];
}

@end
