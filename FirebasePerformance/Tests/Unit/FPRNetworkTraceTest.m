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
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace+Private.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"

#import "FirebasePerformance/Tests/Unit/Configurations/FPRFakeRemoteConfig.h"
#import "FirebasePerformance/Tests/Unit/FPRTestCase.h"
#import "FirebasePerformance/Tests/Unit/FPRTestUtils.h"

#import <OCMock/OCMock.h>

@interface FPRNetworkTraceTest : FPRTestCase

@property(nonatomic) NSURLRequest *testURLRequest;

@end

@implementation FPRNetworkTraceTest

- (void)setUp {
  [super setUp];
  NSURL *URL = [NSURL URLWithString:@"https://abc.com"];
  _testURLRequest = [NSURLRequest requestWithURL:URL];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:YES];
}

- (void)tearDown {
  [super tearDown];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:NO];
}

- (void)testInit {
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest];
  XCTAssertNotNil(trace);
}

/**
 * Validates that the object creation fails for invalid URLs.
 */
- (void)testInitWithNonHttpURL {
  NSURL *URL = [NSURL URLWithString:@"ftp://abc.com"];
  NSURLRequest *sampleURLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:sampleURLRequest];
  XCTAssertNil(trace);
}

/**
 * Validates that the object creation fails for malformed URLs.
 */
- (void)testMalformedURL {
  NSURL *URL = [NSURL URLWithString:@"htp://abc.com"];
  NSURLRequest *sampleURLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:sampleURLRequest];
  XCTAssertNil(trace);
}

/**
 * Validates that the object creation fails for a non URL.
 */
- (void)testNonURL {
  NSURL *URL = [NSURL URLWithString:@"Iamtheherooftheuniverse"];
  NSURLRequest *sampleURLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:sampleURLRequest];
  XCTAssertNil(trace);
}

/**
 * Validates that the object creation fails for nil URLs.
 */
- (void)testNilURL {
  NSString *URLString = nil;
  NSURL *URL = [NSURL URLWithString:URLString];
  NSURLRequest *sampleURLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:sampleURLRequest];
  XCTAssertNil(trace);
}

/**
 * Validates that the object creation fails for empty URLs.
 */
- (void)testEmptyURL {
  NSURL *URL = [NSURL URLWithString:@""];
  NSURLRequest *sampleURLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:sampleURLRequest];
  XCTAssertNil(trace);
}

#pragma mark - Network Trace creation tests.

/** Validates if trace creation fails when SDK flag is disabled in remote config. */
- (void)testTraceCreationWhenSDKFlagDisabled {
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
  configFlags.appStartConfigFetchDelayInSeconds = 0.0;
  [configFlags update];

  XCTAssertNil([[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest]);
}

/** Validates if trace creation succeeds when SDK flag is enabled in remote config. */
- (void)testTraceCreationWhenSDKFlagEnabled {
  FPRConfigurations *configurations = [FPRConfigurations sharedInstance];
  FPRFakeRemoteConfig *remoteConfig = [[FPRFakeRemoteConfig alloc] init];

  FPRRemoteConfigFlags *configFlags =
      [[FPRRemoteConfigFlags alloc] initWithRemoteConfig:(FIRRemoteConfig *)remoteConfig];
  configurations.remoteConfigFlags = configFlags;

  NSUserDefaults *userDefaults = [[NSUserDefaults alloc] init];
  configFlags.userDefaults = userDefaults;

  NSString *configKey = [NSString stringWithFormat:@"%@.%@", kFPRConfigPrefix, @"fpr_enabled"];
  [userDefaults setObject:@(TRUE) forKey:configKey];

  XCTAssertNotNil([[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest]);
}

/** Validates if trace creation fails when SDK flag is enabled in remote config, but data collection
 * disabled. */
- (void)testTraceCreationWhenSDKFlagEnabledWithDataCollectionDisabled {
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

  XCTAssertNil([[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest]);
}

#pragma mark - Other Network Trace related tests.

/**
 * Validates that the object creation succeeds for long URLs and returns a valid trimmed URL.
 */
- (void)testInitWithVeryLongURL {
  NSString *domainString = @"https://thelongesturlusedtotestifitisgettingdropped.com";
  NSString *appendString = @"/thelongesturlusedtotestifitisgettingdroppedpath";
  NSString *URLString = domainString;
  NSInteger numberOfAppends = 0;

  // Create a long URL which exceed the limit.
  while (URLString.length < kFPRMaxURLLength) {
    URLString = [URLString stringByAppendingString:appendString];
    ++numberOfAppends;
  }

  URLString = [URLString stringByAppendingString:@"?param=value"];
  NSURLRequest *sampleURLRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:URLString]];
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:sampleURLRequest];
  XCTAssertNotNil(trace);

  // Expected lenght of the URL should be the domainLength, number of times path was appended which
  // does not make the length go beyond the max limit.
  NSInteger expectedLength = domainString.length + (numberOfAppends - 1) * appendString.length;
  XCTAssertEqual(trace.trimmedURLString.length, expectedLength);
}

