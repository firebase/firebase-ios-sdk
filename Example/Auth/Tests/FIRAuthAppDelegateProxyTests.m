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

#import <objc/runtime.h>

#import "FIRAuthAppDelegateProxy.h"
#import <OCMock/OCMock.h>

NS_ASSUME_NONNULL_BEGIN

/** @class FIRAuthEmptyAppDelegate
    @brief A @c UIApplicationDelegate implementation that does nothing.
 */
@interface FIRAuthEmptyAppDelegate : NSObject <UIApplicationDelegate>
@end
@implementation FIRAuthEmptyAppDelegate
@end

/** @class FIRAuthLegacyAppDelegate
    @brief A @c UIApplicationDelegate implementation that implements
        `application:didReceiveRemoteNotification:`.
 */
@interface FIRAuthLegacyAppDelegate : NSObject <UIApplicationDelegate>

/** @var notificationReceived
    @brief The last notification received, if any.
 */
@property(nonatomic, copy, nullable) NSDictionary *notificationReceived;

@end

@implementation FIRAuthLegacyAppDelegate

- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo {
  self.notificationReceived = userInfo;
}

@end

/** @class FIRAuthModernAppDelegate
    @brief A @c UIApplicationDelegate implementation that implements both
        `application:didRegisterForRemoteNotificationsWithDeviceToken:` and
        `application:didReceiveRemoteNotification:fetchCompletionHandler:`.
 */
@interface FIRAuthModernAppDelegate : NSObject <UIApplicationDelegate>

/** @var deviceTokenReceived
    @brief The last device token received, if any.
 */
@property(nonatomic, copy, nullable) NSData *deviceTokenReceived;

/** @var notificationReceived
    @brief The last notification received, if any.
 */
@property(nonatomic, copy, nullable) NSDictionary *notificationReceived;

@end

@implementation FIRAuthModernAppDelegate

- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  self.deviceTokenReceived = deviceToken;
}

- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  self.notificationReceived = userInfo;
  completionHandler(UIBackgroundFetchResultNewData);
}

@end

/** @class FIRAuthAppDelegateProxyTests
    @brief Unit tests for @c FIRAuthAppDelegateProxy .
 */
@interface FIRAuthAppDelegateProxyTests : XCTestCase
@end
@implementation FIRAuthAppDelegateProxyTests {
  /** @var _mockApplication
      @brief The mock UIApplication used for testing.
   */
  id _mockApplication;

  /** @var _deviceToken
      @brief The fake APNs device token for testing.
   */
  NSData *_deviceToken;

  /** @var _notification
      @brief The fake notification for testing.
   */
  NSDictionary* _notification;
}

- (void)setUp {
  [super setUp];
  _mockApplication = OCMClassMock([UIApplication class]);
  _deviceToken = [@"asdf" dataUsingEncoding:NSUTF8StringEncoding];
  _notification = @{ @"zxcv" : @1234 };
}

- (void)tearDown {
  OCMVerifyAll(_mockApplication);
  [super tearDown];
}

/** @fn testSharedInstance
    @brief Tests that the shared instance is the same one.
 */
- (void)testSharedInstance {
  FIRAuthAppDelegateProxy *proxy1 = [FIRAuthAppDelegateProxy sharedInstance];
  FIRAuthAppDelegateProxy *proxy2 = [FIRAuthAppDelegateProxy sharedInstance];
  XCTAssertEqual(proxy1, proxy2);
}

/** @fn testNilApplication
    @brief Tests that initialization fails if the application is nil.
 */
- (void)testNilApplication {
  XCTAssertNil([[FIRAuthAppDelegateProxy alloc] initWithApplication:nil]);
}

/** @fn testNilDelegate
    @brief Tests that initialization fails if the application's delegate is nil.
 */
- (void)testNilDelegate {
  OCMExpect([_mockApplication delegate]).andReturn(nil);
  XCTAssertNil([[FIRAuthAppDelegateProxy alloc] initWithApplication:_mockApplication]);
}

/** @fn testNonconformingDelegate
    @brief Tests that initialization fails if the application's delegate does not conform to
        @c UIApplicationDelegate protocol.
 */
- (void)testNonconformingDelegate {
  OCMExpect([_mockApplication delegate]).andReturn(@"abc");
  XCTAssertNil([[FIRAuthAppDelegateProxy alloc] initWithApplication:_mockApplication]);
}

/** @fn testDisabledByBundleEntry
    @brief Tests that initialization fails if the proxy is disabled by a bundle entry.
 */
