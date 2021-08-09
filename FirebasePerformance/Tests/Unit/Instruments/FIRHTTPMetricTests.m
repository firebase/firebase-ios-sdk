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

#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRRemoteConfigFlags.h"
#import "FirebasePerformance/Sources/FPRClient.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRHTTPMetric.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"

#import "FirebasePerformance/Sources/Instrumentation/FIRHTTPMetric+Private.h"

#import "FirebasePerformance/Tests/Unit/Configurations/FPRFakeRemoteConfig.h"
#import "FirebasePerformance/Tests/Unit/FPRTestCase.h"

#import <OCMock/OCMock.h>

@interface FIRHTTPMetricTests : FPRTestCase

@property(nonatomic, strong) NSURL *sampleURL;

@end

@implementation FIRHTTPMetricTests

- (void)tearDown {
  [super tearDown];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:NO];
  [performance setInstrumentationEnabled:NO];
}

- (void)setUp {
  [super setUp];
  self.sampleURL = [NSURL URLWithString:@"https://a1b2c3d4.com"];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:YES];
  [performance setInstrumentationEnabled:NO];
}

#pragma mark - HTTP Metric creation tests.

/** Validates instance creation. */
- (void)testInstanceCreation {
  XCTAssertNotNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodGET]);
  XCTAssertNotNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodPUT]);
  XCTAssertNotNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodPOST]);
  XCTAssertNotNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                          HTTPMethod:FIRHTTPMethodCONNECT]);
  XCTAssertNotNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                          HTTPMethod:FIRHTTPMethodOPTIONS]);
  XCTAssertNotNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodHEAD]);
  XCTAssertNotNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                          HTTPMethod:FIRHTTPMethodDELETE]);
  XCTAssertNotNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodPATCH]);
  XCTAssertNotNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodTRACE]);
}

/** Validates instance creation when data collection is disabled. */
- (void)testInstanceCreationWhenDataCollectionDisabled {
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:NO];
  XCTAssertNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodGET]);
  XCTAssertNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodPUT]);
  XCTAssertNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodPOST]);
  XCTAssertNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodCONNECT]);
  XCTAssertNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodOPTIONS]);
  XCTAssertNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodHEAD]);
  XCTAssertNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodDELETE]);
  XCTAssertNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodPATCH]);
  XCTAssertNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodTRACE]);
}

/** Validates if HTTPMetric creation fails when SDK flag is disabled in remote config. */
- (void)testMetricCreationWhenSDKFlagDisabled {
  FPRConfigurations *configurations = [FPRConfigurations sharedInstance];
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;

  NSData *valueData = [@"false" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_enabled"];

  // Trigger the RC config fetch
  remoteConfig.lastFetchTime = nil;
  [configFlags update];

  XCTAssertNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodGET]);
}

/** Validates if HTTPMetric creation succeeds when SDK flag is enabled in remote config. */
- (void)testMetricCreationWhenSDKFlagEnabled {
  FPRConfigurations *configurations = [FPRConfigurations sharedInstance];
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey = [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_enabled"];
  [userDefaults setObject:@(TRUE) forKey:configKey];

  XCTAssertNotNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodGET]);
}

/** Validates if HTTPMetric creation fails when SDK flag is enabled in remote config, but data
 * collection disabled. */
- (void)testMetricCreationWhenSDKFlagEnabledWithDataCollectionDisabled {
  [[FIRPerformance sharedInstance] setDataCollectionEnabled:NO];
  FPRConfigurations *configurations = [FPRConfigurations sharedInstance];
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;

  NSData *valueData = [@"true" dataUsingEncoding:NSUTF8StringEncoding];
  FIRRemoteConfigValue *value =
      [[FIRRemoteConfigValue alloc] initWithData:valueData source:FIRRemoteConfigSourceRemote];
  [remoteConfig.configValues setObject:value forKey:@"fpr_enabled"];

  XCTAssertNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:FIRHTTPMethodGET]);
}

/** Validates that metric creation fails for invalid inputs. */
- (void)testInstanceCreationForInvalidInputs {
  XCTAssertNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:-1]);
  XCTAssertNil([[FIRHTTPMetric alloc] initWithURL:self.sampleURL HTTPMethod:100]);
}

/** Validate if the metric creation succeeds with right values. */
- (void)testMetricCreationSucceeds {
  id mock = [OCMockObject partialMockForObject:[FPRClient sharedInstance]];
  OCMStub([mock logNetworkTrace:[OCMArg any]]).andDo(nil);
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric start];
  [metric markRequestComplete];
  metric.responsePayloadSize = 300;
  metric.requestPayloadSize = 100;
  metric.responseCode = 200;
  metric.responseContentType = @"text/json";
  [metric markResponseStart];
  [metric stop];
  FPRNetworkTrace *networkTrace = metric.networkTrace;
  XCTAssertEqualObjects(networkTrace.URLRequest.URL, self.sampleURL);
  XCTAssertEqual(networkTrace.requestSize, 100);
  XCTAssertEqual(networkTrace.responseSize, 300);
  XCTAssertEqual(networkTrace.responseCode, 200);
  XCTAssertEqualObjects(networkTrace.responseContentType, @"text/json");
}

