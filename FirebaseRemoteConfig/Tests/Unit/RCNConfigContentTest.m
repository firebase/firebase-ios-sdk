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

#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"
#import "FirebaseRemoteConfig/Sources/Public/FirebaseRemoteConfig/FIRRemoteConfig.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigContent.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigValue_Internal.h"
#import "FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.h"

@interface RCNConfigContent (Testing)
- (BOOL)checkAndWaitForInitialDatabaseLoad;
@end

extern const NSTimeInterval kDatabaseLoadTimeoutSecs;
@interface RCNConfigDBManagerMock : RCNConfigDBManager
@property(nonatomic, assign) BOOL isLoadMainCompleted;
@property(nonatomic, assign) BOOL isLoadPersonalizationCompleted;
@end
@implementation RCNConfigDBManagerMock
- (void)createOrOpenDatabase {
}
- (void)loadMainWithBundleIdentifier:(NSString *)bundleIdentifier
                   completionHandler:(RCNDBLoadCompletion)handler {
  double justSmallDelay = 0.008;
  XCTAssertTrue(justSmallDelay < kDatabaseLoadTimeoutSecs);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(justSmallDelay * NSEC_PER_SEC)),
                 dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                   self.isLoadMainCompleted = YES;
                   handler(YES, nil, nil, nil);
                 });
}
- (void)loadPersonalizationWithCompletionHandler:(RCNDBLoadCompletion)handler {
  double justOtherSmallDelay = 0.009;
  XCTAssertTrue(justOtherSmallDelay < kDatabaseLoadTimeoutSecs);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(justOtherSmallDelay * NSEC_PER_SEC)),
                 dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                   self.isLoadPersonalizationCompleted = YES;
                   handler(YES, nil, nil, nil);
                 });
}
@end

@interface RCNConfigContentTest : XCTestCase {
  NSTimeInterval _expectationTimeout;
  RCNConfigContent *_configContent;
  NSString *namespaceApp1, *namespaceApp2;
}
@end

/// Unit Tests for RCNConfigContent methods.
@implementation RCNConfigContentTest
- (void)setUp {
  [super setUp];
  _expectationTimeout = 1.0;

  namespaceApp1 = [NSString
      stringWithFormat:@"%@:%@", FIRNamespaceGoogleMobilePlatform, RCNTestsDefaultFIRAppName];
  namespaceApp2 = [NSString
      stringWithFormat:@"%@:%@", FIRNamespaceGoogleMobilePlatform, RCNTestsSecondFIRAppName];

  _configContent = [[RCNConfigContent alloc] initWithDBManager:nil];

  id partialMock = OCMPartialMock(_configContent);
  OCMStub([partialMock checkAndWaitForInitialDatabaseLoad]).andDo(nil);
}

/// Passing in a nil bundleID should not crash the app
- (void)testCrashShouldNotHappenWithoutMainBundleID {
  id mockBundle = OCMPartialMock([NSBundle mainBundle]);
  OCMStub([mockBundle bundleIdentifier]).andReturn(nil);
  _configContent = [[RCNConfigContent alloc] initWithDBManager:nil];
  [mockBundle stopMocking];
}

/// Standard test case of receiving updated config from fetch.
- (void)testUpdateConfigContentForMultipleApps {
  NSMutableDictionary<NSString *, id> *config1ToSet =
      [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"UPDATE", @"state", nil];
  NSDictionary<NSString *, NSString *> *entries = @{@"key1" : @"value1", @"key2" : @"value2"};
  [config1ToSet setValue:entries forKey:@"entries"];
  [_configContent updateConfigContentWithResponse:config1ToSet forNamespace:namespaceApp1];

  // Update for second app.
  NSMutableDictionary<NSString *, id> *config2ToSet =
      [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"UPDATE", @"state", nil];
  NSDictionary<NSString *, NSString *> *entries2 = @{@"key11" : @"value11", @"key21" : @"value21"};
  [config2ToSet setValue:entries2 forKey:@"entries"];
  [_configContent updateConfigContentWithResponse:config2ToSet forNamespace:namespaceApp2];

  // Check config for first app.

  NSDictionary *fetchedConfig = _configContent.fetchedConfig;
  XCTAssertNotNil(fetchedConfig[namespaceApp1][@"key1"]);
  XCTAssertEqualObjects([fetchedConfig[namespaceApp1][@"key1"] stringValue], @"value1");
  XCTAssertNotNil(fetchedConfig[namespaceApp1][@"key2"]);
  XCTAssertEqualObjects([fetchedConfig[namespaceApp1][@"key2"] stringValue], @"value2");

  // Check config for second app.

  fetchedConfig = _configContent.fetchedConfig;
  XCTAssertNotNil(fetchedConfig[namespaceApp2][@"key11"]);
  XCTAssertEqualObjects([fetchedConfig[namespaceApp2][@"key11"] stringValue], @"value11");
  XCTAssertNotNil(fetchedConfig[namespaceApp2][@"key21"]);
  XCTAssertEqualObjects([fetchedConfig[namespaceApp2][@"key21"] stringValue], @"value21");
}