/**
 * Validates the process of checkpointing and the time that is stored for a checkpoint.
 */
- (void)testCheckpointStates {
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  NSDictionary<NSString *, NSNumber *> *states = [trace checkpointStates];
  XCTAssertEqual(states.count, 1);
  NSString *key = [@(FPRNetworkTraceCheckpointStateInitiated) stringValue];
  NSNumber *value = [states objectForKey:key];
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

  // Validate if the event had occurred less than a millisecond ago.
  XCTAssertLessThan(now - [value doubleValue], .001);
}

/**
 * Validates if checkpointing of the same state is not honored.
 */
- (void)testCheckpointingAgain {
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest];
  [trace start];

  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  NSTimeInterval firstCheckpointTime = [[NSDate date] timeIntervalSince1970];
  NSString *key = [@(FPRNetworkTraceCheckpointStateInitiated) stringValue];
  NSDictionary<NSString *, NSNumber *> *statesAfterFirstCheckpoint = [trace checkpointStates];
  NSNumber *firstValue = [statesAfterFirstCheckpoint objectForKey:key];
  NSTimeInterval firstInitiatedTime = [firstValue doubleValue];

  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  NSTimeInterval secondCheckpointTime = [[NSDate date] timeIntervalSince1970];
  NSDictionary<NSString *, NSNumber *> *statesAfterSecondCheckpoint = [trace checkpointStates];
  NSNumber *secondValue = [statesAfterSecondCheckpoint objectForKey:key];
  NSTimeInterval secondInitiatedTime = [secondValue doubleValue];

  NSDictionary<NSString *, NSNumber *> *states = [trace checkpointStates];
  XCTAssertEqual(states.count, 1);

  // Validate if the first checkpoint occured before the second checkpoint time.
  XCTAssertLessThan(firstCheckpointTime, secondCheckpointTime);
  // Validate if the time has not changed even after rec checkpointing.
  XCTAssertEqual(firstInitiatedTime, secondInitiatedTime);
}

- (void)testCheckpointStatesBeforeStarting {
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  NSDictionary<NSString *, NSNumber *> *states = [trace checkpointStates];
  XCTAssertEqual(states.count, 0);
}

/**
 * Validates a successfully completed request for its checkpoints and data fetched out of the
 * response.
 */
- (void)testDidCompleteRequestWithValidResponse {
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];

  NSDictionary<NSString *, NSString *> *headerFields = @{@"Content-Type" : @"text/json"};
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.testURLRequest.URL
                                                            statusCode:200
                                                           HTTPVersion:@"HTTP/1.1"
                                                          headerFields:headerFields];

  NSString *string = @"Successful response";
  NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
  [trace didReceiveData:data];
  [trace didCompleteRequestWithResponse:response error:nil];

  NSDictionary<NSString *, NSNumber *> *states = [trace checkpointStates];
  XCTAssertEqual(states.count, 3);
  XCTAssertEqual(trace.responseCode, 200);
  XCTAssertEqual(trace.responseSize, string.length);
  XCTAssertEqualObjects(trace.responseContentType, @"text/json");
  NSString *key = [@(FPRNetworkTraceCheckpointStateResponseCompleted) stringValue];
  NSNumber *value = [states objectForKey:key];
  XCTAssertNotNil(value);
}

