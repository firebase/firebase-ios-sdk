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

#import <TargetConditionals.h>
#if !TARGET_OS_OSX

#import <XCTest/XCTest.h>
#import "OCMock.h"

#import "FirebaseAuth/Sources/Storage/FIRAuthKeychainServices.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAppCredential.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAppCredentialManager.h"

#define ANY_ERROR_POINTER ((NSError * __autoreleasing * _Nullable)[OCMArg anyPointer])
#define SAVE_TO(var)                     \
  [OCMArg checkWithBlock:^BOOL(id arg) { \
    var = arg;                           \
    return YES;                          \
  }]

/** @var kReceipt
    @brief A fake receipt used for testing.
 */
static NSString *const kReceipt = @"FAKE_RECEIPT";

/** @var kAnotherReceipt
    @brief Another fake receipt used for testing.
 */
static NSString *const kAnotherReceipt = @"OTHER_RECEIPT";

/** @var kSecret
    @brief A fake secret used for testing.
 */
static NSString *const kSecret = @"FAKE_SECRET";

/** @var kAnotherSecret
    @brief Another fake secret used for testing.
 */
static NSString *const kAnotherSecret = @"OTHER_SECRET";

/** @var kVerificationTimeout
    @brief The verification timeout used for testing.
 */
static const NSTimeInterval kVerificationTimeout = 1;

/** @var kExpectationTimeout
    @brief The test expectation timeout.
    @remarks This must be considerably greater than @c kVerificationTimeout .
 */
static const NSTimeInterval kExpectationTimeout = 2;

NS_ASSUME_NONNULL_BEGIN

/** @class FIRAuthAppCredentialManagerTests
    @brief Unit tests for @c FIRAuthAppCredentialManager .
 */
@interface FIRAuthAppCredentialManagerTests : XCTestCase
@end
@implementation FIRAuthAppCredentialManagerTests {
  /** @var _mockKeychain
      @brief The mock keychain for testing.
   */
  id _mockKeychain;
}

- (void)setUp {
  _mockKeychain = OCMClassMock([FIRAuthKeychainServices class]);
}

/** @fn testCompletion
    @brief Tests a successfully completed verification flow.
 */
- (void)testCompletion {
  // Initial empty state.
  OCMExpect([_mockKeychain dataForKey:OCMOCK_ANY error:ANY_ERROR_POINTER]).andReturn(nil);
  FIRAuthAppCredentialManager *manager =
      [[FIRAuthAppCredentialManager alloc] initWithKeychain:_mockKeychain];
  XCTAssertNil(manager.credential);
  OCMVerifyAll(_mockKeychain);

  // Start verification.
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  OCMExpect([_mockKeychain setData:OCMOCK_ANY forKey:OCMOCK_ANY error:ANY_ERROR_POINTER])
      .andReturn(YES);
  [manager didStartVerificationWithReceipt:kReceipt
                                   timeout:kVerificationTimeout
                                  callback:^(FIRAuthAppCredential *credential) {
                                    XCTAssertEqualObjects(credential.receipt, kReceipt);
                                    XCTAssertEqualObjects(credential.secret, kSecret);
                                    [expectation fulfill];
                                  }];
  XCTAssertNil(manager.credential);
  OCMVerifyAll(_mockKeychain);

  // Mismatched receipt shouldn't finish verification.
  XCTAssertFalse([manager canFinishVerificationWithReceipt:kAnotherReceipt secret:kAnotherSecret]);
  XCTAssertNil(manager.credential);

  // Finish verification.
  OCMExpect([_mockKeychain setData:OCMOCK_ANY forKey:OCMOCK_ANY error:ANY_ERROR_POINTER])
      .andReturn(YES);
  XCTAssertTrue([manager canFinishVerificationWithReceipt:kReceipt secret:kSecret]);
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNotNil(manager.credential);
  XCTAssertEqualObjects(manager.credential.receipt, kReceipt);
  XCTAssertEqualObjects(manager.credential.secret, kSecret);
  OCMVerifyAll(_mockKeychain);

  // Repeated receipt should have no effect.
  XCTAssertFalse([manager canFinishVerificationWithReceipt:kReceipt secret:kAnotherSecret]);
  XCTAssertEqualObjects(manager.credential.secret, kSecret);
}

/** @fn testTimeout
    @brief Tests a verification flow that times out.
 */
