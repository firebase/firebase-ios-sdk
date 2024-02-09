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
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigContent.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigExperiment.h"
#import "FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
@import FirebaseRemoteConfigInterop;

@interface RCNThrottlingTests : XCTestCase {
  RCNConfigContent *_configContentMock;
  RCNConfigSettings *_settings;
  RCNConfigExperiment *_experimentMock;
  RCNConfigFetch *_configFetch;
  NSString *_DBPath;
}

@end

@implementation RCNThrottlingTests

- (void)setUp {
  [super setUp];
  // Put setup code here. This method is called before the invocation of each test method in the
  // class.
  if (![FIRApp defaultApp]) {
    [FIRApp configure];
  }
  [[FIRConfiguration sharedInstance] setLoggerLevel:FIRLoggerLevelMax];
  // Get a test database.
  _DBPath = [RCNTestUtilities remoteConfigPathForTestDatabase];
  id classMock = OCMClassMock([RCNConfigDBManager class]);
  OCMStub([classMock remoteConfigPathForDatabase]).andReturn(_DBPath);
  RCNConfigDBManager *DBManager = [[RCNConfigDBManager alloc] init];

  _configContentMock = OCMClassMock([RCNConfigContent class]);
  _settings = [[RCNConfigSettings alloc]
      initWithDatabaseManager:DBManager
                    namespace:FIRRemoteConfigConstants.FIRNamespaceGoogleMobilePlatform
                          app:[FIRApp defaultApp]];
  _experimentMock = OCMClassMock([RCNConfigExperiment class]);
  dispatch_queue_t _queue = dispatch_queue_create(
      "com.google.GoogleConfigService.FIRRemoteConfigTest", DISPATCH_QUEUE_SERIAL);

  _configFetch = [[RCNConfigFetch alloc]
      initWithContent:_configContentMock
            DBManager:DBManager
             settings:_settings
           experiment:_experimentMock
                queue:_queue
            namespace:FIRRemoteConfigConstants.FIRNamespaceGoogleMobilePlatform
                  app:[FIRApp defaultApp]];
}

- (void)mockFetchResponseWithStatusCode:(NSInteger)statusCode {
  // Mock successful network fetches with an empty config response.
  RCNConfigFetcherTestBlock testBlock = ^(RCNConfigFetcherCompletion completion) {
    NSURL *url = [[NSURL alloc] initWithString:@"https://google.com"];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url
                                                              statusCode:statusCode
                                                             HTTPVersion:nil
                                                            headerFields:@{@"etag" : @"etag1"}];
    NSData *data =
        [NSJSONSerialization dataWithJSONObject:@{@"key1" : @"val1", @"state" : @"UPDATE"}
                                        options:0
                                          error:nil];
    completion(data, response, nil);
  };
  [RCNConfigFetch setGlobalTestBlock:testBlock];
}

/// Regular case of calling fetch should succeed.
- (void)testRegularFetchDoesNotGetThrottled {
  [self mockFetchResponseWithStatusCode:200];
  XCTestExpectation *expectation = [self expectationWithDescription:@"throttlingExpectation"];
  [_configFetch fetchAllConfigsWithExpirationDuration:0
                                    completionHandler:^(FIRRemoteConfigFetchStatus status,
                                                        NSError *_Nullable error) {
                                      XCTAssertNil(error);
                                      XCTAssertEqual(FIRRemoteConfigFetchStatusSuccess, status);
                                      [expectation fulfill];
                                    }];
  // TODO(dmandar): Investigate using a smaller timeout. b/122674668
  [self waitForExpectationsWithTimeout:4.0 handler:nil];
}

