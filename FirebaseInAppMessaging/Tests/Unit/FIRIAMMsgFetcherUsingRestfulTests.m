/*
 * Copyright 2017 Google
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
#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMMessageDefinition.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMMsgFetcherUsingRestful.h"
#import "FirebaseInAppMessaging/Sources/Private/Runtime/FIRIAMFetchFlow.h"

static NSString *serverHost = @"myhost";
static NSString *projectNumber = @"My-project-number";
static NSString *appId = @"My-app-id";
static NSString *apiKey = @"Api-key";

@interface FIRIAMMsgFetcherUsingRestfulTests : XCTestCase
@property NSURLSession *mockedNSURLSession;
@property FIRIAMClientInfoFetcher *mockclientInfoFetcher;
@property FIRIAMMsgFetcherUsingRestful *fetcher;
@end

@implementation FIRIAMMsgFetcherUsingRestfulTests

- (void)setUp {
  [super setUp];
  // Put setup code here. This method is called before the invocation of each test method in the
  // class.
  self.mockedNSURLSession = OCMClassMock([NSURLSession class]);
  self.mockclientInfoFetcher = OCMClassMock([FIRIAMClientInfoFetcher class]);

  FIRIAMFetchResponseParser *parser =
      [[FIRIAMFetchResponseParser alloc] initWithTimeFetcher:[[FIRIAMTimerWithNSDate alloc] init]];

  self.fetcher =
      [[FIRIAMMsgFetcherUsingRestful alloc] initWithHost:serverHost
                                            HTTPProtocol:@"https"
                                                 project:projectNumber
                                             firebaseApp:appId
                                                  APIKey:apiKey
                                            fetchStorage:[[FIRIAMServerMsgFetchStorage alloc] init]
                                       instanceIDFetcher:_mockclientInfoFetcher
                                         usingURLSession:_mockedNSURLSession
                                          responseParser:parser];
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
  [super tearDown];
}

- (void)testRequestConstructionWithoutImpressionData {
  // This is an example of a functional test case.
  // Use XCTAssert and related functions to verify your tests produce the correct results.

  __block NSURLRequest *capturedNSURLRequest;
  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(NSURLRequest *request) {
        capturedNSURLRequest = request;
        return YES;
      }]
        completionHandler:[OCMArg any]  // second parameter is the callback which we don't care in
                                        // this unit testing
  ]);

  NSString *FIDValue = @"my FID";
  NSString *FISToken = @"my FIS token";
  OCMStub([self.mockclientInfoFetcher
      fetchFirebaseInstallationDataWithProjectNumber:[OCMArg any]
                                      withCompletion:([OCMArg
                                                         invokeBlockWithArgs:FIDValue, FISToken,
                                                                             [NSNull null], nil])]);

  NSString *osVersion = @"OS Version";
  OCMStub([self.mockclientInfoFetcher getOSVersion]).andReturn(osVersion);
  NSString *appVersion = @"App Version";
  OCMStub([self.mockclientInfoFetcher getAppVersion]).andReturn(appVersion);
  NSString *deviceLanguage = @"Language";
  OCMStub([self.mockclientInfoFetcher getDeviceLanguageCode]).andReturn(deviceLanguage);
  NSString *timezone = @"time zone";
  OCMStub([self.mockclientInfoFetcher getTimezone]).andReturn(timezone);

  [self.fetcher
      fetchMessagesWithImpressionList:@[]
                       withCompletion:^(NSArray<FIRIAMMessageDefinition *> *_Nullable messages,
                                        NSNumber *nextFetchWaitTime, NSInteger discardCount,
                                        NSError *_Nullable error){
                           // blank on purpose: it won't get triggered
                       }];

  // verify that the dataTaskWithRequest:completionHandler: is triggered for NSURLSession object
  OCMVerify([self.mockedNSURLSession dataTaskWithRequest:[OCMArg any]
                                       completionHandler:[OCMArg any]]);

  XCTAssertEqualObjects(@"POST", capturedNSURLRequest.HTTPMethod);

  NSDictionary<NSString *, NSString *> *requestHeaders = capturedNSURLRequest.allHTTPHeaderFields;

  // verifying some request header fields
  XCTAssertEqualObjects([NSBundle mainBundle].bundleIdentifier,
                        requestHeaders[@"X-Ios-Bundle-Identifier"]);

  XCTAssertEqualObjects(@"application/json", requestHeaders[@"Content-Type"]);
  XCTAssertEqualObjects(@"application/json", requestHeaders[@"Accept"]);

  // verify that the request contains the desired api key
  NSString *s = [NSString stringWithFormat:@"key=%@", apiKey];
  XCTAssertTrue([capturedNSURLRequest.URL.absoluteString containsString:s]);
  XCTAssertTrue([capturedNSURLRequest.URL.absoluteString containsString:projectNumber]);

  // verify that we the request body contains desired iid data
  NSError *errorJson = nil;
  NSDictionary *requestBodyDict =
      [NSJSONSerialization JSONObjectWithData:capturedNSURLRequest.HTTPBody
                                      options:kNilOptions
                                        error:&errorJson];
  XCTAssertEqualObjects(appId, requestBodyDict[@"requesting_client_app"][@"gmp_app_id"]);
  XCTAssertEqualObjects(FIDValue, requestBodyDict[@"requesting_client_app"][@"app_instance_id"]);
  XCTAssertEqualObjects(FISToken,
                        requestBodyDict[@"requesting_client_app"][@"app_instance_id_token"]);

  XCTAssertEqualObjects(osVersion, requestBodyDict[@"client_signals"][@"platform_version"]);
  XCTAssertEqualObjects(appVersion, requestBodyDict[@"client_signals"][@"app_version"]);
  XCTAssertEqualObjects(deviceLanguage, requestBodyDict[@"client_signals"][@"language_code"]);
  XCTAssertEqualObjects(timezone, requestBodyDict[@"client_signals"][@"time_zone"]);
}

- (void)testRequestConstructionWithImpressionData {
  __block NSURLRequest *capturedNSURLRequest;
  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(NSURLRequest *request) {
        capturedNSURLRequest = request;
        return YES;
      }]
        completionHandler:[OCMArg any]  // second parameter is the callback which we don't care in
                                        // this unit testing
  ]);

  NSString *FIDValue = @"my FID";
  NSString *FISToken = @"my FIS token";
  OCMStub([self.mockclientInfoFetcher
      fetchFirebaseInstallationDataWithProjectNumber:[OCMArg any]
                                      withCompletion:([OCMArg
                                                         invokeBlockWithArgs:FIDValue, FISToken,
                                                                             [NSNull null], nil])]);

  // this is to test the case that only partial client signal fields are available
  NSString *osVersion = @"OS Version";
  OCMStub([self.mockclientInfoFetcher getOSVersion]).andReturn(osVersion);
  NSString *appVersion = @"App Version";
  OCMStub([self.mockclientInfoFetcher getAppVersion]).andReturn(appVersion);

  long impression1Timestamp = 12345;
  FIRIAMImpressionRecord *impression1 =
      [[FIRIAMImpressionRecord alloc] initWithMessageID:@"impression 1"
                                impressionTimeInSeconds:impression1Timestamp];
  long impression2Timestamp = 45678;
  FIRIAMImpressionRecord *impression2 =
      [[FIRIAMImpressionRecord alloc] initWithMessageID:@"impression 2"
                                impressionTimeInSeconds:impression2Timestamp];

  [self.fetcher
      fetchMessagesWithImpressionList:@[ impression1, impression2 ]
                       withCompletion:^(NSArray<FIRIAMMessageDefinition *> *_Nullable messages,
                                        NSNumber *_Nullable nextFetchWaitTime,
                                        NSInteger discardCount, NSError *_Nullable error){
                           // blank on purpose: it won't get triggered
                       }];

  // verify that the captured nsurl request has expected body
  NSError *errorJson = nil;
  NSDictionary *requestBodyDict =
      [NSJSONSerialization JSONObjectWithData:capturedNSURLRequest.HTTPBody
                                      options:kNilOptions
                                        error:&errorJson];

  XCTAssertEqualObjects(impression1.messageID,
                        requestBodyDict[@"already_seen_campaigns"][0][@"campaign_id"]);
  XCTAssertEqualWithAccuracy(
      impression1Timestamp * 1000,
      ((NSNumber *)requestBodyDict[@"already_seen_campaigns"][0][@"impression_timestamp_millis"])
          .longValue,
      0.1);
  XCTAssertEqualObjects(impression2.messageID,
                        requestBodyDict[@"already_seen_campaigns"][1][@"campaign_id"]);
  XCTAssertEqualWithAccuracy(
      impression2Timestamp * 1000,
      ((NSNumber *)requestBodyDict[@"already_seen_campaigns"][1][@"impression_timestamp_millis"])
          .longValue,
      0.1);

  XCTAssertEqualObjects(osVersion, requestBodyDict[@"client_signals"][@"platform_version"]);
  XCTAssertEqualObjects(appVersion, requestBodyDict[@"client_signals"][@"app_version"]);
  // not expecting language signal since it's not mocked on mockclientInfoFetcher
  XCTAssertNil(requestBodyDict[@"client_signals"][@"language_code"]);
}

- (void)testBailoutOnFIDError {
  // in this test, the attempt to fetch iid data failed and as a result, we expect the whole
  // fetch operation attempt to fail with that error
  NSError *FIDError = [[NSError alloc] initWithDomain:@"Error Domain" code:100 userInfo:nil];
  OCMStub([self.mockclientInfoFetcher
      fetchFirebaseInstallationDataWithProjectNumber:[OCMArg any]
                                      withCompletion:([OCMArg invokeBlockWithArgs:[NSNull null],
                                                                                  [NSNull null],
                                                                                  FIDError, nil])]);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"fetch callback block triggered."];
  [self.fetcher
      fetchMessagesWithImpressionList:@[]
                       withCompletion:^(NSArray<FIRIAMMessageDefinition *> *_Nullable messages,
                                        NSNumber *_Nullable nextFetchWaitTime,
                                        NSInteger discardCount, NSError *_Nullable error) {
                         // expecting triggering the completion callback with error
                         XCTAssertNil(messages);
                         XCTAssertEqualObjects(FIDError, error);
                         [expectation fulfill];
                       }];

  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}
@end