- (void)testDisabledByBundleEntry {
  // Swizzle NSBundle's objectForInfoDictionaryKey to return @NO for the specific key.
  Method method = class_getInstanceMethod([NSBundle class], @selector(objectForInfoDictionaryKey:));
  __block IMP originalImplementation;
  IMP newImplmentation = imp_implementationWithBlock(^id(id object, NSString *key) {
    if ([key isEqualToString:@"FirebaseAppDelegateProxyEnabled"]) {
      return @NO;
    }
    typedef id (*Implementation)(id object, SEL cmd, NSString *key);
    return ((Implementation)originalImplementation)(object, @selector(objectForInfoDictionaryKey:),
                                                    key);
  });
  originalImplementation = method_setImplementation(method, newImplmentation);

  // Verify that initialization fails.
  FIRAuthEmptyAppDelegate *delegate = [[FIRAuthEmptyAppDelegate alloc] init];
  OCMStub([_mockApplication delegate]).andReturn(delegate);
  XCTAssertNil([[FIRAuthAppDelegateProxy alloc] initWithApplication:_mockApplication]);

  // Unswizzle.
  imp_removeBlock(method_setImplementation(method, originalImplementation));
}

/** @fn testEmptyDelegateOneHandler
    @brief Tests that the proxy works against an empty @c UIApplicationDelegate for one handler.
 */