- (void)testTimeout {
  // Initial empty state.
  OCMExpect([_mockKeychain dataForKey:OCMOCK_ANY error:ANY_ERROR_POINTER]).andReturn(nil);
  FIRAuthAppCredentialManager *manager =
      [[FIRAuthAppCredentialManager alloc] initWithKeychain:_mockKeychain];
  XCTAssertNil(manager.credential);
  OCMVerifyAll(_mockKeychain);

  // Start verification.
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  OCMExpect([_mockKeychain setData:OCMOCK_ANY forKey:OCMOCK_ANY error:ANY_ERROR_POINTER])
      .andReturn(YES);
  [manager didStartVerificationWithReceipt:kReceipt
                                   timeout:kVerificationTimeout
                                  callback:^(FIRAuthAppCredential *credential) {
                                    XCTAssertEqualObjects(credential.receipt, kReceipt);
                                    XCTAssertNil(credential.secret);
                                    [expectation fulfill];
                                  }];
  XCTAssertNil(manager.credential);
  OCMVerifyAll(_mockKeychain);

  // Time-out.
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNil(manager.credential);

  // Completion after timeout.
  OCMExpect([_mockKeychain setData:OCMOCK_ANY forKey:OCMOCK_ANY error:ANY_ERROR_POINTER])
      .andReturn(YES);
  XCTAssertTrue([manager canFinishVerificationWithReceipt:kReceipt secret:kSecret]);
  XCTAssertNotNil(manager.credential);
  XCTAssertEqualObjects(manager.credential.receipt, kReceipt);
  XCTAssertEqualObjects(manager.credential.secret, kSecret);
  OCMVerifyAll(_mockKeychain);
}

/** @fn testMaximumPendingReceipt
    @brief Tests the maximum allowed number of pending receipt.
 */
- (void)testMaximumPendingReceipt {
  // Initial empty state.
  OCMExpect([_mockKeychain dataForKey:OCMOCK_ANY error:ANY_ERROR_POINTER]).andReturn(nil);
  FIRAuthAppCredentialManager *manager =
      [[FIRAuthAppCredentialManager alloc] initWithKeychain:_mockKeychain];
  XCTAssertNil(manager.credential);
  OCMVerifyAll(_mockKeychain);

  // Start verification of the target receipt.
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  OCMExpect([_mockKeychain setData:OCMOCK_ANY forKey:OCMOCK_ANY error:ANY_ERROR_POINTER])
      .andReturn(YES);
  [manager didStartVerificationWithReceipt:kReceipt
                                   timeout:kVerificationTimeout
                                  callback:^(FIRAuthAppCredential *credential) {
                                    XCTAssertEqualObjects(credential.receipt, kReceipt);
                                    XCTAssertEqualObjects(credential.secret, kSecret);
                                    [expectation fulfill];
                                  }];
  XCTAssertNil(manager.credential);
  OCMVerifyAll(_mockKeychain);

  // Start verification of a number of random receipts without overflowing.
  for (NSUInteger i = 1; i < manager.maximumNumberOfPendingReceipts; i++) {
    OCMExpect([_mockKeychain setData:OCMOCK_ANY forKey:OCMOCK_ANY error:ANY_ERROR_POINTER])
        .andReturn(YES);
    NSString *randomReceipt = [NSString stringWithFormat:@"RANDOM_%lu", (unsigned long)i];
    XCTestExpectation *randomExpectation = [self expectationWithDescription:randomReceipt];
    [manager didStartVerificationWithReceipt:randomReceipt
                                     timeout:kVerificationTimeout
                                    callback:^(FIRAuthAppCredential *credential) {
                                      // They all should get full credential because one is
                                      // available at this point.
                                      XCTAssertEqualObjects(credential.receipt, kReceipt);
                                      XCTAssertEqualObjects(credential.secret, kSecret);
                                      [randomExpectation fulfill];
                                    }];
  }

  // Finish verification of target receipt.
  OCMExpect([_mockKeychain setData:OCMOCK_ANY forKey:OCMOCK_ANY error:ANY_ERROR_POINTER])
      .andReturn(YES);
  XCTAssertTrue([manager canFinishVerificationWithReceipt:kReceipt secret:kSecret]);
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNotNil(manager.credential);
  XCTAssertEqualObjects(manager.credential.receipt, kReceipt);
  XCTAssertEqualObjects(manager.credential.secret, kSecret);
  OCMVerifyAll(_mockKeychain);

  // Clear credential to prepare for next round.
  [manager clearCredential];
  XCTAssertNil(manager.credential);

  // Start verification of another target receipt.
  expectation = [self expectationWithDescription:@"another callback"];
  OCMExpect([_mockKeychain setData:OCMOCK_ANY forKey:OCMOCK_ANY error:ANY_ERROR_POINTER])
      .andReturn(YES);
  [manager didStartVerificationWithReceipt:kAnotherReceipt
                                   timeout:kVerificationTimeout
                                  callback:^(FIRAuthAppCredential *credential) {
                                    XCTAssertEqualObjects(credential.receipt, kAnotherReceipt);
                                    XCTAssertNil(credential.secret);
                                    [expectation fulfill];
                                  }];
  XCTAssertNil(manager.credential);
  OCMVerifyAll(_mockKeychain);

  // Start verification of a number of random receipts to overflow.
  for (NSUInteger i = 0; i < manager.maximumNumberOfPendingReceipts; i++) {
    OCMExpect([_mockKeychain setData:OCMOCK_ANY forKey:OCMOCK_ANY error:ANY_ERROR_POINTER])
        .andReturn(YES);
    NSString *randomReceipt = [NSString stringWithFormat:@"RANDOM_%lu", (unsigned long)i];
    XCTestExpectation *randomExpectation = [self expectationWithDescription:randomReceipt];
    [manager didStartVerificationWithReceipt:randomReceipt
                                     timeout:kVerificationTimeout
                                    callback:^(FIRAuthAppCredential *credential) {
                                      // They all should get partial credential because verification
                                      // has never completed.
                                      XCTAssertEqualObjects(credential.receipt, randomReceipt);
                                      XCTAssertNil(credential.secret);
                                      [randomExpectation fulfill];
                                    }];
  }

  // Finish verification of the other target receipt.
  XCTAssertFalse([manager canFinishVerificationWithReceipt:kAnotherReceipt secret:kAnotherSecret]);
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNil(manager.credential);
}

