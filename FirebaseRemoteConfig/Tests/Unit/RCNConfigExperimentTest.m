#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigExperiment.h"

#import <XCTest/XCTest.h>

#import "googlemac/iPhone/Config/RemoteConfig/Source/FIRRemoteConfig.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigDBManager.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigDefines.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigSettings.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigValue_Internal.h"
#import "googlemac/iPhone/Config/RemoteConfig/Tests/UnitTestsNew/RCNTestUtilities.h"

#import "third_party/firebase/ios/Releases/FirebaseABTesting/Sources/Public/FIRExperimentController.h"

#import "developers/mobile/abt/proto/ExperimentPayload.pbobjc.h"
#import "wireless/android/config/proto/Config.pbobjc.h"
#import "third_party/firebase/ios/Releases/FirebaseInterop/Analytics/Public/FIRAnalyticsInterop.h"
#import "third_party/objective_c/ocmock/v3/Source/OCMock/OCMock.h"

// Surface the internal FIRExperimentController initializer.
@interface FIRExperimentController ()
- (instancetype)initWithAnalytics:(nullable id<FIRAnalyticsInterop>)analytics;
@end

@interface RCNConfigExperiment ()
@property(nonatomic, copy) NSMutableArray *experimentPayloads;
@property(nonatomic, copy) NSMutableDictionary *experimentMetadata;
@property(nonatomic, strong) RCNConfigDBManager *DBManager;
- (NSTimeInterval)updateExperimentStartTime;
- (void)loadExperimentFromTable;
@end

@interface RCNConfigExperimentTest : XCTestCase {
  NSTimeInterval _expectationTimeout;
  FIRExperimentController *_experimentController;
  RCNConfigExperiment *_configExperiment;
  id _DBManagerMock;
  NSArray<NSDictionary<NSString *, id> *> *_payloads;
  NSArray<NSData *> *_payloadsData;
  NSDictionary<NSString *, NSString *> *_metadata;
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
  _metadata = @{ @"last_know_start_time" : @12348765 };
  NSDictionary<NSString *, NSString *> *mockResults = @{
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

  XCTAssertEqualObjects(_metadata, _configExperiment.experimentMetadata);
}

- (void)testUpdateExperiment {
  RCNAppConfigTable *appTable = [[RCNAppConfigTable alloc] init];
  appTable.appName = [NSBundle mainBundle].bundleIdentifier;
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
    [[RCNConfigExperiment alloc] initWithDBManager:_DBManagerMock
                              experimentController:mockExperimentController];

  NSTimeInterval lastStartTime =
      [experiment.experimentMetadata[@"last_experiment_start_time"] doubleValue];
  OCMStub(
      [mockExperimentController
          updateExperimentsWithServiceOrigin:[OCMArg any]
                                      events:[OCMArg any]
                                      policy:
                                          ABTExperimentPayload_ExperimentOverflowPolicy_DiscardOldest  // NOLINT
                               lastStartTime:lastStartTime
                                    payloads:[OCMArg any]])
      .andDo(nil);

  ABTExperimentPayload *payload = [[ABTExperimentPayload alloc] init];
  payload.experimentStartTimeMillis = 12345678000;

  experiment.experimentPayloads = [@[ payload.data ] mutableCopy];

  [experiment updateExperiments];
  XCTAssertEqualObjects(experiment.experimentMetadata[@"last_experiment_start_time"],
                        @(12345678));
}

#pragma mark Helpers.

- (ABTExperimentPayload *)deserializeABTData:(NSData *)payload {
  NSError *error;
  ABTExperimentPayload *experimentPayload = [ABTExperimentPayload parseFromData:payload
                                                                          error:&error];
  if (error) {
    return nil;
  }
  return experimentPayload;
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
@end
