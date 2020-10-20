/*
 * Copyright 2020 Google LLC
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

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>
#import "FBLPromise+Testing.h"

#import "FirebaseAppCheck/Source/Library/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Source/Library/Core/Private/FIRAppCheckAPIService.h"
#import "FirebaseAppCheck/Source/Library/Core/Public/FIRAppCheckToken.h"

#import "SharedTestUtilities/Date/FIRDateTestUtils.h"
#import "SharedTestUtilities/URLSession/FIRURLSessionOCMockStub.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

@interface FIRAppCheckAPIServiceTests : XCTestCase

@property(nonatomic) FIRAppCheckAPIService *APIService;

@property(nonatomic) id mockURLSession;
@property(nonatomic) id mockHeartbeatInfo;

@property(nonatomic) NSString *APIKey;
@property(nonatomic) NSString *projectID;
@property(nonatomic) NSString *appID;

@end

@implementation FIRAppCheckAPIServiceTests

- (void)setUp {
  [super setUp];

  self.APIKey = @"api_key";
  self.projectID = @"project_id";
  self.appID = @"app_id";

  // Stub FIRHeartbeatInfo.
  self.mockHeartbeatInfo = OCMClassMock([FIRHeartbeatInfo class]);
  OCMStub([self.mockHeartbeatInfo heartbeatCodeForTag:@"fire-app-check"])
      .andDo(^(NSInvocation *invocation) {
        XCTAssertFalse([NSThread isMainThread]);
      })
      .andReturn(FIRHeartbeatInfoCodeCombined);

  self.mockURLSession = OCMStrictClassMock([NSURLSession class]);

  self.APIService = [[FIRAppCheckAPIService alloc] initWithURLSession:self.mockURLSession
                                                               APIKey:self.APIKey
                                                            projectID:self.projectID
                                                                appID:self.appID];
}

- (void)tearDown {
  [super tearDown];

  self.APIService = nil;
  [self.mockURLSession stopMocking];
  self.mockURLSession = nil;
  [self.mockHeartbeatInfo stopMocking];
  self.mockHeartbeatInfo = nil;
}

- (void)testDataRequestSuccess {
  NSURL *URL = [NSURL URLWithString:@"https://some.url.com"];
  NSDictionary *additionalHeaders = @{@"header1" : @"value1"};
  NSData *requestBody = [@"Request body" dataUsingEncoding:NSUTF8StringEncoding];

  // 1. Stub URL session.
  FIRRequestValidationBlock requestValidation = ^BOOL(NSURLRequest *request) {
    XCTAssertEqualObjects(request.URL, URL);
    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"x-firebase-client"],
                          [FIRApp firebaseUserAgent]);
    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"X-firebase-client-log-type"], @"3");
    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"X-Goog-Api-Key"], self.APIKey);

    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"header1"], @"value1");

    XCTAssertEqualObjects(request.HTTPMethod, @"POST");
    XCTAssertEqualObjects(request.HTTPBody, requestBody);

    return YES;
  };

  NSData *HTTPResponseBody = [@"A response" dataUsingEncoding:NSUTF8StringEncoding];
  NSHTTPURLResponse *HTTPResponse = [FIRURLSessionOCMockStub HTTPResponseWithCode:200];
  id mockURLDataTask =
      [FIRURLSessionOCMockStub stubURLSessionDataTaskWithResponse:HTTPResponse
                                                             body:HTTPResponseBody
                                                            error:nil
                                                   URLSessionMock:self.mockURLSession
                                           requestValidationBlock:requestValidation];

  // 2. Send request.
  __auto_type requestPromise = [self.APIService sendRequestWithURL:URL
                                                        HTTPMethod:@"POST"
                                                              body:requestBody
                                                 additionalHeaders:additionalHeaders];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(requestPromise.isFulfilled);
  XCTAssertNil(requestPromise.error);

  XCTAssertEqualObjects(requestPromise.value.HTTPResponse, HTTPResponse);
  XCTAssertEqualObjects(requestPromise.value.data, HTTPResponseBody);

  OCMVerifyAll(mockURLDataTask);
  OCMVerifyAll(self.mockURLSession);
}

- (void)testDataRequestNetworkError {
  NSURL *URL = [NSURL URLWithString:@"https://some.url.com"];
  NSDictionary *additionalHeaders = @{@"header1" : @"value1"};
  NSData *requestBody = [@"Request body" dataUsingEncoding:NSUTF8StringEncoding];

  // 1. Stub URL session.
  NSError *networkError = [NSError errorWithDomain:self.name code:-1 userInfo:nil];

  id mockURLDataTask =
      [FIRURLSessionOCMockStub stubURLSessionDataTaskWithResponse:nil
                                                             body:nil
                                                            error:networkError
                                                   URLSessionMock:self.mockURLSession
                                           requestValidationBlock:nil];

  // 2. Send request.
  __auto_type requestPromise = [self.APIService sendRequestWithURL:URL
                                                        HTTPMethod:@"POST"
                                                              body:requestBody
                                                 additionalHeaders:additionalHeaders];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(requestPromise.isRejected);
  XCTAssertNotNil(requestPromise.error);
  XCTAssertEqualObjects(requestPromise.error.domain, kFIRAppCheckErrorDomain);
  XCTAssertEqual(requestPromise.error.code, FIRAppCheckErrorCodeUnknown);
  XCTAssertEqualObjects(requestPromise.error.userInfo[NSUnderlyingErrorKey], networkError);

  OCMVerifyAll(mockURLDataTask);
  OCMVerifyAll(self.mockURLSession);
}

- (void)testDataRequestNot2xxHTTPStatusCode {
  NSURL *URL = [NSURL URLWithString:@"https://some.url.com"];
  NSData *requestBody = [@"Request body" dataUsingEncoding:NSUTF8StringEncoding];
  NSString *responseBodyString = @"Token verification failed.";

  NSData *HTTPResponseBody = [responseBodyString dataUsingEncoding:NSUTF8StringEncoding];
  NSHTTPURLResponse *HTTPResponse = [FIRURLSessionOCMockStub HTTPResponseWithCode:300];
  id mockURLDataTask =
      [FIRURLSessionOCMockStub stubURLSessionDataTaskWithResponse:HTTPResponse
                                                             body:HTTPResponseBody
                                                            error:nil
                                                   URLSessionMock:self.mockURLSession
                                           requestValidationBlock:nil];

  // 2. Send request.
  __auto_type requestPromise = [self.APIService sendRequestWithURL:URL
                                                        HTTPMethod:@"POST"
                                                              body:requestBody
                                                 additionalHeaders:nil];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(requestPromise.isRejected);
  XCTAssertNil(requestPromise.value);

  XCTAssertNotNil(requestPromise.error);
  XCTAssertEqualObjects(requestPromise.error.domain, kFIRAppCheckErrorDomain);
  XCTAssertEqual(requestPromise.error.code, FIRAppCheckErrorCodeUnknown);

  // Expect response body and HTTP status code to be included in the error.
  NSString *failureReason = requestPromise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  XCTAssertNotNil(failureReason);
  XCTAssertTrue([failureReason containsString:@"300"]);
  XCTAssertTrue([failureReason containsString:responseBodyString]);

  OCMVerifyAll(mockURLDataTask);
  OCMVerifyAll(self.mockURLSession);
}

@end
