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

#import <FirebaseAppCheck/FirebaseAppCheck.h>
#import <GoogleUtilities/GULURLSessionDataResponse.h>

#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"
#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/DeviceCheckProvider/API/FIRDeviceCheckAPIService.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckErrors.h"

#import "FirebaseAppCheck/Tests/Unit/Utils/FIRFixtureLoader.h"
#import "SharedTestUtilities/URLSession/FIRURLSessionOCMockStub.h"

#import "FirebaseCore/Internal/FirebaseCoreInternal.h"

typedef BOOL (^FIRRequestValidationBlock)(NSURLRequest *request);

@interface FIRDeviceCheckAPIServiceTests : XCTestCase
@property(nonatomic) FIRDeviceCheckAPIService *APIService;

@property(nonatomic) id mockAPIService;

@property(nonatomic) NSString *projectID;
@property(nonatomic) NSString *appID;

@end

@implementation FIRDeviceCheckAPIServiceTests

- (void)setUp {
  [super setUp];

  self.projectID = @"project_id";
  self.appID = @"app_id";

  self.mockAPIService = OCMProtocolMock(@protocol(FIRAppCheckAPIServiceProtocol));
  OCMStub([self.mockAPIService baseURL]).andReturn(@"https://test.appcheck.url.com/alpha");

  self.APIService = [[FIRDeviceCheckAPIService alloc] initWithAPIService:self.mockAPIService
                                                               projectID:self.projectID
                                                                   appID:self.appID];
}

- (void)tearDown {
  self.APIService = nil;
  [self.mockAPIService stopMocking];
  self.mockAPIService = nil;

  [super tearDown];
}

- (void)testAppCheckTokenSuccess {
  NSData *deviceTokenData = [@"device_token" dataUsingEncoding:NSUTF8StringEncoding];
  FIRAppCheckToken *expectedResult = [[FIRAppCheckToken alloc] initWithToken:@"app_check_token"
                                                              expirationDate:[NSDate date]];

  // 1. Stub API service.
  // 1.1 Stub send request.
  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@%@", [self.mockAPIService baseURL],
                                 @"/projects/project_id/apps/app_id:exchangeDeviceCheckToken"];
  id URLValidationArg = [OCMArg checkWithBlock:^BOOL(NSURL *URL) {
    XCTAssertEqualObjects(URL.absoluteString, expectedRequestURL);
    return YES;
  }];

  id HTTPBodyValidationArg = [self HTTPBodyValidationArgWithDeviceToken:deviceTokenData];

  NSData *responseBody =
      [FIRFixtureLoader loadFixtureNamed:@"FACTokenExchangeResponseSuccess.json"];
  XCTAssertNotNil(responseBody);

  NSHTTPURLResponse *HTTPResponse = [FIRURLSessionOCMockStub HTTPResponseWithCode:200];
  GULURLSessionDataResponse *APIResponse =
      [[GULURLSessionDataResponse alloc] initWithResponse:HTTPResponse HTTPBody:responseBody];

  OCMExpect([self.mockAPIService sendRequestWithURL:URLValidationArg
                                         HTTPMethod:@"POST"
                                               body:HTTPBodyValidationArg
                                  additionalHeaders:@{@"Content-Type" : @"application/json"}])
      .andReturn([FBLPromise resolvedWith:APIResponse]);

  // 1.2. Stub response parsing.
  OCMExpect([self.mockAPIService appCheckTokenWithAPIResponse:APIResponse])
      .andReturn([FBLPromise resolvedWith:expectedResult]);

  // 2. Send request.
  __auto_type tokenPromise = [self.APIService appCheckTokenWithDeviceToken:deviceTokenData];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isFulfilled);
  XCTAssertNil(tokenPromise.error);

  XCTAssertEqualObjects(tokenPromise.value.token, expectedResult.token);
  XCTAssertEqualObjects(tokenPromise.value.expirationDate, expectedResult.expirationDate);

  OCMVerifyAll(self.mockAPIService);
}

