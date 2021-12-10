// Copyright 2019 Google
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

#import <XCTest/XCTest.h>

#import "FirebaseFunctions/Sources/FUNContext.h"

#import "SharedTestUtilities/AppCheckFake/FIRAppCheckFake.h"
#import "SharedTestUtilities/AppCheckFake/FIRAppCheckTokenResultFake.h"
#import "SharedTestUtilities/FIRAuthInteropFake.h"
#import "SharedTestUtilities/FIRMessagingInteropFake.h"

@interface FUNContextProviderTests : XCTestCase

@property(nonatomic) FIRMessagingInteropFake *messagingFake;

@property(nonatomic) FIRAppCheckFake *appCheckFake;
@property(strong, nonatomic) FIRAppCheckTokenResultFake *appCheckTokenSuccess;
@property(strong, nonatomic) FIRAppCheckTokenResultFake *appCheckTokenError;

@end

@implementation FUNContextProviderTests

- (void)setUp {
  self.messagingFake = [[FIRMessagingInteropFake alloc] init];
  self.appCheckFake = [[FIRAppCheckFake alloc] init];

  self.appCheckTokenSuccess = [[FIRAppCheckTokenResultFake alloc] initWithToken:@"valid_token"
                                                                          error:nil];
  self.appCheckTokenError = [[FIRAppCheckTokenResultFake alloc]
      initWithToken:@"dummy token"
              error:[NSError errorWithDomain:@"testAppCheckError" code:-1 userInfo:nil]];
}

- (void)testContextWithAuth {
  FIRAuthInteropFake *auth = [[FIRAuthInteropFake alloc] initWithToken:@"token"
                                                                userID:@"userID"
                                                                 error:nil];
  FUNContextProvider *provider = [[FUNContextProvider alloc] initWithAuth:(id<FIRAuthInterop>)auth
                                                                messaging:self.messagingFake
                                                                 appCheck:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Context should have auth keys."];
  [provider getContext:^(FUNContext *context, NSError *_Nullable error) {
    XCTAssertNotNil(context);
    XCTAssert([context.authToken isEqualToString:@"token"]);
    XCTAssert([context.FCMToken isEqualToString:self.messagingFake.FCMToken]);
    XCTAssertNil(error);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:0.1];
}

- (void)testContextWithAuthError {
  NSError *authError = [[NSError alloc] initWithDomain:@"com.functions.tests" code:4 userInfo:nil];
  FIRAuthInteropFake *auth = [[FIRAuthInteropFake alloc] initWithToken:nil
                                                                userID:nil
                                                                 error:authError];
  FUNContextProvider *provider = [[FUNContextProvider alloc] initWithAuth:(id<FIRAuthInterop>)auth
                                                                messaging:self.messagingFake
                                                                 appCheck:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Completion handler should fail with Auth error."];
  [provider getContext:^(FUNContext *context, NSError *_Nullable error) {
    XCTAssertNotNil(context);
    XCTAssertNil(context.authToken);
    XCTAssertEqual(error, auth.error);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:0.1];
}

- (void)testContextWithoutAuth {
  FUNContextProvider *provider = [[FUNContextProvider alloc] initWithAuth:nil
                                                                messaging:nil
                                                                 appCheck:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Completion handler should succeed without Auth."];
  [provider getContext:^(FUNContext *context, NSError *_Nullable error) {
    XCTAssertNotNil(context);
    XCTAssertNil(error);
    XCTAssertNil(context.authToken);
    XCTAssertNil(context.FCMToken);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:0.1];
}

- (void)testContextWithAppCheckOnlySuccess {
  self.appCheckFake.tokenResult = self.appCheckTokenSuccess;
  FUNContextProvider *provider = [[FUNContextProvider alloc] initWithAuth:nil
                                                                messaging:nil
                                                                 appCheck:self.appCheckFake];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Completion handler should succeed without Auth."];
  [provider getContext:^(FUNContext *context, NSError *_Nullable error) {
    XCTAssertNotNil(context);
    XCTAssertNil(error);
    XCTAssertNil(context.authToken);
    XCTAssertNil(context.FCMToken);
    XCTAssertEqualObjects(context.appCheckToken, self.appCheckTokenSuccess.token);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:0.1];
}

- (void)testContextWithAppCheckOnlyError {
  self.appCheckFake.tokenResult = self.appCheckTokenError;
  FUNContextProvider *provider = [[FUNContextProvider alloc] initWithAuth:nil
                                                                messaging:nil
                                                                 appCheck:self.appCheckFake];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Completion handler should succeed without Auth."];
  [provider getContext:^(FUNContext *context, NSError *_Nullable error) {
    XCTAssertNotNil(context);
    XCTAssertNil(error);
    XCTAssertNil(context.authToken);
    XCTAssertNil(context.FCMToken);
    // Don't expect any token in the case of App Check error.
    XCTAssertNil(context.appCheckToken);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:0.1];
}

- (void)testAllContextsAvailableSuccess {
  self.appCheckFake.tokenResult = self.appCheckTokenSuccess;
  FIRAuthInteropFake *auth = [[FIRAuthInteropFake alloc] initWithToken:@"token"
                                                                userID:@"userID"
                                                                 error:nil];
  FUNContextProvider *provider = [[FUNContextProvider alloc] initWithAuth:auth
                                                                messaging:self.messagingFake
                                                                 appCheck:self.appCheckFake];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Completion handler should succeed without Auth."];
  [provider getContext:^(FUNContext *context, NSError *_Nullable error) {
    XCTAssertNotNil(context);
    XCTAssertNil(error);
    XCTAssert([context.authToken isEqualToString:@"token"]);
    XCTAssert([context.FCMToken isEqualToString:self.messagingFake.FCMToken]);
    XCTAssertEqualObjects(context.appCheckToken, self.appCheckTokenSuccess.token);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:0.1];
}

- (void)testAllContextsAuthAndAppCheckError {
  self.appCheckFake.tokenResult = self.appCheckTokenError;

  NSError *authError = [[NSError alloc] initWithDomain:@"com.functions.tests" code:4 userInfo:nil];
  FIRAuthInteropFake *auth = [[FIRAuthInteropFake alloc] initWithToken:nil
                                                                userID:nil
                                                                 error:authError];

  FUNContextProvider *provider = [[FUNContextProvider alloc] initWithAuth:auth
                                                                messaging:self.messagingFake
                                                                 appCheck:self.appCheckFake];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Completion handler should succeed without Auth."];
  [provider getContext:^(FUNContext *context, NSError *_Nullable error) {
    XCTAssertNotNil(context);
    XCTAssertEqual(error, auth.error);

    XCTAssertNil(context.authToken);
    XCTAssert([context.FCMToken isEqualToString:self.messagingFake.FCMToken]);
    // Don't expect any token in the case of App Check error.
    XCTAssertNil(context.appCheckToken);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:0.1];
}

@end
