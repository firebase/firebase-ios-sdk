//
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
//
// FIRAppDistributionAuthPersistenceTests.m
// FirebaseAppDistribution
//
// Created by Cleo Schneider on 4/17/20.

#import <Foundation/Foundation.h>
#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FIRAppDistributionAuthPersistence+Private.h"

@interface FIRAppDistributionAuthPersistenceTests : XCTestCase
@end

static NSString *const kTestCode = @"ThisCode";

static NSString *const kTestVerifier = @"ThisVerifier";

static NSString *const kTestState = @"ThisState";

static NSString *const kTestAccessToken = @"ThisToken";

static long const kTestExpirationSeconds = 45;

static NSString *const kTestIdToken = @"ThisIdToken";

static NSString *const kTestTokenType = @"ThisTokenType";

static NSString *const kTestScope = @"ThisScope";

@implementation FIRAppDistributionAuthPersistenceTests {
  /** @var _mockAuthState
      @brief The mock OIDAuthState  instance
   */
  OIDAuthState *_mockAuthState;
}

- (void)setUp {
  [super setUp];
  OIDAuthorizationRequest *mockAuthorizationRequest = OCMClassMock([OIDAuthorizationRequest class]);
  OIDAuthorizationResponse *testAuthorizationResponse =
      [[OIDAuthorizationResponse alloc] initWithRequest:mockAuthorizationRequest
                                             parameters:@{
                                               @"code" : @"AuthCode",
                                               @"code_verifier" : @"AuthVerifier",
                                               @"state" : @"AuthState",
                                               @"access_token" : @"AuthToken",
                                               @"expires_in" : @(45),
                                               @"id_token" : @"AuthIdToken",
                                               @"token_type" : @"AuthTokenType",
                                               @"scope" : "AuthScope"
                                             }];
  OIDTokenRequest *mockTokenRequest = OCMClassMock([OIDTokenRequest class]);
  OIDTokenResponse *testTokenResponse =
      [[OIDTokenResponse alloc] initWithRequest:mockTokenRequest
                                     parameters:@{
                                       @"access_token" : @"TokenToken",
                                       @"expires_in" : @(45),
                                       @"id_token" : @"TokenIdToken",
                                       @"refresh_token" : @"TokenRefreshToken",
                                       @"scope" : @"TokenScope"
                                     }];

  _mockAuthState = [[OIDAuthState alloc] initWithAuthorizationResponse:testAuthorizationResponse
                                                         tokenResponse:testTokenResponse]
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
  [super tearDown];
}

- (void)testPersistAuthState {
  NSError *error;
  BOOL success = [FIRAppDistributionAuthPersistence persistAuthState:_mockAuthState error:&error];
  XCTAssertTrue(success);
}

@end