- (void)testServerThrottleHTTP429ReturnsAThrottledError {
  [self mockFetchResponseWithStatusCode:429];
  XCTestExpectation *expectation = [self expectationWithDescription:@"throttlingExpectation"];

  [_configFetch
      fetchAllConfigsWithExpirationDuration:0
                          completionHandler:^(FIRRemoteConfigFetchStatus status,
                                              NSError *_Nullable error) {
                            XCTAssertNotNil(error);
                            NSNumber *endTime = error.userInfo[@"error_throttled_end_time_seconds"];
                            XCTAssertGreaterThanOrEqual([endTime doubleValue],
                                                        [[NSDate date] timeIntervalSinceNow]);
                            XCTAssertEqual(FIRRemoteConfigFetchStatusThrottled, status);
                            [expectation fulfill];
                          }];
  [self waitForExpectationsWithTimeout:4.0 handler:nil];
}

- (void)testServerInternalError500ReturnsAThrottledError {
  [self mockFetchResponseWithStatusCode:500];
  XCTestExpectation *expectation = [self expectationWithDescription:@"throttlingExpectation"];

  [_configFetch
      fetchAllConfigsWithExpirationDuration:0
                          completionHandler:^(FIRRemoteConfigFetchStatus status,
                                              NSError *_Nullable error) {
                            XCTAssertNotNil(error);
                            NSNumber *endTime = error.userInfo[@"error_throttled_end_time_seconds"];
                            XCTAssertGreaterThanOrEqual([endTime doubleValue],
                                                        [[NSDate date] timeIntervalSinceNow]);
                            XCTAssertEqual(FIRRemoteConfigFetchStatusThrottled, status);
                            [expectation fulfill];
                          }];
  [self waitForExpectationsWithTimeout:4.0 handler:nil];
}

- (void)testServerUnavailableError503ReturnsAThrottledError {
  [self mockFetchResponseWithStatusCode:503];
  XCTestExpectation *expectation = [self expectationWithDescription:@"throttlingExpectation"];

  [_configFetch
      fetchAllConfigsWithExpirationDuration:0
                          completionHandler:^(FIRRemoteConfigFetchStatus status,
                                              NSError *_Nullable error) {
                            XCTAssertNotNil(error);
                            NSNumber *endTime = error.userInfo[@"error_throttled_end_time_seconds"];
                            XCTAssertGreaterThanOrEqual([endTime doubleValue],
                                                        [[NSDate date] timeIntervalSinceNow]);
                            XCTAssertEqual(FIRRemoteConfigFetchStatusThrottled, status);
                            [expectation fulfill];
                          }];
  [self waitForExpectationsWithTimeout:4.0 handler:nil];
}

- (void)testThrottleReturnsAThrottledErrorAndThrottlesSubsequentRequests {
  [self mockFetchResponseWithStatusCode:429];
  XCTestExpectation *expectation = [self expectationWithDescription:@"throttlingExpectation"];
  XCTestExpectation *expectation2 = [self expectationWithDescription:@"throttlingExpectation2"];

  [_configFetch
      fetchAllConfigsWithExpirationDuration:0
                          completionHandler:^(FIRRemoteConfigFetchStatus status,
                                              NSError *_Nullable error) {
                            XCTAssertNotNil(error);
                            NSNumber *endTime = error.userInfo[@"error_throttled_end_time_seconds"];
                            XCTAssertGreaterThanOrEqual([endTime doubleValue],
                                                        [[NSDate date] timeIntervalSinceNow]);
                            XCTAssertEqual(FIRRemoteConfigFetchStatusThrottled, status);
                            [expectation fulfill];

                            // follow-up request.
                            [_configFetch
                                fetchAllConfigsWithExpirationDuration:0
                                                    completionHandler:^(
                                                        FIRRemoteConfigFetchStatus status,
                                                        NSError *_Nullable error) {
                                                      XCTAssertNotNil(error);
                                                      NSNumber *endTime =
                                                          error.userInfo
                                                              [@"error_throttled_end_time_seconds"];
                                                      XCTAssertGreaterThanOrEqual(
                                                          [endTime doubleValue],
                                                          [[NSDate date] timeIntervalSinceNow]);
                                                      XCTAssertEqual(
                                                          FIRRemoteConfigFetchStatusThrottled,
                                                          status);
                                                      [expectation2 fulfill];
                                                    }];
                          }];

  [self waitForExpectationsWithTimeout:4.0 handler:nil];
}

@end
