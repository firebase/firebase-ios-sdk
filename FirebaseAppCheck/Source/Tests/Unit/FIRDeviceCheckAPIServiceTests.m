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
#import "FirebaseAppCheck/Source/Library/DeviceCheckProvider/API/FIRDeviceCheckAPIService.h"

#import "TestUtilities/Date/FIRDateTestUtils.h"
#import "TestUtilities/URLSession/FIRURLSessionOCMockStub.h"

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRHeartbeatInfo.h>

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
  NSString *expectedToken = @"valid_app_check_token";

  // 1. Stub API service.
  id URLValidationArg = [OCMArg checkWithBlock:^BOOL(NSURL *URL) {
    XCTAssertEqualObjects(URL.absoluteString,
                          @"https://firebaseappcheck.googleapis.com/v1alpha1/projects/project_id/"
                          @"apps/app_id:exchangeDeviceCheckToken");
    return YES;
  }];

  NSData *responseBody = [self loadFixtureNamed:@"DeviceCheckResponseSuccess.json"];
  NSHTTPURLResponse *HTTPResponse = [FIRURLSessionOCMockStub HTTPResponseWithCode:200];
  FIRAppCheckHTTPResponse *APIResponse =
      [[FIRAppCheckHTTPResponse alloc] initWithResponse:HTTPResponse data:responseBody];

  OCMExpect([self.mockAPIService sendRequestWithURL:URLValidationArg
                                         HTTPMethod:@"POST"
                                               body:deviceTokenData
                                  additionalHeaders:nil])
      .andReturn([FBLPromise resolvedWith:APIResponse]);

  // 2. Send request.
  __auto_type tokenPromise = [self.APIService appCheckTokenWithDeviceToken:deviceTokenData];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isFulfilled);
  XCTAssertNil(tokenPromise.error);

  XCTAssertEqualObjects(tokenPromise.value.token, expectedToken);

  XCTAssertTrue([FIRDateTestUtils isDate:tokenPromise.value.expirationDate
      approximatelyEqualCurrentPlusTimeInterval:1800
                                      precision:10]);

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

  OCMExpect([self.mockAPIService sendRequestWithURL:[OCMArg any]
                                         HTTPMethod:@"POST"
                                               body:deviceTokenData
                                  additionalHeaders:nil])
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

- (void)testAppCheckTokenInvalidDeviceToken {
  NSData *deviceTokenData = [@"device_token" dataUsingEncoding:NSUTF8StringEncoding];
  NSString *responseBodyString = @"Token verification failed.";

  // 1. Stub API service.
  NSData *responseBody = [responseBodyString dataUsingEncoding:NSUTF8StringEncoding];
  NSHTTPURLResponse *HTTPResponse = [FIRURLSessionOCMockStub HTTPResponseWithCode:200];
  FIRAppCheckHTTPResponse *APIResponse =
      [[FIRAppCheckHTTPResponse alloc] initWithResponse:HTTPResponse data:responseBody];

  OCMExpect([self.mockAPIService sendRequestWithURL:[OCMArg any]
                                         HTTPMethod:@"POST"
                                               body:deviceTokenData
                                  additionalHeaders:nil])
      .andReturn([FBLPromise resolvedWith:APIResponse]);

  // 2. Send request.
  __auto_type tokenPromise = [self.APIService appCheckTokenWithDeviceToken:deviceTokenData];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isRejected);
  XCTAssertNil(tokenPromise.value);

  XCTAssertNotNil(tokenPromise.error);
  XCTAssertEqualObjects(tokenPromise.error.domain, kFIRAppCheckErrorDomain);
  XCTAssertEqual(tokenPromise.error.code, FIRAppCheckErrorCodeUnknown);

  // Expect response body and HTTP status code to be included in the error.
  NSString *failureReason = tokenPromise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  XCTAssertEqualObjects(failureReason, @"JSON serialization error.");

  OCMVerifyAll(self.mockAPIService);
}

- (void)testAppCheckTokenResponseMissingFields {
  [self assertMissingFieldErrorWithFixture:@"DeviceCheckResponseMissingToken.json"
                              missingField:@"attestation_token"];
  [self assertMissingFieldErrorWithFixture:@"DeviceCheckResponseMissingTimeToLive.json"
                              missingField:@"time_to_live"];
  [self assertMissingFieldErrorWithFixture:@"DeviceCheckResponseMissingSeconds.json"
                              missingField:@"time_to_live.seconds"];
}

#pragma mark - Helpers

- (void)assertMissingFieldErrorWithFixture:(NSString *)fixtureName
                              missingField:(NSString *)fieldName {
  NSData *deviceTokenData = [@"device_token" dataUsingEncoding:NSUTF8StringEncoding];

  // 1. Stub API service.
  NSData *missingFiledBody = [self loadFixtureNamed:fixtureName];

  NSHTTPURLResponse *HTTPResponse = [FIRURLSessionOCMockStub HTTPResponseWithCode:200];
  FIRAppCheckHTTPResponse *APIResponse =
      [[FIRAppCheckHTTPResponse alloc] initWithResponse:HTTPResponse data:missingFiledBody];

  OCMExpect([self.mockAPIService sendRequestWithURL:[OCMArg any]
                                         HTTPMethod:@"POST"
                                               body:deviceTokenData
                                  additionalHeaders:nil])
      .andReturn([FBLPromise resolvedWith:APIResponse]);

  // 2. Send request.
  __auto_type tokenPromise = [self.APIService appCheckTokenWithDeviceToken:deviceTokenData];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isRejected);
  XCTAssertNil(tokenPromise.value);

  XCTAssertNotNil(tokenPromise.error);
  XCTAssertEqualObjects(tokenPromise.error.domain, kFIRAppCheckErrorDomain);
  XCTAssertEqual(tokenPromise.error.code, FIRAppCheckErrorCodeUnknown);

  // Expect missing field name to be included in the error.
  NSString *failureReason = tokenPromise.error.userInfo[NSLocalizedFailureReasonErrorKey];
  NSString *fieldNameString = [NSString stringWithFormat:@"`%@`", fieldName];
  XCTAssertTrue([failureReason containsString:fieldNameString],
                @"Fixture `%@`: expected missing field %@ error not found", fixtureName,
                fieldNameString);

  OCMVerifyAll(self.mockAPIService);
}

- (NSData *)loadFixtureNamed:(NSString *)fileName {
  NSURL *fileURL = [[NSBundle bundleForClass:[self class]] URLForResource:fileName
                                                            withExtension:nil];
  XCTAssertNotNil(fileURL);

  NSError *error;
  NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:&error];
  XCTAssertNotNil(data, @"File name: %@ Error: %@", fileName, error);

  return data;
}

@end