/** Validate if the network trace is invalid if the response code is not set. */
- (void)testMetricCreationFailsWhenResponseCodeNotSet {
  id mock = [OCMockObject partialMockForObject:[FPRClient sharedInstance]];
  OCMStub([mock logNetworkTrace:[OCMArg any]]).andDo(nil);
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric start];
  [metric markRequestComplete];
  metric.responsePayloadSize = 0;
  metric.responseContentType = @"text/json";
  [metric markResponseStart];
  [metric stop];
  FPRNetworkTrace *networkTrace = metric.networkTrace;
  XCTAssertFalse([networkTrace isValid]);
}

/** Validates that starting and stopping logs an event. */
- (void)testValidHTTPMetricBeingSent {
  id mock = [OCMockObject partialMockForObject:[FPRClient sharedInstance]];
  OCMStub([mock logNetworkTrace:[OCMArg any]]).andDo(nil);
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric start];
  [metric markRequestComplete];
  metric.responseCode = 200;
  metric.requestPayloadSize = 200;
  metric.responsePayloadSize = 0;
  metric.responseContentType = @"text/json";
  [metric markResponseStart];
  [metric stop];
  OCMVerify([mock logNetworkTrace:[OCMArg any]]);
}

/** Validates that calling just stop does not log an event. */
- (void)testStartMustBeCalledForLoggingEvent {
  id mock = [OCMockObject partialMockForObject:[FPRClient sharedInstance]];
  OCMStub([mock logNetworkTrace:[OCMArg any]]).andDo(nil);
  [[mock reject] logNetworkTrace:[OCMArg any]];
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  metric.responseCode = 200;
  metric.requestPayloadSize = 200;
  metric.responsePayloadSize = 0;
  metric.responseContentType = @"text/json";
  [metric stop];
}

/** Validates that calling stop twice does not log the event again. */
- (void)testSameEventNotGettingLoggedTwice {
  id mock = [OCMockObject partialMockForObject:[FPRClient sharedInstance]];
  OCMStub([mock logNetworkTrace:[OCMArg any]]).andDo(nil);
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric start];
  metric.responseCode = 200;
  metric.requestPayloadSize = 200;
  metric.responsePayloadSize = 0;
  metric.responseContentType = @"text/json";
  [metric stop];
  OCMVerify([mock logNetworkTrace:[OCMArg any]]);
  [[mock reject] logNetworkTrace:[OCMArg any]];
  [metric stop];
}

#pragma mark - Custom attribute related testing

/** Validates if setting a valid attribute before calling start works. */
- (void)testSettingValidAttributeBeforeStart {
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric setValue:@"bar" forAttribute:@"foo"];
  XCTAssertEqual([metric valueForAttribute:@"foo"], @"bar");
}

/** Validates if setting a valid attribute works between start/stop works. */
- (void)testSettingValidAttributeBetweenStartAndStop {
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric start];
  [metric setValue:@"bar" forAttribute:@"foo"];
  XCTAssertEqual([metric valueForAttribute:@"foo"], @"bar");
  [metric stop];
}

/** Validates if setting a valid attribute works after stop is a no-op. */
- (void)testSettingValidAttributeBetweenAfterStop {
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric start];
  metric.responseCode = 200;
  [metric stop];
  [metric setValue:@"bar" forAttribute:@"foo"];
  XCTAssertNil([metric valueForAttribute:@"foo"]);
}

/** Validates if attributes property access works. */
- (void)testReadingAttributesFromProperty {
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  XCTAssertNotNil(metric.attributes);
  XCTAssertEqual(metric.attributes.count, 0);
  [metric setValue:@"bar" forAttribute:@"foo"];
  NSDictionary<NSString *, NSString *> *attributes = metric.attributes;
  XCTAssertEqual(attributes.allKeys.count, 1);
}

/** Validates if attributes property is immutable. */
- (void)testImmutablityOfAttributesProperty {
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric setValue:@"bar" forAttribute:@"foo"];
  NSMutableDictionary<NSString *, NSString *> *attributes =
      (NSMutableDictionary<NSString *, NSString *> *)metric.attributes;
  XCTAssertThrows([attributes setValue:@"bar1" forKey:@"foo"]);
}

/** Validates if updating attribute value works. */
- (void)testUpdatingAttributeValue {
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric setValue:@"bar" forAttribute:@"foo"];
  [metric setValue:@"baz" forAttribute:@"foo"];
  XCTAssertEqual(@"baz", [metric valueForAttribute:@"foo"]);
  [metric setValue:@"qux" forAttribute:@"foo"];
  XCTAssertEqual(@"qux", [metric valueForAttribute:@"foo"]);
}

/** Validates if removing attributes work before call to start. */
- (void)testRemovingAttributeBeforeStart {
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric setValue:@"bar" forAttribute:@"foo"];
  [metric removeAttribute:@"foo"];
  XCTAssertNil([metric valueForAttribute:@"foo"]);
  [metric removeAttribute:@"foo"];
  XCTAssertNil([metric valueForAttribute:@"foo"]);
}