/**
 * Validates a failed network request for its checkpoints and data fetched out of the response.
 */
- (void)testDidCompleteRequestWithErrorResponse {
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];

  NSDictionary<NSString *, NSString *> *headerFields = @{@"Content-Type" : @"text/json"};
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.testURLRequest.URL
                                                            statusCode:404
                                                           HTTPVersion:@"HTTP/1.1"
                                                          headerFields:headerFields];
  NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:-200 userInfo:nil];

  [trace didReceiveData:[NSData data]];
  [trace didCompleteRequestWithResponse:response error:error];

  NSDictionary<NSString *, NSNumber *> *states = [trace checkpointStates];
  XCTAssertEqual(states.count, 3);
  XCTAssertEqual(trace.responseCode, 404);
  XCTAssertEqual(trace.responseSize, 0);
  XCTAssertEqualObjects(trace.responseContentType, @"text/json");
  NSString *key = [@(FPRNetworkTraceCheckpointStateResponseCompleted) stringValue];
  NSNumber *value = [states objectForKey:key];
  XCTAssertNotNil(value);
}

/**
 * Validates that the uploaded file size correctly reflect in the NetworkTrace.
 */
- (void)testDidUploadFile {
  NSBundle *bundle = [FPRTestUtils getBundle];
  NSURL *fileURL = [bundle URLForResource:@"smallDownloadFile" withExtension:@""];

  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest];

  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];
  [trace didUploadFileWithURL:fileURL];
  XCTAssertEqual(trace.requestSize, 26);
  XCTAssertEqual(trace.responseSize, 0);

  [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
}

- (void)testCompletedRequest {
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];
  [trace didCompleteRequestWithResponse:nil error:nil];

  NSDictionary<NSString *, NSNumber *> *states = [trace checkpointStates];
  XCTAssertEqual(states.count, 3);
  NSString *key = [@(FPRNetworkTraceCheckpointStateResponseCompleted) stringValue];
  NSNumber *value = [states objectForKey:key];
  XCTAssertNotNil(value);
}

/**
 * Validates checkpointing for edge state - Checkpointing after a network request is completed.
 */
- (void)testCheckpointAfterCompletedRequest {
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [trace didCompleteRequestWithResponse:nil error:nil];

  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];

  NSDictionary<NSString *, NSNumber *> *states = [trace checkpointStates];
  XCTAssertEqual(states.count, 2);
}

- (void)testTimeIntervalBetweenValidStates {
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  sleep(2);
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];

  NSTimeInterval timeDifference =
      [trace timeIntervalBetweenCheckpointState:FPRNetworkTraceCheckpointStateInitiated
                                       andState:FPRNetworkTraceCheckpointStateResponseReceived];
  XCTAssertLessThan(fabs(timeDifference - 2), 0.2);
}

- (void)testURLTrimmingWithQuery {
  NSURL *URL = [NSURL URLWithString:@"https://accounts.google.com/ServiceLogin?service=mail"];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *networkTrace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
  XCTAssertEqualObjects(networkTrace.trimmedURLString, @"https://accounts.google.com/ServiceLogin");
}

- (void)testURLTrimmingWithUserNamePasswordAndPort {
  NSURL *URL = [NSURL URLWithString:@"https://a:b@ab.com:1000/ServiceLogin?service=mail"];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *networkTrace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
  XCTAssertEqualObjects(networkTrace.trimmedURLString, @"https://ab.com:1000/ServiceLogin");
}