- (void)testAppCheckTokenResponseParsingError {
  NSData *deviceTokenData = [@"device_token" dataUsingEncoding:NSUTF8StringEncoding];
  NSError *parsingError = [NSError errorWithDomain:@"testAppCheckTokenResponseParsingError"
                                              code:-1
                                          userInfo:nil];

  // 1. Stub API service.
  // 1.1 Stub send request.
  NSString *expectedRequestURL =
      [NSString stringWithFormat:@"%@%@", [self.mockAPIService baseURL],
                                 @"/projects/project_id/apps/app_id:exchangeDeviceCheckToken"];
  id URLValidationArg = [OCMArg checkWithBlock:^BOOL(NSURL *URL) {
    XCTAssertEqualObjects(URL.absoluteString, expectedRequestURL);
    return YES;
  }];

  id HTTPBodyValidationArg = [self HTTPBodyValidationArgWithDeviceToken:deviceTokenData];

  NSData *responseBody =
      [FIRFixtureLoader loadFixtureNamed:@"FACTokenExchangeResponseSuccess.json"];
  XCTAssertNotNil(responseBody);

  NSHTTPURLResponse *HTTPResponse = [FIRURLSessionOCMockStub HTTPResponseWithCode:200];
  GULURLSessionDataResponse *APIResponse =
      [[GULURLSessionDataResponse alloc] initWithResponse:HTTPResponse HTTPBody:responseBody];

  OCMExpect([self.mockAPIService sendRequestWithURL:URLValidationArg
                                         HTTPMethod:@"POST"
                                               body:HTTPBodyValidationArg
                                  additionalHeaders:@{@"Content-Type" : @"application/json"}])
      .andReturn([FBLPromise resolvedWith:APIResponse]);

  // 1.2. Stub response parsing.
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:parsingError];
  OCMExpect([self.mockAPIService appCheckTokenWithAPIResponse:APIResponse])
      .andReturn(rejectedPromise);

  // 2. Send request.
  __auto_type tokenPromise = [self.APIService appCheckTokenWithDeviceToken:deviceTokenData];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isRejected);
  XCTAssertEqualObjects(tokenPromise.error, parsingError);
  XCTAssertNil(tokenPromise.value);

  OCMVerifyAll(self.mockAPIService);
}

- (void)testAppCheckTokenNetworkError {
  NSData *deviceTokenData = [@"device_token" dataUsingEncoding:NSUTF8StringEncoding];
  NSError *APIError = [NSError errorWithDomain:@"testAppCheckTokenNetworkError"
                                          code:-1
                                      userInfo:nil];

  // 1. Stub API service.
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:APIError];

  id HTTPBodyValidationArg = [self HTTPBodyValidationArgWithDeviceToken:deviceTokenData];
  OCMExpect([self.mockAPIService sendRequestWithURL:[OCMArg any]
                                         HTTPMethod:@"POST"
                                               body:HTTPBodyValidationArg
                                  additionalHeaders:@{@"Content-Type" : @"application/json"}])
      .andReturn(rejectedPromise);

  // 2. Send request.
  __auto_type tokenPromise = [self.APIService appCheckTokenWithDeviceToken:deviceTokenData];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isRejected);
  XCTAssertNil(tokenPromise.value);
  XCTAssertEqualObjects(tokenPromise.error, APIError);

  OCMVerifyAll(self.mockAPIService);
}

- (void)testAppCheckTokenEmptyDeviceToken {
  NSData *deviceTokenData = [NSData data];

  // 1. Stub API service.
  OCMReject([self.mockAPIService sendRequestWithURL:[OCMArg any]
                                         HTTPMethod:[OCMArg any]
                                               body:[OCMArg any]
                                  additionalHeaders:[OCMArg any]]);

  // 2. Send request.
  __auto_type tokenPromise = [self.APIService appCheckTokenWithDeviceToken:deviceTokenData];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isRejected);
  XCTAssertNil(tokenPromise.value);

  XCTAssertNotNil(tokenPromise.error);
  XCTAssertEqualObjects(tokenPromise.error.domain, FIRAppCheckErrorDomain);
  XCTAssertEqual(tokenPromise.error.code, FIRAppCheckErrorCodeUnknown);

  // Expect response body and HTTP status code to be included in the error.
  NSString *failureReason = tokenPromise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  XCTAssertEqualObjects(failureReason, @"DeviceCheck token must not be empty.");

  OCMVerifyAll(self.mockAPIService);
}

#pragma mark - Helpers

- (id)HTTPBodyValidationArgWithDeviceToken:(NSData *)deviceToken {
  return [OCMArg checkWithBlock:^BOOL(NSData *body) {
    NSDictionary<NSString *, id> *decodedData = [NSJSONSerialization JSONObjectWithData:body
                                                                                options:0
                                                                                  error:nil];
    XCTAssert([decodedData isKindOfClass:[NSDictionary class]]);

    NSString *base64EncodedDeviceToken = decodedData[@"device_token"];
    XCTAssertNotNil(base64EncodedDeviceToken);

    NSData *decodedToken = [[NSData alloc] initWithBase64EncodedString:base64EncodedDeviceToken
                                                               options:0];
    XCTAssertEqualObjects(decodedToken, deviceToken);
    return YES;
  }];
}

@end
