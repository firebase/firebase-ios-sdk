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

#import <XCTest/XCTest.h>
#import "OCMock.h"

#import "FirebaseAuth/Sources/SystemService/FIRAuthAPNSToken.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAPNSTokenManager.h"

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

/** @class FIRAuthLegacyUIApplication
    @brief A fake legacy (< iOS 7) UIApplication class.
    @remarks A custom class is needed because `respondsToSelector:` itself cannot be mocked.
 */
@interface FIRAuthLegacyUIApplication : NSObject

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)registerForRemoteNotificationTypes:(UIRemoteNotificationType)types;
#pragma clang diagnostic pop

@end
@implementation FIRAuthLegacyUIApplication

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)registerForRemoteNotificationTypes:(UIRemoteNotificationType)types {
}
#pragma clang diagnostic pop

@end

/** @class FIRAuthAPNSTokenManagerTests
    @brief Unit tests for @c FIRAuthAPNSTokenManager .
 */
@interface FIRAuthAPNSTokenManagerTests : XCTestCase
@end
@implementation FIRAuthAPNSTokenManagerTests {
  /** @var _mockApplication
      @brief The mock application for testing.
   */
  id _mockApplication;

  /** @var _manager
      @brief The @c FIRAuthAPNSTokenManager instance under tests.
   */
  FIRAuthAPNSTokenManager *_manager;

  /** @var _data
      @brief One piece of data used for testing.
   */
  NSData *_data;

  /** @var _otherData
      @brief Another piece of data used for testing.
   */
  NSData *_otherData;

  /** @var _error
      @brief The fake error used for testing.
   */
  NSError *_error;
}

- (void)setUp {
  _mockApplication = OCMClassMock([UIApplication class]);
  _manager = [[FIRAuthAPNSTokenManager alloc] initWithApplication:_mockApplication];
  _data = [@"qwerty" dataUsingEncoding:NSUTF8StringEncoding];
  _otherData = [@"!@#$" dataUsingEncoding:NSUTF8StringEncoding];
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
  // Add first callback, which is yet to be called.
  OCMExpect([_mockApplication registerForRemoteNotifications]);
  __block BOOL firstCallbackCalled = NO;
  [_manager getTokenWithCallback:^(FIRAuthAPNSToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqualObjects(token.data, self->_data);
    XCTAssertEqual(token.type, FIRAuthAPNSTokenTypeSandbox);
    XCTAssertNil(error);
    firstCallbackCalled = YES;
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

  // Verify the mock in the main thread.
  XCTestExpectation *expectation = [self expectationWithDescription:@"verify mock"];
  dispatch_async(dispatch_get_main_queue(), ^{
    OCMVerifyAll(self->_mockApplication);
    [expectation fulfill];
  });
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

/** @fn testTimeout
    @brief Tests callbacks can be timed out.
 */
- (void)testTimeout {
  // Set up timeout.
  XCTAssertGreaterThan(_manager.timeout, 0);
  _manager.timeout = kRegistrationTimeout;

  // Add callback to time out.
  OCMExpect([_mockApplication registerForRemoteNotifications]);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_manager getTokenWithCallback:^(FIRAuthAPNSToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertNil(token);
    XCTAssertNil(error);
    [expectation fulfill];
  }];

  // Time out.
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockApplication);

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
  OCMExpect([_mockApplication registerForRemoteNotifications]);
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
  XCTAssertTrue(callbackCalled);

  // Add callback to timeout.
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_manager getTokenWithCallback:^(FIRAuthAPNSToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertNil(token);
    XCTAssertNil(error);
    [expectation fulfill];
  }];

  // Time out.
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
  OCMVerifyAll(_mockApplication);
}

/** @fn testLegacyRegistration
    @brief Tests remote notification registration on legacy systems.
 */
- (void)testLegacyRegistration {
  // Use a custom class for `respondsToSelector:` to work.
  _mockApplication = OCMClassMock([FIRAuthLegacyUIApplication class]);
  _manager = [[FIRAuthAPNSTokenManager alloc] initWithApplication:_mockApplication];

  // Add callback.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [[[_mockApplication expect] ignoringNonObjectArgs] registerForRemoteNotificationTypes:0];
#pragma clang diagnostic pop
  __block BOOL callbackCalled = NO;
  [_manager getTokenWithCallback:^(FIRAuthAPNSToken *_Nullable token, NSError *_Nullable error) {
    XCTAssertEqualObjects(token.data, self->_data);
    XCTAssertNotEqual(token.type, FIRAuthAPNSTokenTypeUnknown);
    XCTAssertNil(error);
    callbackCalled = YES;
  }];
  XCTAssertFalse(callbackCalled);

  // Set the token.
  _manager.token = [[FIRAuthAPNSToken alloc] initWithData:_data type:FIRAuthAPNSTokenTypeUnknown];
  XCTAssertTrue(callbackCalled);

  // Verify the mock in the main thread.
  XCTestExpectation *expectation = [self expectationWithDescription:@"verify mock"];
  dispatch_async(dispatch_get_main_queue(), ^{
    OCMVerifyAll(self->_mockApplication);
    [expectation fulfill];
  });
  [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
}

@end

NS_ASSUME_NONNULL_END

#endif
