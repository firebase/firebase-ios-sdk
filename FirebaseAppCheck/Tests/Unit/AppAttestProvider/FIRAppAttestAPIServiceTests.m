/*
 * Copyright 2021 Google LLC
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

#import "FBLPromise+Testing.h"
#import "OCMock.h"

#import <GoogleUtilities/GULURLSessionDataResponse.h>

#import "FirebaseAppCheck/Sources/AppAttestProvider/API/FIRAppAttestAPIService.h"
#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"
#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"

#import "FirebaseAppCheck/Tests/Unit/Utils/FIRFixtureLoader.h"
#import "SharedTestUtilities/URLSession/FIRURLSessionOCMockStub.h"

@interface FIRAppAttestAPIServiceTests : XCTestCase

@property(nonatomic) FIRAppAttestAPIService *appAttestAPIService;

@property(nonatomic) id mockAPIService;

@property(nonatomic) NSString *projectID;
@property(nonatomic) NSString *appID;

@end

@implementation FIRAppAttestAPIServiceTests

- (void)setUp {
  [super setUp];

  self.projectID = @"project_id";
  self.appID = @"app_id";

  self.mockAPIService = OCMProtocolMock(@protocol(FIRAppCheckAPIServiceProtocol));
  OCMStub([self.mockAPIService baseURL]).andReturn(@"https://test.appcheck.url.com/beta");

  self.appAttestAPIService = [[FIRAppAttestAPIService alloc] initWithAPIService:self.mockAPIService
                                                                      projectID:self.projectID
                                                                          appID:self.appID];
}

- (void)tearDown {
  [super tearDown];

  self.appAttestAPIService = nil;
  [self.mockAPIService stopMocking];
  self.mockAPIService = nil;
}

- (void)testGetRandomChallengeWhenAPIResponseValid {
  // 1. Prepare API response.
  NSData *responseBody = [FIRFixtureLoader loadFixtureNamed:@"AppAttestResponseSuccess.json"];
  GULURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                             responseBody:responseBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestWithResponse:validAPIResponse];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isFulfilled);
  XCTAssertNotNil(promise.value);
  XCTAssertNil(promise.error);

  NSString *challengeString = [[NSString alloc] initWithData:promise.value
                                                    encoding:NSUTF8StringEncoding];
  XCTAssert([challengeString isEqualToString:@"random_challenge"]);

  OCMVerifyAll(self.mockAPIService);
}

- (void)testGetRandomChallengeWhenAPIError {
  // 1. Prepare API response.
  NSString *responseBodyString = @"Generate challenge failed with invalid format.";
  NSData *responseBody = [responseBodyString dataUsingEncoding:NSUTF8StringEncoding];
  GULURLSessionDataResponse *invalidAPIResponse = [self APIResponseWithCode:300
                                                               responseBody:responseBody];
  NSError *APIError = [FIRAppCheckErrorUtil APIErrorWithHTTPResponse:invalidAPIResponse.HTTPResponse
                                                                data:invalidAPIResponse.HTTPBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestWithResponse:APIError];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isRejected);
  XCTAssertNotNil(promise.error);
  XCTAssertNil(promise.value);

  // Assert error is as expected.
  XCTAssertEqualObjects(promise.error.domain, kFIRAppCheckErrorDomain);
  XCTAssertEqual(promise.error.code, FIRAppCheckErrorCodeUnknown);

  // Expect response body and HTTP status code to be included in the error.
  NSString *failureReason = promise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  XCTAssertTrue([failureReason containsString:@"300"]);
  XCTAssertTrue([failureReason containsString:responseBodyString]);

  OCMVerifyAll(self.mockAPIService);
}

- (void)testGetRandomChallengeWhenAPIResponseEmpty {
  // 1. Prepare API response.
  NSData *responseBody = [NSData data];
  GULURLSessionDataResponse *emptyAPIResponse = [self APIResponseWithCode:200
                                                             responseBody:responseBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestWithResponse:emptyAPIResponse];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isRejected);
  XCTAssertNotNil(promise.error);
  XCTAssertNil(promise.value);

  // Expect response body and HTTP status code to be included in the error.
  NSString *failureReason = promise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  XCTAssertEqualObjects(failureReason, @"Empty server response body.");

  OCMVerifyAll(self.mockAPIService);
}

- (void)testGetRandomChallengeWhenAPIResponseInvalidFormat {
  // 1. Prepare API response.
  NSString *responseBodyString = @"Generate challenge failed with invalid format.";
  NSData *responseBody = [responseBodyString dataUsingEncoding:NSUTF8StringEncoding];
  GULURLSessionDataResponse *validAPIResponse = [self APIResponseWithCode:200
                                                             responseBody:responseBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestWithResponse:validAPIResponse];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isRejected);
  XCTAssertNotNil(promise.error);
  XCTAssertNil(promise.value);

  // Expect response body and HTTP status code to be included in the error.
  NSString *failureReason = promise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  XCTAssertEqualObjects(failureReason, @"JSON serialization error.");

  OCMVerifyAll(self.mockAPIService);
}

- (void)testGetRandomChallengeWhenResponseMissingField {
  [self assertMissingFieldErrorWithFixture:@"AppAttestResponseMissingChallenge.json"
                              missingField:@"challenge"];
}

- (void)assertMissingFieldErrorWithFixture:(NSString *)fixtureName
                              missingField:(NSString *)fieldName {
  // 1. Prepare API response.
  NSData *missingFieldBody = [FIRFixtureLoader loadFixtureNamed:fixtureName];
  GULURLSessionDataResponse *incompleteAPIResponse = [self APIResponseWithCode:200
                                                                  responseBody:missingFieldBody];
  // 2. Stub API Service Request to return prepared API response.
  [self stubMockAPIServiceRequestWithResponse:incompleteAPIResponse];

  // 3. Request the random challenge and verify results.
  __auto_type *promise = [self.appAttestAPIService getRandomChallenge];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssert(promise.isRejected);
  XCTAssertNotNil(promise.error);
  XCTAssertNil(promise.value);

  // Assert error is as expected.
  XCTAssertEqualObjects(promise.error.domain, kFIRAppCheckErrorDomain);
  XCTAssertEqual(promise.error.code, FIRAppCheckErrorCodeUnknown);

  // Expect missing field name to be included in the error.
  NSString *failureReason = promise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  NSString *fieldNameString = [NSString stringWithFormat:@"`%@`", fieldName];
  XCTAssertTrue([failureReason containsString:fieldNameString],
                @"Fixture `%@`: expected missing field %@ error not found", fixtureName,
                fieldNameString);
}

#pragma mark - Helpers

- (GULURLSessionDataResponse *)APIResponseWithCode:(NSInteger)code
                                      responseBody:(NSData *)responseBody {
  XCTAssertNotNil(responseBody);
  NSHTTPURLResponse *HTTPResponse = [FIRURLSessionOCMockStub HTTPResponseWithCode:code];
  GULURLSessionDataResponse *APIResponse =
      [[GULURLSessionDataResponse alloc] initWithResponse:HTTPResponse HTTPBody:responseBody];
  return APIResponse;
}

- (void)stubMockAPIServiceRequestWithResponse:(id)response {
  id URLValidationArg = [self URLValidationCheckBlock];
  OCMStub([self.mockAPIService sendRequestWithURL:URLValidationArg
                                       HTTPMethod:@"POST"
                                             body:nil
                                additionalHeaders:nil])
      .andDo(^(NSInvocation *invocation) {
        XCTAssertFalse([NSThread isMainThread]);
      })
      .andReturn([FBLPromise resolvedWith:response]);
}

- (id)URLValidationCheckBlock {
  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@/projects/%@/apps/%@:generateAppAttestChallenge",
                                 [self.mockAPIService baseURL], self.projectID, self.appID];

  id URLValidationArg = [OCMArg checkWithBlock:^BOOL(NSURL *URL) {
    XCTAssertEqualObjects(URL.absoluteString, expectedRequestURL);
    return YES;
  }];
  return URLValidationArg;
}

@end
