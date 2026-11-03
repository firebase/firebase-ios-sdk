/*
 * Copyright 2019 Google
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

@import FirebaseAuth;

#import "FIRAuthApiTestsBase.h"

@interface AccountInfoTests : FIRAuthApiTestsBase
@end

@implementation AccountInfoTests {
  NSString *_oldUserEmail;
}

- (void)setUp {
  [super setUp];
  _oldUserEmail = [self fakeRandomEmail];
  XCTestExpectation *expectation = [self expectationWithDescription:@"setup old email expectation"];
  FIRAuth *auth = [FIRAuth auth];
  [auth createUserWithEmail:_oldUserEmail
                   password:@"password"
                 completion:^(FIRAuthDataResult *user, NSError *error) {
                   XCTAssertNil(error);
                   [expectation fulfill];
                 }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout handler:nil];
}

- (void)tearDown {
  if ([FIRAuth auth].currentUser) {
    [self deleteCurrentUser];
  }
  [super tearDown];
}

- (void)testUpdatingUsersEmailAlreadyInUse {
  SKIP_IF_ON_MOBILE_HARNESS
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Created account with email and password."];
  [auth createUserWithEmail:_oldUserEmail
                   password:@"password"
                 completion:^(FIRAuthDataResult *user, NSError *error) {
                   XCTAssertEqual(error.code, FIRAuthErrorCodeEmailAlreadyInUse);
                   [expectation fulfill];
                 }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout handler:nil];
}

@end
