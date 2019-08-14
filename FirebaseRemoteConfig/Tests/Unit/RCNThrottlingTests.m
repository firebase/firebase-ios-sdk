#import <XCTest/XCTest.h>

#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigContent.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigDBManager.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigExperiment.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigFetch.h"
#import "googlemac/iPhone/Config/RemoteConfig/Source/RCNConfigSettings.h"
#import "googlemac/iPhone/Config/RemoteConfig/Tests/UnitTestsNew/RCNTestUtilities.h"

#import "third_party/firebase/ios/Releases/FirebaseCore/Library/FIRApp.h"
#import "third_party/firebase/ios/Releases/FirebaseCore/Library/FIRConfiguration.h"
#import "third_party/objective_c/ocmock/v3/Source/OCMock/OCMock.h"

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
  _settings = [[RCNConfigSettings alloc] initWithDatabaseManager:DBManager
                                                       namespace:FIRNamespaceGoogleMobilePlatform
                                                             app:[FIRApp defaultApp]];
  _experimentMock = OCMClassMock([RCNConfigExperiment class]);
  dispatch_queue_t _queue = dispatch_queue_create(
      "com.google.GoogleConfigService.FIRRemoteConfigTest", DISPATCH_QUEUE_SERIAL);

  _configFetch = [[RCNConfigFetch alloc] initWithContent:_configContentMock
                                               DBManager:DBManager
                                                settings:_settings
                                              experiment:_experimentMock
                                                   queue:_queue
                                               namespace:FIRNamespaceGoogleMobilePlatform
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
  // TODO(mandard): Investigate using a smaller timeout. b/122674668
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
