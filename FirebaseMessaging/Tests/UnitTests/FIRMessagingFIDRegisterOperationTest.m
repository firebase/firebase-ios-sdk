/*
 * Copyright 2026 Google LLC
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

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingFIDRegisterOperation.h"
#import "SharedTestUtilities/URLSession/FIRURLSessionOCMockStub.h"

@interface FIRInstallationsAuthTokenResult (Tests)
- (instancetype)initWithToken:(NSString *)token expirationDate:(NSDate *)expirationDate;
@end

@interface FIRMessagingFIDRegisterOperationTest : XCTestCase

@property(nonatomic) id URLSessionMock;
@property(nonatomic) id mockInstallations;
@property(nonatomic) id mockFirebaseApp;
@property(nonatomic) id mockOptions;

@end

@implementation FIRMessagingFIDRegisterOperationTest

- (void)setUp {
  [super setUp];

  self.URLSessionMock = OCMClassMock([NSURLSession class]);
  OCMStub(ClassMethod([self.URLSessionMock sessionWithConfiguration:[OCMArg any]]))
      .andReturn(self.URLSessionMock);

  self.mockInstallations = OCMClassMock([FIRInstallations class]);
  OCMStub([self.mockInstallations installations]).andReturn(self.mockInstallations);

  self.mockFirebaseApp = OCMClassMock([FIRApp class]);
  OCMStub([self.mockFirebaseApp defaultApp]).andReturn(self.mockFirebaseApp);

  self.mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([(FIRApp *)self.mockFirebaseApp options]).andReturn(self.mockOptions);
  OCMStub([self.mockOptions projectID]).andReturn(@"test-project-id");
  OCMStub([self.mockOptions APIKey]).andReturn(@"test-api-key");
}

- (void)tearDown {
  [self.URLSessionMock stopMocking];
  [self.mockInstallations stopMocking];
  [self.mockFirebaseApp stopMocking];
  [self.mockOptions stopMocking];
  [super tearDown];
}

- (void)testRequestConstruction {
  NSDictionary *options = @{
    kFIRMessagingTokenOptionsAPNSKey : [@"fakeAPNSToken" dataUsingEncoding:NSUTF8StringEncoding],
    kFIRMessagingTokenOptionsAPNSIsSandboxKey : @YES
  };

  FIRInstallationsAuthTokenResult *mockTokenResult =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"fis-auth-token"
                                              expirationDate:[NSDate distantFuture]];

  id authTokenWithCompletionArg = [OCMArg invokeBlockWithArgs:mockTokenResult, [NSNull null], nil];
  OCMStub([self.mockInstallations authTokenWithCompletion:authTokenWithCompletionArg]);

  FIRMessagingFIDRegisterOperation *operation =
      [[FIRMessagingFIDRegisterOperation alloc] initWithAuthorizedEntity:@"sender-123"
                                                                   scope:@"fcm"
                                                                 options:options
                                                              instanceID:@"instance-id"
                                                           installations:self.mockInstallations];

  XCTestExpectation *requestExpectation = [self expectationWithDescription:@"Request validation"];

  NSHTTPURLResponse *response =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]
                                  statusCode:200
                                 HTTPVersion:@"HTTP/1.1"
                                headerFields:nil];

  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:response
                                    body:[@"{\"name\":\"projects/sender-123/registrations/"
                                          @"fake-fid\"}" dataUsingEncoding:NSUTF8StringEncoding]
                                   error:nil
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    XCTAssertEqualObjects(sentRequest.URL.absoluteString,
                                          @"https://fcmregistrations.googleapis.com/v1/projects/"
                                          @"test-project-id/registrations");
                    XCTAssertEqualObjects(sentRequest.HTTPMethod, @"POST");
                    XCTAssertEqualObjects(sentRequest.allHTTPHeaderFields[@"X-Goog-Api-Key"],
                                          @"test-api-key");
                    XCTAssertEqualObjects(
                        sentRequest.allHTTPHeaderFields[@"X-Goog-Firebase-Installations-Auth"],
                        @"fis-auth-token");

                    // Verify body
                    NSDictionary *body =
                        [NSJSONSerialization JSONObjectWithData:sentRequest.HTTPBody
                                                        options:0
                                                          error:nil];
                    XCTAssertNotNil(body[@"ios"]);
                    XCTAssertEqualObjects(body[@"ios"][@"apns_token"],
                                          FIRMessagingStringForAPNSDeviceToken(
                                              options[kFIRMessagingTokenOptionsAPNSKey]));
                    XCTAssertEqualObjects(body[@"ios"][@"apns_environment"], @"SANDBOX");

                    [requestExpectation fulfill];
                    return YES;
                  }];

  [operation start];

  [self waitForExpectationsWithTimeout:0.5 handler:nil];
}

- (void)testSuccessfulResponse {
  NSDictionary *options = @{
    kFIRMessagingTokenOptionsAPNSKey : [@"fakeAPNSToken" dataUsingEncoding:NSUTF8StringEncoding],
    kFIRMessagingTokenOptionsAPNSIsSandboxKey : @NO
  };

  FIRInstallationsAuthTokenResult *mockTokenResult =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"fis-auth-token"
                                              expirationDate:[NSDate distantFuture]];

  id authTokenWithCompletionArg = [OCMArg invokeBlockWithArgs:mockTokenResult, [NSNull null], nil];
  OCMStub([self.mockInstallations authTokenWithCompletion:authTokenWithCompletionArg]);

  FIRMessagingFIDRegisterOperation *operation =
      [[FIRMessagingFIDRegisterOperation alloc] initWithAuthorizedEntity:@"sender-123"
                                                                   scope:@"fcm"
                                                                 options:options
                                                              instanceID:@"instance-id"
                                                           installations:self.mockInstallations];

  XCTestExpectation *successExpectation = [self expectationWithDescription:@"Operation succeeded"];

  [operation addCompletionHandler:^(FIRMessagingTokenOperationResult result,
                                    NSString *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqual(result, FIRMessagingTokenOperationSucceeded);
    XCTAssertEqualObjects(token, @"fake-fid");
    XCTAssertNil(error);
    [successExpectation fulfill];
  }];

  NSHTTPURLResponse *response =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]
                                  statusCode:200
                                 HTTPVersion:@"HTTP/1.1"
                                headerFields:nil];

  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:response
                                    body:[@"{\"name\":\"projects/sender-123/registrations/"
                                          @"fake-fid\"}" dataUsingEncoding:NSUTF8StringEncoding]
                                   error:nil
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    return YES;
                  }];

  [operation start];

  [self waitForExpectationsWithTimeout:0.5 handler:nil];
}

- (void)testFailureStatusCode {
  NSDictionary *options = @{
    kFIRMessagingTokenOptionsAPNSKey : [@"fakeAPNSToken" dataUsingEncoding:NSUTF8StringEncoding],
    kFIRMessagingTokenOptionsAPNSIsSandboxKey : @NO
  };

  FIRInstallationsAuthTokenResult *mockTokenResult =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"fis-auth-token"
                                              expirationDate:[NSDate distantFuture]];

  id authTokenWithCompletionArg = [OCMArg invokeBlockWithArgs:mockTokenResult, [NSNull null], nil];
  OCMStub([self.mockInstallations authTokenWithCompletion:authTokenWithCompletionArg]);

  FIRMessagingFIDRegisterOperation *operation =
      [[FIRMessagingFIDRegisterOperation alloc] initWithAuthorizedEntity:@"sender-123"
                                                                   scope:@"fcm"
                                                                 options:options
                                                              instanceID:@"instance-id"
                                                           installations:self.mockInstallations];

  XCTestExpectation *failureExpectation = [self expectationWithDescription:@"Operation failed"];

  [operation addCompletionHandler:^(FIRMessagingTokenOperationResult result,
                                    NSString *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqual(result, FIRMessagingTokenOperationError);
    XCTAssertNil(token);
    XCTAssertNotNil(error);
    [failureExpectation fulfill];
  }];

  NSHTTPURLResponse *response =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]
                                  statusCode:400
                                 HTTPVersion:@"HTTP/1.1"
                                headerFields:nil];

  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:response
                                    body:[@"Bad Request" dataUsingEncoding:NSUTF8StringEncoding]
                                   error:nil
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    return YES;
                  }];

  [operation start];

  [self waitForExpectationsWithTimeout:0.5 handler:nil];
}

- (void)testInvalidJSONResponse {
  NSDictionary *options = @{
    kFIRMessagingTokenOptionsAPNSKey : [@"fakeAPNSToken" dataUsingEncoding:NSUTF8StringEncoding],
    kFIRMessagingTokenOptionsAPNSIsSandboxKey : @NO
  };

  FIRInstallationsAuthTokenResult *mockTokenResult =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"fis-auth-token"
                                              expirationDate:[NSDate distantFuture]];

  id authTokenWithCompletionArg = [OCMArg invokeBlockWithArgs:mockTokenResult, [NSNull null], nil];
  OCMStub([self.mockInstallations authTokenWithCompletion:authTokenWithCompletionArg]);

  FIRMessagingFIDRegisterOperation *operation =
      [[FIRMessagingFIDRegisterOperation alloc] initWithAuthorizedEntity:@"sender-123"
                                                                   scope:@"fcm"
                                                                 options:options
                                                              instanceID:@"instance-id"
                                                           installations:self.mockInstallations];

  XCTestExpectation *failureExpectation = [self expectationWithDescription:@"Operation failed"];

  [operation addCompletionHandler:^(FIRMessagingTokenOperationResult result,
                                    NSString *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqual(result, FIRMessagingTokenOperationError);
    XCTAssertNil(token);
    XCTAssertNotNil(error);
    [failureExpectation fulfill];
  }];

  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:nil
                                    body:[@"invalid json" dataUsingEncoding:NSUTF8StringEncoding]
                                   error:nil
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    return YES;
                  }];

  [operation start];

  [self waitForExpectationsWithTimeout:0.5 handler:nil];
}

- (void)testRetryOn5xx {
  NSDictionary *options = @{
    kFIRMessagingTokenOptionsAPNSKey : [@"fakeAPNSToken" dataUsingEncoding:NSUTF8StringEncoding],
    kFIRMessagingTokenOptionsAPNSIsSandboxKey : @NO
  };

  FIRInstallationsAuthTokenResult *mockTokenResult =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"fis-auth-token"
                                              expirationDate:[NSDate distantFuture]];

  id authTokenWithCompletionArg = [OCMArg invokeBlockWithArgs:mockTokenResult, [NSNull null], nil];
  OCMStub([self.mockInstallations authTokenWithCompletion:authTokenWithCompletionArg]);

  FIRMessagingFIDRegisterOperation *operation =
      [[FIRMessagingFIDRegisterOperation alloc] initWithAuthorizedEntity:@"sender-123"
                                                                   scope:@"fcm"
                                                                 options:options
                                                              instanceID:@"instance-id"
                                                           installations:self.mockInstallations];

  XCTestExpectation *retryExpectation =
      [self expectationWithDescription:@"Operation retried and succeeded"];

  // First call returns 500
  NSHTTPURLResponse *response500 = [FIRURLSessionOCMockStub HTTPResponseWithCode:500];
  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:response500
                                    body:[@"Internal Server Error"
                                             dataUsingEncoding:NSUTF8StringEncoding]
                                   error:nil
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    return YES;
                  }];

  // Second call returns 200
  NSHTTPURLResponse *response200 = [FIRURLSessionOCMockStub HTTPResponseWithCode:200];
  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:response200
                                    body:[@"{\"name\":\"projects/sender-123/registrations/"
                                          @"fake-fid\"}" dataUsingEncoding:NSUTF8StringEncoding]
                                   error:nil
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    return YES;
                  }];

  [operation addCompletionHandler:^(FIRMessagingTokenOperationResult result,
                                    NSString *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqual(result, FIRMessagingTokenOperationSucceeded);
    XCTAssertEqualObjects(token, @"fake-fid");
    XCTAssertNil(error);
    [retryExpectation fulfill];
  }];

  [operation start];

  [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testRetryOnNetworkFailure {
  NSDictionary *options = @{
    kFIRMessagingTokenOptionsAPNSKey : [@"fakeAPNSToken" dataUsingEncoding:NSUTF8StringEncoding],
    kFIRMessagingTokenOptionsAPNSIsSandboxKey : @NO
  };

  FIRInstallationsAuthTokenResult *mockTokenResult =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"fis-auth-token"
                                              expirationDate:[NSDate distantFuture]];

  id authTokenWithCompletionArg = [OCMArg invokeBlockWithArgs:mockTokenResult, [NSNull null], nil];
  OCMStub([self.mockInstallations authTokenWithCompletion:authTokenWithCompletionArg]);

  FIRMessagingFIDRegisterOperation *operation =
      [[FIRMessagingFIDRegisterOperation alloc] initWithAuthorizedEntity:@"sender-123"
                                                                   scope:@"fcm"
                                                                 options:options
                                                              instanceID:@"instance-id"
                                                           installations:self.mockInstallations];

  XCTestExpectation *retryExpectation =
      [self expectationWithDescription:@"Operation retried and succeeded after network failure"];

  // First call returns network error
  NSError *networkError = [NSError errorWithDomain:NSURLErrorDomain
                                              code:NSURLErrorNotConnectedToInternet
                                          userInfo:nil];
  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:nil
                                    body:nil
                                   error:networkError
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    return YES;
                  }];

  // Second call returns 200
  NSHTTPURLResponse *response200 = [FIRURLSessionOCMockStub HTTPResponseWithCode:200];
  [FIRURLSessionOCMockStub
      stubURLSessionDataTaskWithResponse:response200
                                    body:[@"{\"name\":\"projects/sender-123/registrations/"
                                          @"fake-fid\"}" dataUsingEncoding:NSUTF8StringEncoding]
                                   error:nil
                          URLSessionMock:self.URLSessionMock
                  requestValidationBlock:^BOOL(NSURLRequest *_Nonnull sentRequest) {
                    return YES;
                  }];

  [operation addCompletionHandler:^(FIRMessagingTokenOperationResult result,
                                    NSString *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqual(result, FIRMessagingTokenOperationSucceeded);
    XCTAssertEqualObjects(token, @"fake-fid");
    XCTAssertNil(error);
    [retryExpectation fulfill];
  }];

  [operation start];

  [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

@end
