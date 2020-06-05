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

#import "FIRAppCheckErrorUtil.h"
#import "FIRAppCheckToken.h"
#import "FIRDeviceCheckAPIService.h"

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRHeartbeatInfo.h>

typedef BOOL (^FIRRequestValidationBlock)(NSURLRequest *request);

@interface FIRDeviceCheckAPIServiceTests : XCTestCase
@property(nonatomic) FIRDeviceCheckAPIService *APIService;

@property(nonatomic) id mockURLSession;
@property(nonatomic) id mockHeartbeatInfo;

@property(nonatomic) NSString *APIKey;
@property(nonatomic) NSString *projectID;
@property(nonatomic) NSString *appID;

@end

@implementation FIRDeviceCheckAPIServiceTests

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

  self.APIService = [[FIRDeviceCheckAPIService alloc] initWithURLSession:self.mockURLSession
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

- (void)testAppCheckTokenSuccess {
  NSData *deviceTokenData = [@"device_token" dataUsingEncoding:NSUTF8StringEncoding];
  NSString *expectedToken = @"valid_app_check_token";

  // 1. Stub URL session.
  FIRRequestValidationBlock requestValidation = ^BOOL(NSURLRequest *request) {
    XCTAssertEqualObjects(request.URL.absoluteString,
                          @"https://firebaseappcheck.googleapis.com/v1alpha1/projects/project_id/"
                          @"apps/app_id:exchangeDeviceCheckToken");
    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"x-firebase-client"],
                          [FIRApp firebaseUserAgent]);
    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"X-firebase-client-log-type"], @"3");
    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"X-Goog-Api-Key"], self.APIKey);

    XCTAssertEqualObjects(request.HTTPBody, deviceTokenData);
    return YES;
  };

  NSData *HTTPResponseBody = [self loadFixtureNamed:@"DeviceCheckResponseSuccess.json"];
  id mockURLDataTask = [self stubURLSessionDataTaskWithResponse:[self HTTPResponseWithCode:200]
                                                           body:HTTPResponseBody
                                                          error:nil
                                         requestValidationBlock:requestValidation];

  // 2. Send request.
  __auto_type tokenPromise = [self.APIService appCheckTokenWithDeviceToken:deviceTokenData];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isFulfilled);
  XCTAssertNil(tokenPromise.error);

  XCTAssertEqualObjects(tokenPromise.value.token, expectedToken);
  [self assertDate:tokenPromise.value.expirationDate
      isApproximatelyEqualCurrentPlusTimeInterval:1800];

  OCMVerifyAll(mockURLDataTask);
  OCMVerifyAll(self.mockURLSession);
}

- (void)testAppCheckTokenNetworkError {
  NSData *deviceTokenData = [@"device_token" dataUsingEncoding:NSUTF8StringEncoding];
  NSError *networkError = [NSError errorWithDomain:@"testAppCheckTokenNetworkError"
                                              code:-1
                                          userInfo:nil];

  // 1. Stub URL session.
  id mockURLDataTask = [self stubURLSessionDataTaskWithResponse:nil
                                                           body:nil
                                                          error:networkError
                                         requestValidationBlock:nil];

  // 2. Send request.
  __auto_type tokenPromise = [self.APIService appCheckTokenWithDeviceToken:deviceTokenData];

  // 3. Verify.
  XCTAssert(FBLWaitForPromisesWithTimeout(1));

  XCTAssertTrue(tokenPromise.isRejected);
  XCTAssertNil(tokenPromise.value);

  XCTAssertNotNil(tokenPromise.error);
  XCTAssertEqualObjects(tokenPromise.error.domain, kFIRAppCheckErrorDomain);
  XCTAssertEqual(tokenPromise.error.code, FIRAppCheckErrorCodeUnknown);
  XCTAssertEqualObjects(tokenPromise.error.userInfo[NSUnderlyingErrorKey], networkError);

  OCMVerifyAll(mockURLDataTask);
  OCMVerifyAll(self.mockURLSession);
}

- (void)testAppCheckTokenInvalidDeviceToken {
  NSData *deviceTokenData = [@"device_token" dataUsingEncoding:NSUTF8StringEncoding];
  NSString *responseBodyString = @"Token verification failed.";

  // 1. Stub URL session.

  id mockURLDataTask = [self
      stubURLSessionDataTaskWithResponse:[self HTTPResponseWithCode:300]
                                    body:[responseBodyString dataUsingEncoding:NSUTF8StringEncoding]
                                   error:nil
                  requestValidationBlock:nil];

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
  XCTAssertTrue([failureReason containsString:@"300"]);
  XCTAssertTrue([failureReason containsString:responseBodyString]);

  OCMVerifyAll(mockURLDataTask);
  OCMVerifyAll(self.mockURLSession);
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

  // 1. Stub URL session.
  NSData *missingFiledBody = [self loadFixtureNamed:fixtureName];
  id mockURLDataTask = [self stubURLSessionDataTaskWithResponse:[self HTTPResponseWithCode:200]
                                                           body:missingFiledBody
                                                          error:nil
                                         requestValidationBlock:nil];

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

  OCMVerifyAll(mockURLDataTask);
  OCMVerifyAll(self.mockURLSession);
}

- (id)stubURLSessionDataTaskWithResponse:(NSHTTPURLResponse *)response
                                    body:(NSData *)body
                                   error:(NSError *)error
                  requestValidationBlock:(FIRRequestValidationBlock)requestValidationBlock {
  __block id mockDataTask = OCMStrictClassMock([NSURLSessionDataTask class]);

  // Validate request content.
  FIRRequestValidationBlock nonOptionalRequestValidationBlock =
      requestValidationBlock ?: ^BOOL(id request) {
        return YES;
      };

  id URLRequestValidationArg = [OCMArg checkWithBlock:nonOptionalRequestValidationBlock];

  // Save task completion to be called on the `[NSURLSessionDataTask resume]`
  __block void (^taskCompletion)(NSData *, NSURLResponse *, NSError *);
  id completionArg = [OCMArg checkWithBlock:^BOOL(id obj) {
    taskCompletion = obj;
    return YES;
  }];

  // Expect `dataTaskWithRequest` to be called.
  OCMExpect([self.mockURLSession dataTaskWithRequest:URLRequestValidationArg
                                   completionHandler:completionArg])
      .andReturn(mockDataTask);

  // Expect the task to be resumed and call the task completion.
  OCMExpect([(NSURLSessionDataTask *)mockDataTask resume]).andDo(^(NSInvocation *invocation) {
    taskCompletion(body, response, error);
  });

  return mockDataTask;
}

- (NSHTTPURLResponse *)HTTPResponseWithCode:(NSInteger)statusCode {
  return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://localhost"]
                                     statusCode:statusCode
                                    HTTPVersion:@"HTTP/1.1"
                                   headerFields:nil];
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

- (void)assertDate:(NSDate *)date
    isApproximatelyEqualCurrentPlusTimeInterval:(NSTimeInterval)timeInterval {
  NSDate *expectedDate = [NSDate dateWithTimeIntervalSinceNow:timeInterval];

  NSTimeInterval precision = 10;
  XCTAssert(ABS([date timeIntervalSinceDate:expectedDate]) <= precision,
            @"date: %@ is not equal to expected %@ with precision %f - %@", date, expectedDate,
            precision, self.name);
}

@end
