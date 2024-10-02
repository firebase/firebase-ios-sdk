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

#import "FirebaseRemoteConfig/Sources/Private/RCNConfigFetch.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigContent.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigExperiment.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigValue_Internal.h"
#import "FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.h"
@import FirebaseRemoteConfigInterop;

static NSString *const RCNFakeSenderID = @"855865492447";
static NSString *const RCNFakeToken = @"ctToAh17Exk:"
                                      @"APA91bFpX1aucYk5ONWt3MxyVxTyDKV8PKjaY2X3DPCZOOTHIBNf3ybxV5"
                                      @"aMQ7G8zUTrduobNLEUoSvGsncthR27gDF_qqZELqp2eEi1BL8k_"
                                      @"4AkeP2dLBq4f8MvuJTOEv2P5ChTdByr";
static NSString *const RCNFakeDeviceID = @"4421690866479820589";
static NSString *const RCNFakeSecretToken = @"6377571288467228941";

@interface RCNConfigFetch (ForTest)
// Exposes fetching user property method in the category.
//- (void)fetchWithUserPropertiesCompletionHandler:(RCNAnalyticsUserPropertiesCompletion)block;
- (void)refreshInstanceIDTokenAndFetchCheckInInfoWithCompletionHandler:
    (FIRRemoteConfigFetchCompletion)completionHandler;
- (void)fetchCheckinInfoWithCompletionHandler:(FIRRemoteConfigFetchCompletion)completionHandler;
@end

@interface RCNConfigTest : XCTestCase {
  NSTimeInterval _expectationTimeout;
  RCNConfigSettings *_settings;
  RCNConfigFetchResponse *_response;
  RCNConfigContent *_configContent;
  RCNConfigExperiment *_experiment;
  RCNConfigFetch *_configFetch;
  dispatch_queue_t _queue;
  NSString *_namespaceGoogleMobilePlatform;
}
@end

@implementation RCNConfigTest
- (void)setUp {
  [super setUp];
  _expectationTimeout = 1.0;
  // Mock the singleton to an instance that is reset for each unit test
  _configContent = [[RCNConfigContent alloc] initWithDBManager:nil];
  _settings = [[RCNConfigSettings alloc] initWithDatabaseManager:nil];
  _experiment = [[RCNConfigExperiment alloc] initWithDBManager:nil];
  _queue = dispatch_queue_create("com.google.GoogleConfigService.FIRRemoteConfigTest",
                                 DISPATCH_QUEUE_CONCURRENT);
  RCNConfigFetch *fetcher = [[RCNConfigFetch alloc] initWithContent:_configContent
                                                           settings:_settings
                                                         experiment:_experiment
                                                              queue:_queue];
  _configFetch = OCMPartialMock(fetcher);
  _namespaceGoogleMobilePlatform = FIRRemoteConfigConstants.FIRNamespaceGoogleMobilePlatform;
  // Fake a response with a default namespace and a custom namespace.
  NSDictionary *namespaceToConfig = @{
    _namespaceGoogleMobilePlatform : @{@"key1" : @"value1", @"key2" : @"value2"},
    FIRNamespaceGooglePlayPlatform : @{@"playerID" : @"36", @"gameLevel" : @"87"},
  };
  _response =
      [RCNTestUtilities responseWithNamespaceToConfig:namespaceToConfig
                                          statusArray:@[
                                            @(RCNAppNamespaceConfigTable_NamespaceStatus_Update),
                                            @(RCNAppNamespaceConfigTable_NamespaceStatus_Update)
                                          ]];
  NSData *responseData = [NSData gtm_dataByDeflatingData:_response.data error:nil];

  // Mock successful network fetches with an empty config response.
  RCNConfigFetcherTestBlock testBlock = ^(RCNConfigFetcherCompletion completion) {
    completion(responseData, nil, nil);
  };
  [RCNConfigFetch setGlobalTestBlock:testBlock];

  // Mocks the user property fetch with a predefined dictionary.
  NSDictionary *userProperties = @{@"userProperty1" : @"100", @"userProperty2" : @"200"};
  OCMStub([_configFetch
      fetchWithUserPropertiesCompletionHandler:([OCMArg invokeBlockWithArgs:userProperties, nil])]);
}

