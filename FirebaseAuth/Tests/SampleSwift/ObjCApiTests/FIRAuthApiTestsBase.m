/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FIRAuthApiTestsBase.h"
@import FirebaseAuth;

@implementation FIRAuthApiTestsBase

- (void)setUp {
  [super setUp];

  [self signOut];
}

- (void)tearDown {
  [super tearDown];
}

- (void)signInAnonymously {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }

  XCTestExpectation *expectation = [self expectationWithDescription:@"Anonymous sign-in finished."];
  [auth signInAnonymouslyWithCompletion:^(FIRAuthDataResult *result, NSError *error) {
    if (error) {
      NSLog(@"Anonymous sign in error: %@", error);
    }
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in anonymously sign in. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];
}

- (void)signOut {
  NSError *signOutError;
  BOOL status = [[FIRAuth auth] signOut:&signOutError];

  // Just log the error because we don't want to fail the test if signing out
  // fails.
  if (!status) {
    NSLog(@"Error signing out: %@", signOutError);
  }
}

- (void)deleteCurrentUser {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    NSLog(@"Could not obtain auth object.");
  }

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Delete current user finished."];
  [auth.currentUser deleteWithCompletion:^(NSError *_Nullable error) {
    if (error) {
      XCTFail(@"Failed to delete user. Error: %@.", error);
    }
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in deleting user. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];
}

- (NSString *)fakeRandomEmail {
  NSMutableString *fakeEmail = [[NSMutableString alloc] init];
  for (int i = 0; i < 10; i++) {
    [fakeEmail
        appendString:[NSString stringWithFormat:@"%c", 'a' + arc4random_uniform('z' - 'a' + 1)]];
  }
  [fakeEmail appendString:@"@gmail.com"];
  return fakeEmail;
}

@end
