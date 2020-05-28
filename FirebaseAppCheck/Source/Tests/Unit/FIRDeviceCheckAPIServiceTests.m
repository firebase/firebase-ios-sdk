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
  id mockURLDataTask = [self stubURLSessionDataTaskWithResponse:[self HTTPResponseSuccess]
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

// TODO: Test failures.

#pragma mark - Helpers

- (id)stubURLSessionDataTaskWithResponse:(NSHTTPURLResponse *)response
                                    body:(NSData *)body
                                   error:(NSError *)error
                  requestValidationBlock:(FIRRequestValidationBlock)requestValidationBlock {
  __block id mockDataTask = OCMStrictClassMock([NSURLSessionDataTask class]);

  // Validate request content.
  id URLRequestValidationArg = [OCMArg checkWithBlock:requestValidationBlock];

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

- (NSHTTPURLResponse *)HTTPResponseSuccess {
  return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://localhost"]
                                     statusCode:200
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