/** @fn testKeychain
    @brief Tests state preservation in the keychain.
 */
- (void)testKeychain {
  // Initial empty state.
  OCMExpect([_mockKeychain dataForKey:OCMOCK_ANY error:ANY_ERROR_POINTER]).andReturn(nil);
  FIRAuthAppCredentialManager *manager =
      [[FIRAuthAppCredentialManager alloc] initWithKeychain:_mockKeychain];
  XCTAssertNil(manager.credential);
  OCMVerifyAll(_mockKeychain);

  // Start verification.
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  __block NSString *key;
  __block NSString *data;
  OCMExpect([_mockKeychain setData:SAVE_TO(data) forKey:SAVE_TO(key) error:ANY_ERROR_POINTER])
      .andReturn(YES);
  [manager didStartVerificationWithReceipt:kReceipt
                                   timeout:kVerificationTimeout
                                  callback:^(FIRAuthAppCredential *credential) {
                                    XCTAssertEqualObjects(credential.receipt, kReceipt);
                                    XCTAssertNil(credential.secret);
                                    [expectation fulfill];
                                  }];
  XCTAssertNil(manager.credential);
  OCMVerifyAll(_mockKeychain);

  // Time-out.
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  XCTAssertNil(manager.credential);

  // Start a new manager with saved data in keychain.
  OCMExpect([_mockKeychain dataForKey:key error:ANY_ERROR_POINTER]).andReturn(data);
  manager = [[FIRAuthAppCredentialManager alloc] initWithKeychain:_mockKeychain];
  XCTAssertNil(manager.credential);
  OCMVerifyAll(_mockKeychain);

  // Finish verification.
  OCMExpect([_mockKeychain setData:SAVE_TO(data) forKey:SAVE_TO(key) error:ANY_ERROR_POINTER])
      .andReturn(YES);
  XCTAssertTrue([manager canFinishVerificationWithReceipt:kReceipt secret:kSecret]);
  XCTAssertNotNil(manager.credential);
  XCTAssertEqualObjects(manager.credential.receipt, kReceipt);
  XCTAssertEqualObjects(manager.credential.secret, kSecret);
  OCMVerifyAll(_mockKeychain);

  // Start yet another new manager with saved data in keychain.
  OCMExpect([_mockKeychain dataForKey:key error:ANY_ERROR_POINTER]).andReturn(data);
  manager = [[FIRAuthAppCredentialManager alloc] initWithKeychain:_mockKeychain];
  XCTAssertNotNil(manager.credential);
  XCTAssertEqualObjects(manager.credential.receipt, kReceipt);
  XCTAssertEqualObjects(manager.credential.secret, kSecret);
  OCMVerifyAll(_mockKeychain);
}

@end

NS_ASSUME_NONNULL_END

#endif
