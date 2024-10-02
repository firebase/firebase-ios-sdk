/*
 * Copyright 2017 Google
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
@import FirebaseAuth;

/** The testing email address for testCreateAccountWithEmailAndPassword. */
static NSString *const kNewEmailToCreateUser = @"user+email_new_user@example.com";

/** The testing email address for testSignInExistingUserWithEmailAndPassword. */
static NSString *const kExistingEmailToSignIn = @"user+email_existing_user@example.com";

/** The testing password for testSignInExistingUserWithEmailAndPassword. */
static NSString *const kExistingPasswordToSignIn = @"password";

@interface EmailPasswordAuthTests : FIRAuthApiTestsBase

@end

@implementation EmailPasswordAuthTests

- (void)testCreateAccountWithEmailAndPassword {
  SKIP_IF_ON_MOBILE_HARNESS
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Created account with email and password."];
  [auth createUserWithEmail:kNewEmailToCreateUser
                   password:@"password"
                 completion:^(FIRAuthDataResult *result, NSError *error) {
                   if (error) {
                     NSLog(@"createUserWithEmail has error: %@", error);
                   }
                   [expectation fulfill];
                 }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in creating account. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];

  XCTAssertEqualObjects(auth.currentUser.email, kNewEmailToCreateUser);

  [self deleteCurrentUser];
}

- (void)testSignInExistingUserWithEmailAndPassword {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Signed in existing account with email and password."];
  [auth signInWithEmail:kExistingEmailToSignIn
               password:kExistingPasswordToSignIn
             completion:^(FIRAuthDataResult *user, NSError *error) {
               if (error) {
                 NSLog(@"Signing in existing account has error: %@", error);
               }
               [expectation fulfill];
             }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in signing in existing account. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];

  XCTAssertEqualObjects(auth.currentUser.email, kExistingEmailToSignIn);
}

@end