/// Standard test case of receiving updated config from fetch.
- (void)testUpdateConfigContentWithResponse {
  NSMutableDictionary *configToSet =
      [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"UPDATE", @"state", nil];
  NSDictionary *entries = @{@"key1" : @"value1", @"key2" : @"value2"};
  [configToSet setValue:entries forKey:@"entries"];
  [_configContent updateConfigContentWithResponse:configToSet
                                     forNamespace:FIRNamespaceGoogleMobilePlatform];

  NSDictionary *fetchedConfig = _configContent.fetchedConfig;
  XCTAssertNotNil(fetchedConfig[FIRNamespaceGoogleMobilePlatform][@"key1"]);
  XCTAssertEqualObjects([fetchedConfig[FIRNamespaceGoogleMobilePlatform][@"key1"] stringValue],
                        @"value1");
  XCTAssertNotNil(fetchedConfig[FIRNamespaceGoogleMobilePlatform][@"key2"]);
  XCTAssertEqualObjects([fetchedConfig[FIRNamespaceGoogleMobilePlatform][@"key2"] stringValue],
                        @"value2");
}

/// Verify that fetchedConfig is overwritten for a new fetch call.
- (void)testUpdateConfigContentWithStatusUpdateWithDifferentKeys {
  NSMutableDictionary *configToSet =
      [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"UPDATE", @"state", nil];
  NSDictionary *entries = @{@"key1" : @"value1"};
  [configToSet setValue:entries forKey:@"entries"];
  [_configContent updateConfigContentWithResponse:configToSet
                                     forNamespace:FIRNamespaceGoogleMobilePlatform];
  configToSet = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"UPDATE", @"state", nil];
  entries = @{@"key2" : @"value2", @"key3" : @"value3"};
  [configToSet setValue:entries forKey:@"entries"];
  [_configContent updateConfigContentWithResponse:configToSet
                                     forNamespace:FIRNamespaceGoogleMobilePlatform];

  NSDictionary *fetchedConfig = _configContent.fetchedConfig;
  XCTAssertNil(fetchedConfig[FIRNamespaceGoogleMobilePlatform][@"key1"]);
  XCTAssertNotNil(fetchedConfig[FIRNamespaceGoogleMobilePlatform][@"key2"]);
  XCTAssertEqualObjects([fetchedConfig[FIRNamespaceGoogleMobilePlatform][@"key2"] stringValue],
                        @"value2");
  XCTAssertNotNil(fetchedConfig[FIRNamespaceGoogleMobilePlatform][@"key3"]);
  XCTAssertEqualObjects([fetchedConfig[FIRNamespaceGoogleMobilePlatform][@"key3"] stringValue],
                        @"value3");
}

