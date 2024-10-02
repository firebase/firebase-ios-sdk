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

/** The user name string for Custom Auth testing account. */
static NSString *const kCustomAuthTestingAccountUserID = KCUSTOM_AUTH_USER_ID;

/** The url for obtaining a valid custom token string used to test Custom Auth. */
static NSString *const kCustomTokenUrl = KCUSTOM_AUTH_TOKEN_URL;

/** The url for obtaining an expired but valid custom token string used to test Custom Auth failure.
 */
static NSString *const kExpiredCustomTokenUrl = KCUSTOM_AUTH_TOKEN_EXPIRED_URL;

/** The invalid custom token string for testing Custom Auth. */
static NSString *const kInvalidCustomToken = @"invalid token.";

/** Error message for invalid custom token sign in. */
NSString *kInvalidTokenErrorMessage =
    @"Invalid assertion format. 3 dot separated segments required.";

@interface CustomAuthTests : FIRAuthApiTestsBase

@end

@implementation CustomAuthTests

- (void)DISABLE_testSignInWithValidCustomAuthToken {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }

  NSError *error;
  NSString *customToken = [NSString stringWithContentsOfURL:[NSURL URLWithString:kCustomTokenUrl]
                                                   encoding:NSUTF8StringEncoding
                                                      error:&error];
  if (!customToken) {
    XCTFail(@"There was an error retrieving the custom token: %@", error);
  }
  NSLog(@"The valid token is: %@", customToken);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"CustomAuthToken sign-in finished."];

  [auth signInWithCustomToken:customToken
                   completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
                     if (error) {
                       NSLog(@"Valid token sign in error: %@", error);
                     }
                     [expectation fulfill];
                   }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in CustomAuthToken sign in. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];

  XCTAssertEqualObjects(auth.currentUser.uid, kCustomAuthTestingAccountUserID);
}

- (void)DISABLE_testSignInWithValidCustomAuthExpiredToken {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }

  NSError *error;
  NSString *customToken =
      [NSString stringWithContentsOfURL:[NSURL URLWithString:kExpiredCustomTokenUrl]
                               encoding:NSUTF8StringEncoding
                                  error:&error];
  if (!customToken) {
    XCTFail(@"There was an error retrieving the custom token: %@", error);
  }
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"CustomAuthToken sign-in finished."];

  __block NSError *apiError;
  [auth signInWithCustomToken:customToken
                   completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
                     if (error) {
                       apiError = error;
                     }
                     [expectation fulfill];
                   }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in CustomAuthToken sign in. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];

  XCTAssertNil(auth.currentUser);
  XCTAssertEqual(apiError.code, FIRAuthErrorCodeInvalidCustomToken);
}

- (void)DISABLE_testSignInWithInvalidCustomAuthToken {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Invalid CustomAuthToken sign-in finished."];

  [auth signInWithCustomToken:kInvalidCustomToken
                   completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
                     XCTAssertEqualObjects(error.localizedDescription, kInvalidTokenErrorMessage);
                     [expectation fulfill];
                   }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in CustomAuthToken sign in. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];
}

- (void)DISABLE_testInMemoryUserAfterSignOut {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }
  NSError *error;
  NSString *customToken = [NSString stringWithContentsOfURL:[NSURL URLWithString:kCustomTokenUrl]
                                                   encoding:NSUTF8StringEncoding
                                                      error:&error];
  if (!customToken) {
    XCTFail(@"There was an error retrieving the custom token: %@", error);
  }
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"CustomAuthToken sign-in finished."];
  __block NSError *rpcError;
  [auth signInWithCustomToken:customToken
                   completion:^(FIRAuthDataResult *_Nullable result, NSError *_Nullable error) {
                     if (error) {
                       rpcError = error;
                     }
                     [expectation fulfill];
                   }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in CustomAuthToken sign in. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];
  XCTAssertEqualObjects(auth.currentUser.uid, kCustomAuthTestingAccountUserID);
  XCTAssertNil(rpcError);
  FIRUser *inMemoryUser = auth.currentUser;
  XCTestExpectation *expectation1 = [self expectationWithDescription:@"Profile data change."];
  [auth signOut:NULL];
  rpcError = nil;
  NSString *newEmailAddress = [self fakeRandomEmail];
  XCTAssertNotEqualObjects(newEmailAddress, inMemoryUser.email);
  [inMemoryUser updateEmail:newEmailAddress
                 completion:^(NSError *_Nullable error) {
                   rpcError = error;
                   [expectation1 fulfill];
                 }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout handler:nil];
  XCTAssertEqualObjects(inMemoryUser.email, newEmailAddress);
  XCTAssertNil(rpcError);
  XCTAssertNil(auth.currentUser);
}

@end
