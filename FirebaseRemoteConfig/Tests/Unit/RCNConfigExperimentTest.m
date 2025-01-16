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

@import FirebaseRemoteConfig;

#import "FirebaseRemoteConfig/Sources/Public/FirebaseRemoteConfig/FIRRemoteConfig.h"
#import "FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.h"

#import "FirebaseABTesting/Sources/Private/FirebaseABTestingInternal.h"

#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

#import "FirebaseRemoteConfig/FirebaseRemoteConfig-Swift.h"

// Surface the internal FIRExperimentController initializer.
@interface FIRExperimentController ()
- (instancetype)initWithAnalytics:(nullable id<FIRAnalyticsInterop>)analytics;
@end

@interface RCNConfigExperiment ()
@property(nonatomic, copy) NSMutableArray *experimentPayloads;
@property(nonatomic, copy) NSMutableDictionary *experimentMetadata;
@property(nonatomic, copy) NSMutableArray *activeExperimentPayloads;
- (NSTimeInterval)updateExperimentStartTime;
- (void)loadExperimentFromTable;
- (void)updateActiveExperimentsInDB;
@end

@interface RCNConfigExperimentTest : XCTestCase {
  NSTimeInterval _expectationTimeout;
  FIRExperimentController *_experimentController;
  RCNConfigExperiment *_configExperiment;
  NSArray<NSDictionary<NSString *, id> *> *_payloads;
  NSArray<NSData *> *_payloadsData;
  NSDictionary<NSString *, NSNumber *> *_metadata;
  NSString *_DBPath;
}
@property(nonatomic, strong) RCNConfigDBManager *DBManager;
@end

@implementation RCNConfigExperimentTest
- (void)setUp {
  [super setUp];
  _expectationTimeout = 1.0;
  _DBPath = [RCNTestUtilities remoteConfigPathForTestDatabase];
  _DBManager = [[RCNConfigDBManager alloc] initWithDbPath:_DBPath];

  FIRExperimentController *experimentController =
      [[FIRExperimentController alloc] initWithAnalytics:nil];
  _configExperiment = [[RCNConfigExperiment alloc] initWithDbManager:_DBManager
                                                experimentController:experimentController];
}

- (void)tearDown {
  [super tearDown];
}

//- (void)testInitMethod {
//  OCMVerify([_DBManagerMock loadExperimentWithCompletionHandler:[OCMArg any]]);
//}

// TODO: This test depends on mocking _DBManagerMock loadExperimentWithCompletionHandler:
// Replace by subclassing or another means.
- (void)SKIPtestLoadExperimentFromTable {
  [_configExperiment updateActiveExperimentsInDB];
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
      [[RCNConfigExperiment alloc] initWithDbManager:_DBManager
                                experimentController:mockExperimentController];

  NSTimeInterval lastStartTime =
      [experiment.experimentMetadata[@"last_experiment_start_time"] doubleValue];
  OCMStub(
      [mockExperimentController
          updateExperimentsWithServiceOrigin:[OCMArg any]
                                      events:[OCMArg any]
                                      policy:
                                          ABTExperimentPayloadExperimentOverflowPolicyDiscardOldest  // NOLINT
                               lastStartTime:lastStartTime
                                    payloads:[OCMArg any]
                           completionHandler:[OCMArg any]])
      .andDo(nil);

  NSData *payloadData = [[self class] payloadDataFromTestFile];

  experiment.experimentPayloads = [@[ payloadData ] mutableCopy];

  [experiment updateExperimentsWithHandler:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(experiment.experimentMetadata[@"last_experiment_start_time"],
                          @(12345678));
    OCMVerify([experiment updateActiveExperimentsInDB]);
    XCTAssertEqualObjects(experiment.activeExperimentPayloads, @[ payloadData ]);
  }];
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