/// Verify fetchedConfig is available across different namespaces.
- (void)testUpdateConfigContentWithStatusUpdateWithDifferentNamespaces {
  NSMutableDictionary *configToSet =
      [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"UPDATE", @"state", nil];
  NSMutableDictionary *configToSet2 =
      [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"UPDATE", @"state", nil];
  NSDictionary *entries = @{@"key1" : @"value1"};
  NSDictionary *entries2 = @{@"key2" : @"value2"};
  [configToSet setValue:entries forKey:@"entries"];
  [configToSet2 setValue:entries2 forKey:@"entries"];
  [_configContent updateConfigContentWithResponse:configToSet forNamespace:@"namespace_1"];
  [_configContent updateConfigContentWithResponse:configToSet2 forNamespace:@"namespace_2"];
  [_configContent updateConfigContentWithResponse:configToSet forNamespace:@"namespace_3"];
  [_configContent updateConfigContentWithResponse:configToSet2 forNamespace:@"namespace_4"];

  NSDictionary *fetchedConfig = _configContent.fetchedConfig;

  XCTAssertNotNil(fetchedConfig[@"namespace_1"][@"key1"]);
  XCTAssertEqualObjects([fetchedConfig[@"namespace_1"][@"key1"] stringValue], @"value1");
  XCTAssertNotNil(fetchedConfig[@"namespace_2"][@"key2"]);
  XCTAssertEqualObjects([fetchedConfig[@"namespace_2"][@"key2"] stringValue], @"value2");
  XCTAssertNotNil(fetchedConfig[@"namespace_3"][@"key1"]);
  XCTAssertEqualObjects([fetchedConfig[@"namespace_3"][@"key1"] stringValue], @"value1");
  XCTAssertNotNil(fetchedConfig[@"namespace_4"][@"key2"]);
  XCTAssertEqualObjects([fetchedConfig[@"namespace_4"][@"key2"] stringValue], @"value2");
}

- (void)skip_testUpdateConfigContentWithStatusNoChange {
  // TODO: Add test case once new eTag based logic is implemented.
}

- (void)skip_testUpdateConfigContentWithRemoveNamespaceStatus {
  // TODO: Add test case once new eTag based logic is implemented.
}

- (void)skip_testUpdateConfigContentWithEmptyConfig {
  // TODO: Add test case once new eTag based logic is implemented.
}

- (void)testCopyFromDictionaryDoesNotUpdateFetchedConfig {
  NSMutableDictionary *configToSet =
      [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"UPDATE", @"state", nil];
  NSDictionary *entries = @{@"key1" : @"value1", @"key2" : @"value2"};
  [configToSet setValue:entries forKey:@"entries"];
  [_configContent updateConfigContentWithResponse:configToSet forNamespace:@"dummy_namespace"];
  NSDictionary *namespaceToConfig = @{
    @"dummy_namespace" : @{
      @"new_key" : @"new_value",

    }
  };
  [_configContent copyFromDictionary:namespaceToConfig
                            toSource:RCNDBSourceFetched
                        forNamespace:@"dummy_namespace"];
  XCTAssertEqual(((NSDictionary *)_configContent.fetchedConfig[@"dummy_namespace"]).count, 2);
  XCTAssertEqual(_configContent.activeConfig.count, 0);
  XCTAssertEqual(_configContent.defaultConfig.count, 0);
}