- (void)tearDown {
  [RCNConfigFetch setGlobalTestBlock:nil];
  [super tearDown];
}

- (void)testInitMethod {
  RCNConfigFetch *fetcher = [[RCNConfigFetch alloc] init];
  XCTAssertNotNil(fetcher);
}

- (void)testFetchAllConfigsFailedWithoutCachedResult {
  XCTestExpectation *fetchFailedExpectation = [self
      expectationWithDescription:@"Test first config fetch failed without any cached result."];
  // Mock a failed network fetch.
  NSError *error = [NSError errorWithDomain:@"testDomain" code:1 userInfo:nil];
  RCNConfigFetcherTestBlock testBlock = ^(RCNConfigFetcherCompletion completion) {
    completion(nil, nil, error);
  };
  [RCNConfigFetch setGlobalTestBlock:testBlock];

  FIRRemoteConfigFetchCompletion fetchAllConfigsCompletion =
      ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
        XCTAssertNotNil(error);
        XCTAssertEqual(self->_configContent.fetchedConfig.count,
                       0);  // There's no cached result yet since this is the first fetch.
        XCTAssertEqual(status, FIRRemoteConfigFetchStatusFailure,
                       @"Fetch config failed, there is no cached config result yet. Status must "
                       @"equal to FIRRemoteConfigFetchStatusNotAvailable.");

        XCTAssertEqual(self->_settings.expirationInSeconds, 0,
                       @"expirationInSeconds is set successfully during fetch.");
        XCTAssertEqual(self->_settings.lastFetchTimeInterval, 0,
                       @"last fetch time interval should not be set.");
        XCTAssertEqual(self->_settings.lastApplyTimeInterval, 0,
                       @"last apply time interval should not be set.");

        [fetchFailedExpectation fulfill];
      };
  [_configFetch fetchAllConfigsWithExpirationDuration:0
                                    completionHandler:fetchAllConfigsCompletion];

  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testFetchAllConfigsSuccessfully {
  XCTestExpectation *fetchAllConfigsExpectation =
      [self expectationWithDescription:@"Test fetch all configs successfully."];

  FIRRemoteConfigFetchCompletion fetchAllConfigsCompletion =
      ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
        XCTAssertNil(error);
        NSDictionary *result = self->_configContent.fetchedConfig;
        XCTAssertNotNil(result);

        [self checkConfigResult:result
                  withNamespace:_namespaceGoogleMobilePlatform
                            key:@"key1"
                          value:@"value1"];
        [self checkConfigResult:result
                  withNamespace:_namespaceGoogleMobilePlatform
                            key:@"key2"
                          value:@"value2"];
        [self checkConfigResult:result
                  withNamespace:_namespaceGoogleMobilePlatform
                            key:@"playerID"
                          value:@"36"];
        [self checkConfigResult:result
                  withNamespace:_namespaceGoogleMobilePlatform
                            key:@"gameLevel"
                          value:@"87"];
        XCTAssertEqual(self->_settings.expirationInSeconds, 43200,
                       @"expirationInSeconds is set successfully during fetch.");
        XCTAssertGreaterThan(self->_settings.lastFetchTimeInterval, 0,
                             @"last fetch time interval should be set.");
        XCTAssertEqual(self->_settings.lastApplyTimeInterval, 0,
                       @"last apply time interval should not be set.");

        XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess,
                       @"Callback of first successful config "
                       @"fetch. Status must equal to FIRRemoteConfigFetchStatusSuccess.");
        [fetchAllConfigsExpectation fulfill];
      };

  [_configFetch fetchAllConfigsWithExpirationDuration:43200
                                    completionHandler:fetchAllConfigsCompletion];

  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testFetchConfigInCachedResults {
  XCTestExpectation *fetchConfigExpectation =
      [self expectationWithDescription:@"Test fetch config within expiration duration, meaning "
                                       @"use fresh cached result instead of fetching from server."];

  FIRRemoteConfigFetchCompletion firstFetchCompletion =
      ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
        XCTAssertNil(error);
        FIRRemoteConfigFetchCompletion secondFetchCompletion = ^void(
            FIRRemoteConfigFetchStatus status, NSError *error) {
          XCTAssertNil(error);
          NSDictionary *result = self->_configContent.fetchedConfig;
          XCTAssertNotNil(result);
          [self checkConfigResult:result
                    withNamespace:_namespaceGoogleMobilePlatform
                              key:@"key1"
                            value:@"value1"];
          [self checkConfigResult:result
                    withNamespace:_namespaceGoogleMobilePlatform
                              key:@"key2"
                            value:@"value2"];

          XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess,
                         "Config fetch's expiration duration is 43200 seconds, which means the"
                         "config cached data hasn't expired. Return cached result. Status must be "
                         "FIRRemoteConfigFetchStatusSuccess.");
          [fetchConfigExpectation fulfill];
        };
        [_configFetch fetchAllConfigsWithExpirationDuration:43200
                                          completionHandler:secondFetchCompletion];
      };
  [_configFetch fetchAllConfigsWithExpirationDuration:43200 completionHandler:firstFetchCompletion];

  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testFetchFailedWithCachedResult {
  XCTestExpectation *fetchFailedExpectation =
      [self expectationWithDescription:@"Test fetch failed from server, use cached result."];
  // Mock a failed network fetch.
  NSError *error = [NSError errorWithDomain:@"testDomain" code:1 userInfo:nil];
  RCNConfigFetcherTestBlock testBlock = ^(RCNConfigFetcherCompletion completion) {
    completion(nil, nil, error);
  };
  [RCNConfigFetch setGlobalTestBlock:testBlock];

  // Mock previous fetch succeed with cached data.
  [_settings updateMetadata:YES namespaceToDigest:nil];
  [_configContent updateConfigContentWithResponse:[_response copy]];

  FIRRemoteConfigFetchCompletion fetchAllConfigsCompletion =
      ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
        XCTAssertNotNil(error);
        NSDictionary *result = self->_configContent.fetchedConfig;
        XCTAssertNotNil(result);

        [self checkConfigResult:result
                  withNamespace:_namespaceGoogleMobilePlatform
                            key:@"key1"
                          value:@"value1"];
        [self checkConfigResult:result
                  withNamespace:_namespaceGoogleMobilePlatform
                            key:@"key2"
                          value:@"value2"];
        [self checkConfigResult:result
                  withNamespace:_namespaceGoogleMobilePlatform
                            key:@"playerID"
                          value:@"36"];
        [self checkConfigResult:result
                  withNamespace:_namespaceGoogleMobilePlatform
                            key:@"gameLevel"
                          value:@"87"];

        [fetchFailedExpectation fulfill];
      };
  // Expiration duration is set to 0, meaning always fetch from server because the cached result
  // expired in 0 seconds.
  [_configFetch fetchAllConfigsWithExpirationDuration:0
                                    completionHandler:fetchAllConfigsCompletion];

  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testFetchThrottledWithCachedResult {
  XCTestExpectation *fetchAllConfigsExpectation =
      [self expectationWithDescription:
                @"Test fetch being throttled after exceeding throttling limit, use cached result."];
  // Fake a new response with a different custom namespace.
  NSDictionary *namespaceToConfig = @{
    @"configns:MY_OWN_APP" :
        @{@"columnID" : @"28", @"columnName" : @"height", @"columnValue" : @"2"}
  };
  RCNConfigFetchResponse *newResponse = [RCNTestUtilities
      responseWithNamespaceToConfig:namespaceToConfig
                        statusArray:@[ @(RCNAppNamespaceConfigTable_NamespaceStatus_Update) ]];
  // Mock 5 fetches ahead.
  for (int i = 0; i < RCNThrottledSuccessFetchCountDefault; i++) {
    [_settings updateMetadata:YES namespaceToDigest:nil];
    [_configContent updateConfigContentWithResponse:[newResponse copy]];
  }

  FIRRemoteConfigFetchCompletion fetchAllConfigsCompletion =
      ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
        XCTAssertNotNil(error);
        NSDictionary *result = self->_configContent.fetchedConfig;
        XCTAssertNotNil(result);  // Cached result is not nil.
        [self checkConfigResult:result
                  withNamespace:@"configns:MY_OWN_APP"
                            key:@"columnID"
                          value:@"28"];
        [self checkConfigResult:result
                  withNamespace:@"configns:MY_OWN_APP"
                            key:@"columnName"
                          value:@"height"];
        [self checkConfigResult:result
                  withNamespace:@"configns:MY_OWN_APP"
                            key:@"columnValue"
                          value:@"2"];

        XCTAssertEqual(error.code, (int)FIRRemoteConfigErrorThrottled,
                       @"Default success throttling rate is 5. Mocked 5 successful fetches from "
                       @"server, this fetch will be throttled. Status must equal to "
                       @"FIRRemoteConfigFetchStatusFetchThrottled.");
        [fetchAllConfigsExpectation fulfill];
      };
  [_configFetch fetchAllConfigsWithExpirationDuration:-1
                                    completionHandler:fetchAllConfigsCompletion];
  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testFetchThrottledWithStaledCachedResult {
  XCTestExpectation *fetchAllConfigsExpectation =
      [self expectationWithDescription:@"Test fetch being throttled, use staled cache result."];
  // Mock 5 fetches ahead.
  for (int i = 0; i < RCNThrottledSuccessFetchCountDefault; i++) {
    [_settings updateMetadata:YES namespaceToDigest:nil];
    [_configContent updateConfigContentWithResponse:[_response copy]];
  }

  FIRRemoteConfigFetchCompletion fetchAllConfigsCompletion =
      ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
        XCTAssertNotNil(error);
        NSDictionary *result = self->_configContent.fetchedConfig;
        XCTAssertNotNil(result);
        [self checkConfigResult:result
                  withNamespace:_namespaceGoogleMobilePlatform
                            key:@"key1"
                          value:@"value1"];
        [self checkConfigResult:result
                  withNamespace:_namespaceGoogleMobilePlatform
                            key:@"key2"
                          value:@"value2"];
        [self checkConfigResult:result
                  withNamespace:_namespaceGoogleMobilePlatform
                            key:@"playerID"
                          value:@"36"];
        [self checkConfigResult:result
                  withNamespace:_namespaceGoogleMobilePlatform
                            key:@"gameLevel"
                          value:@"87"];
        XCTAssertEqual(
            error.code, FIRRemoteConfigErrorThrottled,
            @"Request fetching within throttling time interval, so this fetch will still be "
            @"throttled. "
            @"However, the App context (custom variables) has changed, meaning the return cached "
            @"result is staled. The status must equal to RCNConfigStatusFetchThrottledStale.");
        [fetchAllConfigsExpectation fulfill];
      };
  // Fetch with new custom variables.
  [_configFetch fetchAllConfigsWithExpirationDuration:0
                                    completionHandler:fetchAllConfigsCompletion];

  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

#pragma mark - helpers

- (void)checkConfigResult:(NSDictionary *)result
            withNamespace:(NSString *)namespace
                      key:(NSString *)key
                    value:(NSString *)value {
  if (result[namespace]) {
    FIRRemoteConfigValue *configValue = result[namespace][key];
    XCTAssertEqualObjects(configValue.stringValue, value,
                          @"Config result missing the key value pair.");
  } else {
    XCTAssertNotNil(result[namespace], @"Config result missing the namespace.");
  }
}

@end
