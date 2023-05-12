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
#if TARGET_OS_IOS

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

@import FirebaseAuth;

NS_ASSUME_NONNULL_BEGIN

/** @var kRegistrationTimeout
    @brief The registration timeout used for testing.
 */
static const NSTimeInterval kRegistrationTimeout = .5;

/** @var kExpectationTimeout
    @brief The test expectation timeout.
    @remarks This must be considerably greater than @c kVerificationTimeout .
 */
static const NSTimeInterval kExpectationTimeout = 2;

#if TARGET_OS_IOS && (!defined(TARGET_OS_XR) || !TARGET_OS_XR)

/** @class FIRAuthLegacyUIApplication
    @brief A fake legacy (< iOS 7) UIApplication class.
    @remarks A custom class is needed because `respondsToSelector:` itself cannot be mocked.
 */
@interface FakeApplication : NSObject <AuthAPNSTokenApplication>
- (void)registerForRemoteNotifications;
@end
@implementation FakeApplication
BOOL registerCalled;

- (void)registerForRemoteNotifications {
  registerCalled = YES;
}

- (BOOL)registerCalled {
  return registerCalled;
}
#pragma clang diagnostic pop

@end

#endif  // TARGET_OS_IOS && (!defined(TARGET_OS_XR) || !TARGET_OS_XR)

/** @class FIRAuthAPNSTokenManagerTests
    @brief Unit tests for @c FIRAuthAPNSTokenManager .
 */
@interface FIRAuthAPNSTokenManagerTests : XCTestCase
@end
@implementation FIRAuthAPNSTokenManagerTests {
  /** @var _mockApplication
      @brief The mock application for testing.
   */
  id _fakeApplication;

  /** @var _manager
      @brief The @c FIRAuthAPNSTokenManager instance under tests.
   */
  FIRAuthAPNSTokenManager *_manager;

  /** @var _data
      @brief One piece of data used for testing.
   */
  NSData *_data;

  /** @var _error
      @brief The fake error used for testing.
   */
  NSError *_error;
}

- (void)setUp {
  _fakeApplication = [[FakeApplication alloc] init];
  _manager = [[FIRAuthAPNSTokenManager alloc] initWithApplication:_fakeApplication];
  _data = [@"qwerty" dataUsingEncoding:NSUTF8StringEncoding];
}

/** @fn testSetToken
    @brief Tests setting and getting the `token` property.
 */
- (void)testSetToken {
  XCTAssertNil(_manager.token);
  _manager.token = [[FIRAuthAPNSToken alloc] initWithData:_data type:FIRAuthAPNSTokenTypeProd];
  XCTAssertEqualObjects(_manager.token.data, _data);
  XCTAssertEqual(_manager.token.type, FIRAuthAPNSTokenTypeProd);
  _manager.token = nil;
  XCTAssertNil(_manager.token);
}

/** @fn testDetectTokenType
    @brief Tests automatic detection of token type.
 */
- (void)testDetectTokenType {
  XCTAssertNil(_manager.token);
  _manager.token = [[FIRAuthAPNSToken alloc] initWithData:_data type:FIRAuthAPNSTokenTypeUnknown];
  XCTAssertEqualObjects(_manager.token.data, _data);
  XCTAssertNotEqual(_manager.token.type, FIRAuthAPNSTokenTypeUnknown);
}

/** @fn testCallback
    @brief Tests callbacks are called.
 */
