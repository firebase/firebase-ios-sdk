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

// macOS requests a user password when accessing the Keychain for the first time,
// so the tests may fail. Disable integration tests on macOS so far.
// TODO: Configure the tests to run on macOS without requesting the keychain password.
#if !TARGET_OS_OSX

#import <XCTest/XCTest.h>

#import <FirebaseCore/FirebaseCore.h>
#import "Firebase/InstanceID/Public/FirebaseInstanceID.h"

static BOOL sFIRInstanceIDFirebaseDefaultAppConfigured = NO;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@interface FIRInstanceIDIntegrationTests : XCTestCase
@property(nonatomic, strong) FIRInstanceID *instanceID;
@end

@implementation FIRInstanceIDIntegrationTests

- (void)setUp {
  [self configureFirebaseDefaultAppIfCan];

  if (![self isDefaultAppConfigured]) {
    return;
  }

  self.instanceID = [FIRInstanceID instanceID];
}

- (void)tearDown {
  self.instanceID = nil;
}

- (void)testGetID {
  if (![self isDefaultAppConfigured]) {
    return;
  }

  XCTestExpectation *expectation = [self expectationWithDescription:@"getID"];
  [self.instanceID getIDWithHandler:^(NSString *_Nullable identity, NSError *_Nullable error) {
    XCTAssertNil(error);
    XCTAssertEqual(identity.length, 22);
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:5];
}

- (void)testInstanceIDWithHandler {
  if (![self isDefaultAppConfigured]) {
    return;
  }

  XCTestExpectation *expectation = [self expectationWithDescription:@"instanceIDWithHandler"];
  [self.instanceID
      instanceIDWithHandler:^(FIRInstanceIDResult *_Nullable result, NSError *_Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssert(result.instanceID.length > 0);
        XCTAssert(result.token.length > 0);
        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5];
}

- (void)testTokenWithAuthorizedEntity {
  if (![self isDefaultAppConfigured]) {
    return;
  }

  [self assertTokenWithAuthorizedEntity];
}

- (void)testDeleteToken {
  if (![self isDefaultAppConfigured]) {
    return;
  }

  [self assertTokenWithAuthorizedEntity];

  XCTestExpectation *expectation = [self expectationWithDescription:@"testDeleteToken"];
  [self.instanceID deleteTokenWithAuthorizedEntity:[self tokenAuthorizedEntity]
                                             scope:@"*"
                                           handler:^(NSError *_Nonnull error) {
                                             XCTAssertNil(error);
                                             [expectation fulfill];
                                           }];

  [self waitForExpectations:@[ expectation ] timeout:5];
}

- (void)testDeleteID {
  if (![self isDefaultAppConfigured]) {
    return;
  }

  XCTestExpectation *expectation = [self expectationWithDescription:@"deleteID"];
  [self.instanceID deleteIDWithHandler:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];

  [self waitForExpectations:@[ expectation ] timeout:5];
}

#pragma mark - Helpers

- (void)assertTokenWithAuthorizedEntity {
  XCTestExpectation *expectation = [self expectationWithDescription:@"tokenWithAuthorizedEntity"];
  [self.instanceID
      tokenWithAuthorizedEntity:[self tokenAuthorizedEntity]
                          scope:@"*"
                        options:nil
                        handler:^(NSString *_Nullable token, NSError *_Nullable error) {
                          XCTAssertNil(error);
                          XCTAssert(token > 0);
                          [expectation fulfill];
                        }];

  [self waitForExpectations:@[ expectation ] timeout:5];
}
#pragma clang diagnostic pop

- (NSString *)tokenAuthorizedEntity {
  if (!sFIRInstanceIDFirebaseDefaultAppConfigured) {
    return @"";
  }

  return [FIRApp defaultApp].options.GCMSenderID;
}

- (void)configureFirebaseDefaultAppIfCan {
  if (sFIRInstanceIDFirebaseDefaultAppConfigured) {
    return;
  }

  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *plistPath = [bundle pathForResource:@"GoogleService-Info" ofType:@"plist"];
  if (plistPath == nil) {
    return;
  }

  FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:plistPath];
  [FIRApp configureWithOptions:options];
  sFIRInstanceIDFirebaseDefaultAppConfigured = YES;
}

- (BOOL)isDefaultAppConfigured {
  if (!sFIRInstanceIDFirebaseDefaultAppConfigured) {
// Fail tests requiring GoogleService-Info.plist only if it is required.
#if FIR_IID_INTEGRATION_TESTS_REQUIRED
    XCTFail(@"GoogleService-Info.plist for integration tests was not found. Please add the file to "
            @"your project.");
#else
    NSLog(@"GoogleService-Info.plist for integration tests was not found. Skipping the test %@",
          self.name);
#endif  // FIR_IID_INTEGRATION_TESTS_REQUIRED
  }

  return sFIRInstanceIDFirebaseDefaultAppConfigured;
}

@end

#endif  // !TARGET_OS_OSX
