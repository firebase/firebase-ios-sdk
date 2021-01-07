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

#import "FBLPromise+Testing.h"
#import "OCMock.h"
#import "SharedTestUtilities/URLSession/FIRURLSessionOCMockStub.h"

#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULURLSessionDataResponse.h"
#import "GoogleUtilities/Environment/Public/GoogleUtilities/NSURLSession+GULPromises.h"

@interface NSURLSession_GULPromisesTests : XCTestCase
@property(nonatomic) NSURLSession *URLSession;
@property(nonatomic) id URLSessionMock;
@end

@implementation NSURLSession_GULPromisesTests

- (void)setUp {
  self.URLSession = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
  self.URLSessionMock = OCMPartialMock(self.URLSession);
}

- (void)tearDown {
  [self.URLSessionMock stopMocking];
  self.URLSessionMock = nil;
  self.URLSession = nil;
}

- (void)testDataTaskPromiseWithRequestSuccess {
  NSURL *url = [NSURL URLWithString:@"https://localhost"];
  NSURLRequest *request = [NSURLRequest requestWithURL:url];

  NSHTTPURLResponse *expectedResponse = [[NSHTTPURLResponse alloc] initWithURL:url
                                                                    statusCode:200
                                                                   HTTPVersion:@"1.1"
                                                                  headerFields:nil];
  NSData *expectedBody = [@"body" dataUsingEncoding:NSUTF8StringEncoding];

  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:expectedResponse
                                    body:expectedBody
                                   error:nil
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    return [sentRequest isEqual:request];
                  }];

  __auto_type taskPromise = [self.URLSessionMock gul_dataTaskPromiseWithRequest:request];

  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertTrue(taskPromise.isFulfilled);
  XCTAssertNil(taskPromise.error);
  XCTAssertEqualObjects(taskPromise.value.HTTPResponse, expectedResponse);
  XCTAssertEqualObjects(taskPromise.value.HTTPBody, expectedBody);
}

- (void)testDataTaskPromiseWithRequestError {
  NSURL *url = [NSURL URLWithString:@"https://localhost"];
  NSURLRequest *request = [NSURLRequest requestWithURL:url];

  NSError *expectedError = [NSError errorWithDomain:@"testDataTaskPromiseWithRequestError"
                                               code:-1
                                           userInfo:nil];

  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:nil
                                    body:nil
                                   error:expectedError
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    return [sentRequest isEqual:request];
                  }];

  __auto_type taskPromise = [self.URLSessionMock gul_dataTaskPromiseWithRequest:request];

  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertTrue(taskPromise.isRejected);
  XCTAssertEqualObjects(taskPromise.error, expectedError);
  XCTAssertNil(taskPromise.value);
}

@end