- (void)testCallback {
  __block BOOL firstCallbackCalled = NO;
  [_manager getTokenWithCallback:^(FIRAuthAPNSToken *_Nullable token, NSError *_Nullable error) {
    firstCallbackCalled = YES;
    XCTAssertEqualObjects(token.data, self->_data);
    XCTAssertEqual(token.type, FIRAuthAPNSTokenTypeSandbox);
    XCTAssertNil(error);
  }];
  XCTAssertFalse(firstCallbackCalled);

  // Add second callback, which is yet to be called either.
  __block BOOL secondCallbackCalled = NO;
  [_manager getTokenWithCallback:^(FIRAuthAPNSToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqualObjects(token.data, self->_data);
    XCTAssertEqual(token.type, FIRAuthAPNSTokenTypeSandbox);
    XCTAssertNil(error);
    secondCallbackCalled = YES;
  }];
  XCTAssertFalse(secondCallbackCalled);

  // Setting nil token shouldn't trigger either callbacks.
  _manager.token = nil;
  XCTAssertFalse(firstCallbackCalled);
  XCTAssertFalse(secondCallbackCalled);
  XCTAssertNil(_manager.token);

  // Setting a real token should trigger both callbacks.
  _manager.token = [[FIRAuthAPNSToken alloc] initWithData:_data type:FIRAuthAPNSTokenTypeSandbox];
  XCTAssertTrue(firstCallbackCalled);
  XCTAssertTrue(secondCallbackCalled);
  XCTAssertEqualObjects(_manager.token.data, _data);
  XCTAssertEqual(_manager.token.type, FIRAuthAPNSTokenTypeSandbox);

  // Add third callback, which should be called back immediately.
  __block BOOL thirdCallbackCalled = NO;
  [_manager getTokenWithCallback:^(FIRAuthAPNSToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqualObjects(token.data, self->_data);
    XCTAssertEqual(token.type, FIRAuthAPNSTokenTypeSandbox);
    XCTAssertNil(error);
    thirdCallbackCalled = YES;
  }];
  XCTAssertTrue(thirdCallbackCalled);

  // In the main thread, Verify the that the fake `registerForRemoteNotifications` was called.
  dispatch_async(dispatch_get_main_queue(), ^{
    XCTAssertTrue([self->_fakeApplication registerCalled]);
  });
}

/** @fn testTimeout
    @brief Tests callbacks can be timed out.
 */
- (void)testTimeout {
  // Set up timeout.
  XCTAssertGreaterThan(_manager.timeout, 0);
  _manager.timeout = kRegistrationTimeout;

  // Add callback to time out.
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_manager getTokenWithCallback:^(FIRAuthAPNSToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertNil(token);
    XCTAssertNil(error);
    [expectation fulfill];
  }];

  // Time out.
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  // In the main thread, Verify the that the fake `registerForRemoteNotifications` was called.
  dispatch_async(dispatch_get_main_queue(), ^{
    XCTAssertTrue([self->_fakeApplication registerCalled]);
  });

  // Calling cancel afterwards should have no effect.
  [_manager cancelWithError:_error];
}

/** @fn testCancel
    @brief Tests cancelling the pending callbacks.
 */
- (void)testCancel {
  // Set up timeout.
  XCTAssertGreaterThan(_manager.timeout, 0);
  _manager.timeout = kRegistrationTimeout;

  // Add callback to cancel.
  __block BOOL callbackCalled = NO;
  [_manager getTokenWithCallback:^(FIRAuthAPNSToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertNil(token);
    XCTAssertEqualObjects(error, self->_error);
    XCTAssertFalse(callbackCalled);  // verify callback is not called twice
    callbackCalled = YES;
  }];
  XCTAssertFalse(callbackCalled);

  // Call cancel.
  [_manager cancelWithError:_error];

  // In the main thread, Verify the that the fake `registerForRemoteNotifications` was called.
  dispatch_async(dispatch_get_main_queue(), ^{
    XCTAssertTrue([self->_fakeApplication registerCalled]);
  });

  // Add callback to timeout.
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_manager getTokenWithCallback:^(FIRAuthAPNSToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertNil(token);
    XCTAssertNil(error);
    [expectation fulfill];
  }];

  // Time out.
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];

  // In the main thread, Verify the that the fake `registerForRemoteNotifications` was called.
  dispatch_async(dispatch_get_main_queue(), ^{
    XCTAssertTrue([self->_fakeApplication registerCalled]);
  });
}

#endif  // TARGET_OS_IOS && (!defined(TARGET_OS_XR) || !TARGET_OS_XR)

@end

NS_ASSUME_NONNULL_END

#endif  // TARGET_OS_IOS
