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

#import "FIRAuthInteropFake.h"
#import "Functions/FirebaseFunctions/FUNContext.h"
#import "SharedTestUtilities/FIRMessagingInteropFake.h"

@interface FUNContextProviderTests : XCTestCase
@property(nonatomic) FIRMessagingInteropFake *messagingFake;
@end

@implementation FUNContextProviderTests

- (void)setUp {
  self.messagingFake = [[FIRMessagingInteropFake alloc] init];
}

- (void)testContextWithAuth {
  FIRAuthInteropFake *auth = [[FIRAuthInteropFake alloc] initWithToken:@"token"
                                                                userID:@"userID"
                                                                 error:nil];
  FUNContextProvider *provider = [[FUNContextProvider alloc] initWithAuth:(id<FIRAuthInterop>)auth
                                                                messaging:self.messagingFake];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Context should have auth keys."];
  [provider getContext:^(FUNContext *_Nullable context, NSError *_Nullable error) {
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
                                                                messaging:self.messagingFake];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Completion handler should fail with Auth error."];
  [provider getContext:^(FUNContext *_Nullable context, NSError *_Nullable error) {
    XCTAssertNil(context);
    XCTAssertEqual(error, auth.error);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:0.1];
}

- (void)testContextWithoutAuth {
  FUNContextProvider *provider = [[FUNContextProvider alloc] initWithAuth:nil messaging:nil];
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Completion handler should succeed without Auth."];
  [provider getContext:^(FUNContext *_Nullable context, NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertNil(context.authToken);
    XCTAssertNil(context.FCMToken);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:0.1];
}

@end