/** Validates if removing attributes work between start and stop calls. */
- (void)testRemovingAttributeBetweenStartStop {
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric setValue:@"bar" forAttribute:@"foo"];
  [metric start];
  [metric removeAttribute:@"foo"];
  [metric stop];
  XCTAssertNil([metric valueForAttribute:@"foo"]);
}

/** Validates if removing attributes is a no-op after stop. */
- (void)testRemovingAttributeBetweenAfterStop {
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric setValue:@"bar" forAttribute:@"foo"];
  [metric start];
  metric.responseCode = 200;
  [metric stop];
  [metric removeAttribute:@"foo"];
  XCTAssertEqual([metric valueForAttribute:@"foo"], @"bar");
}

/** Validates if removing non-existing attributes works. */
- (void)testRemovingNonExistingAttribute {
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric removeAttribute:@"foo"];
  XCTAssertNil([metric valueForAttribute:@"foo"]);
  [metric removeAttribute:@"foo"];
  XCTAssertNil([metric valueForAttribute:@"foo"]);
}

/** Validates if using reserved prefix in attribute prefix will drop the attribute. */
- (void)testAttributeNamePrefixSrtipped {
  NSArray<NSString *> *reservedPrefix = @[ @"firebase_", @"google_", @"ga_" ];

  [reservedPrefix enumerateObjectsUsingBlock:^(NSString *prefix, NSUInteger idx, BOOL *stop) {
    NSString *attributeName = [NSString stringWithFormat:@"%@name", prefix];
    NSString *attributeValue = @"value";

    FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                    HTTPMethod:FIRHTTPMethodGET];
    [metric setValue:attributeValue forAttribute:attributeName];
    XCTAssertNil([metric valueForAttribute:attributeName]);
  }];
}

/** Validates if long attribute names gets dropped. */
- (void)testMaxLengthForAttributeName {
  NSString *testName = [@"abc" stringByPaddingToLength:kFPRMaxAttributeNameLength + 1
                                            withString:@"-"
                                       startingAtIndex:0];
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric setValue:@"bar" forAttribute:testName];
  XCTAssertNil([metric valueForAttribute:testName]);
}

/** Validates if attribute names with illegal characters gets dropped. */
- (void)testIllegalCharactersInAttributeName {
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric setValue:@"bar" forAttribute:@"foo_"];
  XCTAssertEqual([metric valueForAttribute:@"foo_"], @"bar");
  [metric setValue:@"bar" forAttribute:@"foo_$"];
  XCTAssertNil([metric valueForAttribute:@"foo_$"]);
  [metric setValue:@"bar" forAttribute:@"FOO_$"];
  XCTAssertNil([metric valueForAttribute:@"FOO_$"]);
  [metric setValue:@"bar" forAttribute:@"FOO_"];
  XCTAssertEqual([metric valueForAttribute:@"FOO_"], @"bar");
}

/** Validates if long attribute values gets truncated. */
- (void)testMaxLengthForAttributeValue {
  NSString *testValue = [@"abc" stringByPaddingToLength:kFPRMaxAttributeValueLength + 1
                                             withString:@"-"
                                        startingAtIndex:0];
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric setValue:testValue forAttribute:@"foo"];
  XCTAssertNil([metric valueForAttribute:@"foo"]);
}

/** Validates if empty name or value of the attributes are getting dropped. */
- (void)testAttributesWithEmptyValues {
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  [metric setValue:@"" forAttribute:@"foo"];
  XCTAssertNil([metric valueForAttribute:@"foo"]);
  [metric setValue:@"bar" forAttribute:@""];
  XCTAssertNil([metric valueForAttribute:@""]);
}

/** Validates if the limit the maximum number of attributes work. */
- (void)testMaximumNumberOfAttributes {
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  for (int i = 0; i < kFPRMaxGlobalCustomAttributesCount; i++) {
    NSString *attributeName = [NSString stringWithFormat:@"dim%d", i];
    [metric setValue:@"bar" forAttribute:attributeName];
    XCTAssertEqual([metric valueForAttribute:attributeName], @"bar");
  }
  [metric setValue:@"bar" forAttribute:@"foo"];
  XCTAssertNil([metric valueForAttribute:@"foo"]);
}

/** Validates if removing old attributes and adding new attributes work. */
- (void)testRemovingAndAddingAttributes {
  FIRHTTPMetric *metric = [[FIRHTTPMetric alloc] initWithURL:self.sampleURL
                                                  HTTPMethod:FIRHTTPMethodGET];
  for (int i = 0; i < kFPRMaxGlobalCustomAttributesCount; i++) {
    NSString *attributeName = [NSString stringWithFormat:@"dim%d", i];
    [metric setValue:@"bar" forAttribute:attributeName];
    XCTAssertEqual([metric valueForAttribute:attributeName], @"bar");
  }
  [metric removeAttribute:@"dim1"];
  [metric setValue:@"bar" forAttribute:@"foo"];
  XCTAssertEqual([metric valueForAttribute:@"foo"], @"bar");
}

@end