- (void)testCopyFromDictionaryUpdatesDefaultConfig {
  NSDictionary *embeddedDictionary = @{@"default_embedded_key" : @"default_embedded_Value"};
  NSData *dataValue = [NSJSONSerialization dataWithJSONObject:embeddedDictionary
                                                      options:NSJSONWritingPrettyPrinted
                                                        error:nil];
  NSDate *now = [NSDate date];
  NSError *error;
  NSData *JSONData = [NSJSONSerialization dataWithJSONObject:@{@"key1" : @"value1"}
                                                     options:0
                                                       error:&error];
  NSString *JSONString = [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
  NSDictionary *namespaceToConfig = @{
    @"default_namespace" : @{
      @"new_string_key" : @"new_string_value",
      @"new_number_key" : @1234,
      @"new_data_key" : dataValue,
      @"new_date_key" : now,
      @"new_json_key" : JSONString
    }
  };
  [_configContent copyFromDictionary:namespaceToConfig
                            toSource:RCNDBSourceDefault
                        forNamespace:@"default_namespace"];
  NSDictionary *defaultConfig = _configContent.defaultConfig;
  XCTAssertEqual(_configContent.fetchedConfig.count, 0);
  XCTAssertEqual(_configContent.activeConfig.count, 0);
  XCTAssertNotNil(defaultConfig[@"default_namespace"]);
  XCTAssertEqual(((NSDictionary *)defaultConfig[@"default_namespace"]).count, 5);
  XCTAssertEqualObjects(@"new_string_value",
                        [defaultConfig[@"default_namespace"][@"new_string_key"] stringValue]);
  XCTAssertEqualObjects(
      @1234, [((FIRRemoteConfigValue *)defaultConfig[@"default_namespace"][@"new_number_key"])
                 numberValue]);
  NSDictionary<NSString *, NSString *> *sampleJSON = @{@"key1" : @"value1"};
  id configJSON = [(defaultConfig[@"default_namespace"][@"new_json_key"]) JSONValue];
  XCTAssertTrue([configJSON isKindOfClass:[NSDictionary class]]);
  XCTAssertTrue([sampleJSON isKindOfClass:[NSDictionary class]]);
  XCTAssertEqualObjects(sampleJSON, (NSDictionary *)configJSON);
  XCTAssertEqualObjects(dataValue,
                        [defaultConfig[@"default_namespace"][@"new_data_key"] dataValue]);
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
  NSString *strValueForDate = [dateFormatter stringFromDate:now];
  XCTAssertEqualObjects(strValueForDate,
                        [defaultConfig[@"default_namespace"][@"new_date_key"] stringValue]);
}

- (void)testCopyFromDictionaryUpdatesActiveConfig {
  // Active config values must be RCNConfigValue format
  NSDictionary *embeddedDictionary = @{@"active_embedded_key" : @"active_embedded_Value"};
  NSData *dataValue = [NSJSONSerialization dataWithJSONObject:embeddedDictionary
                                                      options:NSJSONWritingPrettyPrinted
                                                        error:nil];

  NSDictionary *namespaceToConfig = @{
    @"dummy_namespace" : @{
      @"new_key" : [[FIRRemoteConfigValue alloc] initWithData:dataValue source:-1],
    }
  };
  [_configContent copyFromDictionary:namespaceToConfig
                            toSource:RCNDBSourceActive
                        forNamespace:@"dummy_namespace"];
  XCTAssertEqual(((NSDictionary *)_configContent.activeConfig[@"dummy_namespace"]).count, 1);
  XCTAssertEqual(_configContent.fetchedConfig.count, 0);
  XCTAssertEqual(_configContent.defaultConfig.count, 0);
  XCTAssertEqualObjects(dataValue,
                        [_configContent.activeConfig[@"dummy_namespace"][@"new_key"] dataValue]);
}

- (void)testCheckAndWaitForInitialDatabaseLoad {
  RCNConfigDBManagerMock *mockDBManager = [[RCNConfigDBManagerMock alloc] init];
  RCNConfigContent *configContent = [[RCNConfigContent alloc] initWithDBManager:mockDBManager];

  // Check that no one of first three calls of `-checkAndWaitForInitialDatabaseLoad` do not produce
  // timeout error <begin>
  XCTestExpectation *expectation1 =
      [self expectationWithDescription:
                @"1st `checkAndWaitForInitialDatabaseLoad` return without timeout"];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    XCTAssertTrue([configContent checkAndWaitForInitialDatabaseLoad]);
    [expectation1 fulfill];
  });
  XCTestExpectation *expectation2 =
      [self expectationWithDescription:
                @"2nd `checkAndWaitForInitialDatabaseLoad` return without timeout"];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    XCTAssertTrue([configContent checkAndWaitForInitialDatabaseLoad]);
    [expectation2 fulfill];
  });

  XCTAssertTrue([configContent checkAndWaitForInitialDatabaseLoad]);
  // Check that both `-load...` methods already completed after 1st wait.
  // This make us sure that both `-loadMainWithBundleIdentifier` and
  // `-loadPersonalizationWithCompletionHandler` methods synched with
  // `-checkAndWaitForInitialDatabaseLoad`.
  XCTAssertTrue(mockDBManager.isLoadMainCompleted);
  XCTAssertTrue(mockDBManager.isLoadPersonalizationCompleted);

  // Check that no one of first three calls of `-checkAndWaitForInitialDatabaseLoad` do not produce
  // timeout error <end>.
  // This make us sure that there no threads "stucked" on `-checkAndWaitForInitialDatabaseLoad`.
  [self waitForExpectationsWithTimeout:0.5 * kDatabaseLoadTimeoutSecs handler:nil];
}

@end