- (void)testURLTrimmingWithDeepPath {
  NSURL *URL = [NSURL URLWithString:@"https://a:b@ab.com:1000/x/y/z?service=1&really=2"];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *networkTrace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
  XCTAssertEqualObjects(networkTrace.trimmedURLString, @"https://ab.com:1000/x/y/z");
}

- (void)testURLTrimmingWithFragments {
  NSURL *URL = [NSURL URLWithString:@"https://a:b@ab.com:1000/x#really?service=1&really=2"];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *networkTrace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
  XCTAssertEqualObjects(networkTrace.trimmedURLString, @"https://ab.com:1000/x");
}

/** Validate if the trace creation fails when the domain name is beyond max length. */
- (void)testURLMaxLength {
  NSString *longString = [@"abd" stringByPaddingToLength:kFPRMaxURLLength + 1
                                              withString:@"-"
                                         startingAtIndex:0];
  NSString *urlString = [NSString stringWithFormat:@"https://%@.com", longString];
  NSURL *URL = [NSURL URLWithString:urlString];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  XCTAssertNil([[FPRNetworkTrace alloc] initWithURLRequest:URLRequest]);
}

/** Validate if the trimmed URL drops only few sub paths from the URL when the length goes beyond
 *  the limit.
 */
- (void)testURLMaxLengthWithQuerypath {
  NSString *longString = [@"abd" stringByPaddingToLength:kFPRMaxURLLength - 20
                                              withString:@"-"
                                         startingAtIndex:0];
  NSString *urlString = [NSString stringWithFormat:@"https://%@.com/abcd/efgh/ijkl", longString];
  NSURL *URL = [NSURL URLWithString:urlString];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *networkTrace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
  XCTAssertNotNil(networkTrace);
  XCTAssertEqual(networkTrace.trimmedURLString.length, 1997);
}

/** Validate if the trimmed URL is equal to the URL provided when the length is less than the limit.
 */
- (void)testTrimmedURLForShortLengthURLs {
  NSString *urlString = @"https://helloworld.com/abcd/efgh/ijkl";
  NSURL *URL = [NSURL URLWithString:urlString];
  NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL];
  FPRNetworkTrace *networkTrace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
  XCTAssertNotNil(networkTrace);
  XCTAssertEqual(networkTrace.URLRequest.URL.absoluteString, urlString);
}

/** Validates that every trace contains a session Id. */
- (void)testSessionId {
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];

  NSDictionary<NSString *, NSString *> *headerFields = @{@"Content-Type" : @"text/json"};
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.testURLRequest.URL
                                                            statusCode:200
                                                           HTTPVersion:@"HTTP/1.1"
                                                          headerFields:headerFields];

  NSString *string = @"Successful response";
  NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];

  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];

  [trace didReceiveData:data];
  [trace didCompleteRequestWithResponse:response error:nil];
  XCTAssertNotNil(trace.sessions);
  XCTAssertTrue(trace.sessions.count > 0);
}

/** Validates if a trace contains multiple session Ids on changing app state. */
- (void)testMultipleSessionIds {
  FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:self.testURLRequest];
  [trace start];
  [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];

  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter postNotificationName:UIWindowDidBecomeVisibleNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationWillEnterForegroundNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationWillEnterForegroundNotification
                               object:[UIApplication sharedApplication]];

  NSDictionary<NSString *, NSString *> *headerFields = @{@"Content-Type" : @"text/json"};
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.testURLRequest.URL
                                                            statusCode:200
                                                           HTTPVersion:@"HTTP/1.1"
                                                          headerFields:headerFields];

  NSString *string = @"Successful response";
  NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
  [trace didReceiveData:data];
  [trace didCompleteRequestWithResponse:response error:nil];

  XCTestExpectation *expectation = [self expectationWithDescription:@"Dummy expectation"];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [expectation fulfill];
                   XCTAssertNotNil(trace.sessions);
                   XCTAssertTrue(trace.sessions.count >= 2);
                 });
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

@end
