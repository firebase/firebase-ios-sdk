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

#import "FirebaseAuth/Sources/SystemService/FIRAuthAppCredential.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAppCredentialManager.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthNotificationManager.h"

NS_ASSUME_NONNULL_BEGIN

/** @var kReceipt
    @brief A fake receipt used for testing.
 */
static NSString *const kReceipt = @"FAKE_RECEIPT";

/** @var kSecret
    @brief A fake secret used for testing.
 */
static NSString *const kSecret = @"FAKE_SECRET";

/** @class FIRAuthFakeForwardingDelegate
    @brief The base class for a fake UIApplicationDelegate that forwards remote notifications.
 */
@interface FIRAuthFakeForwardingDelegate : NSObject <UIApplicationDelegate>

/** @property notificationManager
    @brief The notification manager to forward.
 */
@property(nonatomic, strong) FIRAuthNotificationManager *notificationManager;

/** @property forwardsNotification
    @brief Whether notifications are being forwarded.
 */
@property(nonatomic, assign) BOOL forwardsNotification;

/** @property notificationReceived
    @brief Whether a notification has been received.
 */
@property(nonatomic, assign) BOOL notificationReceived;

/** @property notificationhandled
    @brief Whether a notification has been handled.
 */
@property(nonatomic, assign) BOOL notificationhandled;

@end
@implementation FIRAuthFakeForwardingDelegate
@end

/** @class FIRAuthFakeForwardingDelegate
    @brief A fake UIApplicationDelegate that implements the modern deegate method to receive
        notification.
 */
@interface FIRAuthModernForwardingDelegate : FIRAuthFakeForwardingDelegate
@end
@implementation FIRAuthModernForwardingDelegate

- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  self.notificationReceived = YES;
  if (self.forwardsNotification) {
    self.notificationhandled = [self.notificationManager canHandleNotification:userInfo];
  }
}

@end

/** @class FIRAuthNotificationManagerTests
    @brief Unit tests for @c FIRAuthNotificationManager .
 */
@interface FIRAuthNotificationManagerTests : XCTestCase
@end
@implementation FIRAuthNotificationManagerTests {
  /** @var _mockApplication
      @brief The mock UIApplication for testing.
   */
  id _mockApplication;

  /** @var _mockAppCredentialManager
      @brief The mock FIRAuthAppCredentialManager for testing.
   */
  id _mockAppCredentialManager;

  /** @var _notificationManager
      @brief The FIRAuthNotificationManager to be tested.
   */
  FIRAuthNotificationManager *_notificationManager;

  /** @var _modernDelegate
      @brief The modern fake UIApplicationDelegate for testing.
   */
  FIRAuthModernForwardingDelegate *_modernDelegate;
}

- (void)setUp {
  _mockApplication = OCMClassMock([UIApplication class]);
  _mockAppCredentialManager = OCMClassMock([FIRAuthAppCredentialManager class]);
  _notificationManager =
      [[FIRAuthNotificationManager alloc] initWithApplication:_mockApplication
                                         appCredentialManager:_mockAppCredentialManager];
  _modernDelegate = [[FIRAuthModernForwardingDelegate alloc] init];
  _modernDelegate.notificationManager = _notificationManager;
}

/** @fn testForwardingModernDelegate
    @brief Tests checking notification forwarding on modern fake delegate.
 */
- (void)testForwardingModernDelegate {
  [self verifyForwarding:YES delegate:_modernDelegate];
}

/** @fn testNotForwardingModernDelegate
    @brief Tests checking notification not forwarding on modern fake delegate.
 */
- (void)testNotForwardingModernDelegate {
  [self verifyForwarding:NO delegate:_modernDelegate];
}

/** @fn verifyForwarding:delegate:
    @brief Tests checking notification forwarding on a particular delegate.
    @param forwarding Whether the notification is being forwarded or not.
    @param delegate The fake UIApplicationDelegate used for testing.
 */
- (void)verifyForwarding:(BOOL)forwarding delegate:(FIRAuthFakeForwardingDelegate *)delegate {
  delegate.forwardsNotification = forwarding;
  OCMStub([_mockApplication delegate]).andReturn(delegate);
  XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
  [_notificationManager
      checkNotificationForwardingWithCallback:^(BOOL isNotificationBeingForwarded) {
        XCTAssertEqual(isNotificationBeingForwarded, forwarding);
        [expectation fulfill];
      }];
  XCTAssertFalse(delegate.notificationReceived);
  NSTimeInterval timeout = _notificationManager.timeout * (1.5 - forwarding);
  [self waitForExpectationsWithTimeout:timeout handler:nil];
  XCTAssertTrue(delegate.notificationReceived);
  XCTAssertEqual(delegate.notificationhandled, forwarding);
}

/** @fn testCachedResult
    @brief Test notification forwarding is only checked once.
 */
- (void)testCachedResult {
  FIRAuthFakeForwardingDelegate *delegate = _modernDelegate;
  [self verifyForwarding:NO delegate:delegate];
  delegate.notificationReceived = NO;
  __block BOOL calledBack = NO;
  [_notificationManager
      checkNotificationForwardingWithCallback:^(BOOL isNotificationBeingForwarded) {
        XCTAssertFalse(isNotificationBeingForwarded);
        calledBack = YES;
      }];
  XCTAssertTrue(calledBack);
  XCTAssertFalse(delegate.notificationReceived);
}

/** @fn testPassingToCredentialManager
    @brief Test notification with the right structure is passed to credential manager.
 */
- (void)testPassingToCredentialManager {
  NSDictionary *payload = @{@"receipt" : kReceipt, @"secret" : kSecret};
  NSDictionary *notification = @{@"com.google.firebase.auth" : payload};
  OCMExpect([_mockAppCredentialManager canFinishVerificationWithReceipt:kReceipt secret:kSecret])
      .andReturn(YES);
  XCTAssertTrue([_notificationManager canHandleNotification:notification]);
  OCMVerifyAll(_mockAppCredentialManager);

  // JSON string form
  NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
  NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  notification = @{@"com.google.firebase.auth" : string};
  OCMExpect([_mockAppCredentialManager canFinishVerificationWithReceipt:kReceipt secret:kSecret])
      .andReturn(YES);
  XCTAssertTrue([_notificationManager canHandleNotification:notification]);
  OCMVerifyAll(_mockAppCredentialManager);
}

/** @fn testNotHandling
    @brief Test unrecognized notifications are not handled.
 */
- (void)testNotHandling {
  XCTAssertFalse([_notificationManager canHandleNotification:@{@"random" : @"string"}]);
  XCTAssertFalse([_notificationManager
      canHandleNotification:@{@"com.google.firebase.auth" : @"something wrong"}]);
  XCTAssertFalse([_notificationManager canHandleNotification:@{
    @"com.google.firebase.auth" : @{
      @"receipt" : kReceipt
      // missing secret
    }
  }]);
  XCTAssertFalse([_notificationManager canHandleNotification:@{
    @"com.google.firebase.auth" : @{
      // missing receipt
      @"secret" : kSecret
    }
  }]);
  XCTAssertFalse([_notificationManager canHandleNotification:@{
    @"com.google.firebase.auth" : @{
      // probing notification does not belong to this instance
      @"warning" : @"asdf"
    }
  }]);
}

@end

NS_ASSUME_NONNULL_END

#endif
