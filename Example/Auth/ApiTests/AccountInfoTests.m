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

#import "FIRAuthApiTestsBase.h"

/** The testing email address for testCreateAccountWithEmailAndPassword. */
static NSString *const kOldUserEmail = @"olduseremail@iosapitests.com";

/** The testing email address for testUpdatingUsersEmail. */
static NSString *const kNewUserEmail = @"newuseremail@iosapitests.com";

@interface AccountInfoTests : FIRAuthApiTestsBase

@end

@implementation AccountInfoTests

- (void)DISABLED_testUpdatingUsersEmail {
  SKIP_IF_ON_MOBILE_HARNESS
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }

  __block NSError *apiError;
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Created account with email and password."];
  [auth createUserWithEmail:kOldUserEmail
                   password:@"password"
                 completion:^(FIRAuthDataResult *user, NSError *error) {
                   apiError = error;
                   [expectation fulfill];
                 }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout handler:nil];
  expectation = [self expectationWithDescription:@"Created account with email and password."];
  XCTAssertEqualObjects(auth.currentUser.email, kOldUserEmail);
  XCTAssertNil(apiError);

  [auth.currentUser updateEmail:kNewUserEmail
                     completion:^(NSError *_Nullable error) {
                       apiError = error;
                       [expectation fulfill];
                     }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout handler:nil];
  XCTAssertNil(apiError);
  XCTAssertEqualObjects(auth.currentUser.email, kNewUserEmail);

  // Clean up the created Firebase user for future runs.
  [self deleteCurrentUser];
}

@end