- (void)testEmptyDelegateOneHandler {
  FIRAuthEmptyAppDelegate *delegate = [[FIRAuthEmptyAppDelegate alloc] init];
  OCMExpect([_mockApplication delegate]).andReturn(delegate);
  __weak id weakProxy;
  @autoreleasepool {
    FIRAuthAppDelegateProxy *proxy =
        [[FIRAuthAppDelegateProxy alloc] initWithApplication:_mockApplication];
    XCTAssertNotNil(proxy);

    // Verify `application:didReceiveRemoteNotification:` is not swizzled.
    XCTAssertFalse([delegate respondsToSelector:
                    @selector(application:didReceiveRemoteNotification:)]);

    // Verify the handler is called after being added.
    __weak id weakHandler;
    @autoreleasepool {
      id mockHandler = OCMProtocolMock(@protocol(FIRAuthAppDelegateHandler));
      [proxy addHandler:mockHandler];

      // Verify handling of `application:didRegisterForRemoteNotificationsWithDeviceToken:`.
      OCMExpect([mockHandler setAPNSToken:_deviceToken]);
      [delegate application:_mockApplication
          didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
      OCMVerifyAll(mockHandler);

      // Verify handling of `application:didReceiveRemoteNotification:fetchCompletionHandler:`.
      OCMExpect([mockHandler canHandleNotification:_notification]).andReturn(YES);
      __block BOOL fetchCompletionHandlerCalled = NO;
      [delegate application:_mockApplication
          didReceiveRemoteNotification:_notification
                fetchCompletionHandler:^(UIBackgroundFetchResult result) {
        XCTAssertEqual(result, UIBackgroundFetchResultNoData);
        fetchCompletionHandlerCalled = YES;
      }];
      OCMVerifyAll(mockHandler);
      XCTAssertTrue(fetchCompletionHandlerCalled);

      weakHandler = mockHandler;
      XCTAssertNotNil(weakHandler);
    }
    // Verify the handler is not retained by the proxy.
    XCTAssertNil(weakHandler);

    // Verify nothing bad happens after the handler is released.
    [delegate application:_mockApplication
        didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
    [delegate application:_mockApplication
        didReceiveRemoteNotification:_notification
              fetchCompletionHandler:^(UIBackgroundFetchResult result) {
      XCTFail(@"Should not call completion handler.");
    }];

    weakProxy = proxy;
    XCTAssertNotNil(weakProxy);
  }
  // Verify the proxy does not retain itself.
  XCTAssertNil(weakProxy);
  // Verify nothing bad happens after the proxy is released.
  [delegate application:_mockApplication
      didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
  [delegate application:_mockApplication
      didReceiveRemoteNotification:_notification
            fetchCompletionHandler:^(UIBackgroundFetchResult result) {
    XCTFail(@"Should not call completion handler.");
  }];
}

/** @fn testLegacyDelegateTwoHandlers
    @brief Tests that the proxy works against a legacy @c UIApplicationDelegate for two handlers.
 */
- (void)testLegacyDelegateTwoHandlers {
  FIRAuthLegacyAppDelegate *delegate = [[FIRAuthLegacyAppDelegate alloc] init];
  OCMExpect([_mockApplication delegate]).andReturn(delegate);
  __weak id weakProxy;
  @autoreleasepool {
    FIRAuthAppDelegateProxy *proxy =
        [[FIRAuthAppDelegateProxy alloc] initWithApplication:_mockApplication];
    XCTAssertNotNil(proxy);

    // Verify `application:didReceiveRemoteNotification:fetchCompletionHandler` is not swizzled.
    XCTAssertFalse([delegate respondsToSelector:
                    @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]);

    // Verify the handler is called after being added.
    __weak id weakHandler1;
    @autoreleasepool {
      id mockHandler1 = OCMProtocolMock(@protocol(FIRAuthAppDelegateHandler));
      [proxy addHandler:mockHandler1];
      __weak id weakHandler2;
      @autoreleasepool {
        id mockHandler2 = OCMProtocolMock(@protocol(FIRAuthAppDelegateHandler));
        [proxy addHandler:mockHandler2];

        // Verify handling of `application:didRegisterForRemoteNotificationsWithDeviceToken:`.
        OCMExpect([mockHandler1 setAPNSToken:_deviceToken]);
        OCMExpect([mockHandler2 setAPNSToken:_deviceToken]);
        [delegate application:_mockApplication
            didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
        OCMVerifyAll(mockHandler1);
        OCMVerifyAll(mockHandler2);

        // Verify handling of `application:didReceiveRemoteNotification:fetchCompletionHandler:`.
        OCMExpect([mockHandler1 canHandleNotification:_notification]).andReturn(YES);
        // handler2 shouldn't been invoked because it is already handled by handler1.
        [delegate application:_mockApplication didReceiveRemoteNotification:_notification];
        OCMVerifyAll(mockHandler1);
        OCMVerifyAll(mockHandler2);
        XCTAssertNil(delegate.notificationReceived);

        weakHandler2 = mockHandler2;
        XCTAssertNotNil(weakHandler2);
      }
      // Verify the handler2 is not retained by the proxy.
      XCTAssertNil(weakHandler2);

      // Verify handling of `application:didRegisterForRemoteNotificationsWithDeviceToken:`.
      OCMExpect([mockHandler1 setAPNSToken:_deviceToken]);
      [delegate application:_mockApplication
          didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
      OCMVerifyAll(mockHandler1);

      // Verify NOT handling of `application:didReceiveRemoteNotification:fetchCompletionHandler:`.
      OCMExpect([mockHandler1 canHandleNotification:_notification]).andReturn(NO);
      [delegate application:_mockApplication didReceiveRemoteNotification:_notification];
      OCMVerifyAll(mockHandler1);
      XCTAssertEqualObjects(delegate.notificationReceived, _notification);
      delegate.notificationReceived = nil;

      weakHandler1 = mockHandler1;
      XCTAssertNotNil(weakHandler1);
    }
    // Verify the handler1 is not retained by the proxy.
    XCTAssertNil(weakHandler1);

    // Verify the delegate still works after all handlers are released.
    [delegate application:_mockApplication
        didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
    [delegate application:_mockApplication didReceiveRemoteNotification:_notification];
    XCTAssertEqualObjects(delegate.notificationReceived, _notification);
    delegate.notificationReceived = nil;

    weakProxy = proxy;
    XCTAssertNotNil(weakProxy);
  }
  // Verify the proxy does not retain itself.
  XCTAssertNil(weakProxy);

  // Verify the delegate still works after the proxy is released.
  [delegate application:_mockApplication
      didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
  [delegate application:_mockApplication didReceiveRemoteNotification:_notification];
  XCTAssertEqualObjects(delegate.notificationReceived, _notification);
  delegate.notificationReceived = nil;
}

/** @fn testModernDelegateWithOtherInstance
    @brief Tests that the proxy works against a modern @c UIApplicationDelegate along with
        another unaffected instance.
 */
- (void)testModernDelegateWithUnaffectedInstance {
  FIRAuthModernAppDelegate *delegate = [[FIRAuthModernAppDelegate alloc] init];
  OCMExpect([_mockApplication delegate]).andReturn(delegate);
  FIRAuthModernAppDelegate *unaffectedDelegate = [[FIRAuthModernAppDelegate alloc] init];
  __weak id weakProxy;
  @autoreleasepool {
    FIRAuthAppDelegateProxy *proxy =
        [[FIRAuthAppDelegateProxy alloc] initWithApplication:_mockApplication];
    XCTAssertNotNil(proxy);

    // Verify `application:didReceiveRemoteNotification:` is not swizzled.
    XCTAssertFalse([delegate respondsToSelector:
                    @selector(application:didReceiveRemoteNotification:)]);

    // Verify the handler is called after being added.
    __weak id weakHandler;
    @autoreleasepool {
      id mockHandler = OCMProtocolMock(@protocol(FIRAuthAppDelegateHandler));
      [proxy addHandler:mockHandler];

      // Verify handling of `application:didRegisterForRemoteNotificationsWithDeviceToken:`.
      OCMExpect([mockHandler setAPNSToken:_deviceToken]);
      [delegate application:_mockApplication
          didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
      OCMVerifyAll(mockHandler);
      XCTAssertEqualObjects(delegate.deviceTokenReceived, _deviceToken);
      delegate.deviceTokenReceived = nil;

      // Verify handling of `application:didReceiveRemoteNotification:fetchCompletionHandler:`.
      OCMExpect([mockHandler canHandleNotification:_notification]).andReturn(YES);
      __block BOOL fetchCompletionHandlerCalled = NO;
      [delegate application:_mockApplication
          didReceiveRemoteNotification:_notification
                fetchCompletionHandler:^(UIBackgroundFetchResult result) {
        XCTAssertEqual(result, UIBackgroundFetchResultNoData);
        fetchCompletionHandlerCalled = YES;
      }];
      OCMVerifyAll(mockHandler);
      XCTAssertTrue(fetchCompletionHandlerCalled);
      XCTAssertNil(delegate.notificationReceived);

      // Verify unaffected delegate instance.
      [unaffectedDelegate application:_mockApplication
          didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
      XCTAssertEqualObjects(unaffectedDelegate.deviceTokenReceived, _deviceToken);
      unaffectedDelegate.deviceTokenReceived = nil;
      fetchCompletionHandlerCalled = NO;
      [unaffectedDelegate application:_mockApplication
          didReceiveRemoteNotification:_notification
                fetchCompletionHandler:^(UIBackgroundFetchResult result) {
        XCTAssertEqual(result, UIBackgroundFetchResultNewData);
        fetchCompletionHandlerCalled = YES;
      }];
      XCTAssertTrue(fetchCompletionHandlerCalled);
      XCTAssertEqualObjects(unaffectedDelegate.notificationReceived, _notification);
      unaffectedDelegate.notificationReceived = nil;

      weakHandler = mockHandler;
      XCTAssertNotNil(weakHandler);
    }
    // Verify the handler is not retained by the proxy.
    XCTAssertNil(weakHandler);

    // Verify the delegate still works after the handler is released.
    [delegate application:_mockApplication
        didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
    XCTAssertEqualObjects(delegate.deviceTokenReceived, _deviceToken);
    delegate.deviceTokenReceived = nil;
    __block BOOL fetchCompletionHandlerCalled = NO;
    [delegate application:_mockApplication
        didReceiveRemoteNotification:_notification
              fetchCompletionHandler:^(UIBackgroundFetchResult result) {
      XCTAssertEqual(result, UIBackgroundFetchResultNewData);
      fetchCompletionHandlerCalled = YES;
    }];
    XCTAssertEqualObjects(delegate.notificationReceived, _notification);
    delegate.notificationReceived = nil;
    XCTAssertTrue(fetchCompletionHandlerCalled);

    weakProxy = proxy;
    XCTAssertNotNil(weakProxy);
  }
  // Verify the proxy does not retain itself.
  XCTAssertNil(weakProxy);

  // Verify the delegate still works after the proxy is released.
  [delegate application:_mockApplication
      didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
  XCTAssertEqualObjects(delegate.deviceTokenReceived, _deviceToken);
  delegate.deviceTokenReceived = nil;
    __block BOOL fetchCompletionHandlerCalled = NO;
  [delegate application:_mockApplication
      didReceiveRemoteNotification:_notification
            fetchCompletionHandler:^(UIBackgroundFetchResult result) {
    XCTAssertEqual(result, UIBackgroundFetchResultNewData);
    fetchCompletionHandlerCalled = YES;
  }];
  XCTAssertEqualObjects(delegate.notificationReceived, _notification);
  delegate.notificationReceived = nil;
  XCTAssertTrue(fetchCompletionHandlerCalled);
}

@end

NS_ASSUME_NONNULL_END
