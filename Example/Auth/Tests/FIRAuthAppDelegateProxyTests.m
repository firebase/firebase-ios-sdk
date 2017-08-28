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
#import <UIKit/UIKit.h>

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
        `application:didReceiveRemoteNotification:` and
        `application:openURL:sourceApplication:annotation:`.
 */
@interface FIRAuthLegacyAppDelegate : NSObject <UIApplicationDelegate>

/** @var notificationReceived
    @brief The last notification received, if any.
 */
@property(nonatomic, copy, nullable) NSDictionary *notificationReceived;

/** @var urlOpened
    @brief The last URL opened, if any.
 */
@property(nonatomic, copy, nullable) NSURL *urlOpened;

@end

@implementation FIRAuthLegacyAppDelegate

- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo {
  self.notificationReceived = userInfo;
}

- (BOOL)application:(UIApplication *)application
              openURL:(NSURL *)url
    sourceApplication:(nullable NSString *)sourceApplication
           annotation:(id)annotation {
  self.urlOpened = url;
  return NO;
}

@end

/** @class FIRAuthModernAppDelegate
    @brief A @c UIApplicationDelegate implementation that implements both
        `application:didRegisterForRemoteNotificationsWithDeviceToken:`,
        `application:didReceiveRemoteNotification:fetchCompletionHandler:`, and
        `application:openURL:options:`.
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

/** @var urlOpened
    @brief The last URL opened, if any.
 */
@property(nonatomic, copy, nullable) NSURL *urlOpened;

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

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
  self.urlOpened = url;
  return NO;
}

@end

/** @class FIRAuthOtherLegacyAppDelegate
    @brief A @c UIApplicationDelegate implementation that implements `application:handleOpenURL:`.
 */
@interface FIRAuthOtherLegacyAppDelegate : NSObject <UIApplicationDelegate>

/** @var urlOpened
    @brief The last URL opened, if any.
 */
@property(nonatomic, copy, nullable) NSURL *urlOpened;

@end

@implementation FIRAuthOtherLegacyAppDelegate

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
  self.urlOpened = url;
  return NO;
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

  /** @var _url
      @brief The fake URL for testing.
   */
  NSURL *_url;

  /** @var _isIOS9orLater
      @brief Whether the OS version is iOS 9 or later.
   */
  BOOL _isIOS9orLater;
}

- (void)setUp {
  [super setUp];
  _mockApplication = OCMClassMock([UIApplication class]);
  _deviceToken = [@"asdf" dataUsingEncoding:NSUTF8StringEncoding];
  _notification = @{ @"zxcv" : @1234 };
  _url = [NSURL URLWithString:@"https://abc.def/ghi"];
  _isIOS9orLater = [[[UIDevice currentDevice] systemVersion] doubleValue] >= 9.0;
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

// Deprecated methods are call intentionally in tests to verify behaviors on older iOS systems.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

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

    // Verify certain methods are swizzled while others are not.
    XCTAssertTrue([delegate respondsToSelector:
                   @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]);
    XCTAssertTrue([delegate respondsToSelector:
                   @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]);
    XCTAssertFalse([delegate respondsToSelector:
                    @selector(application:didReceiveRemoteNotification:)]);
    if (_isIOS9orLater) {
      XCTAssertTrue([delegate respondsToSelector:@selector(application:openURL:options:)]);
      XCTAssertFalse([delegate respondsToSelector:
                      @selector(application:openURL:sourceApplication:annotation:)]);
    } else {
      XCTAssertFalse([delegate respondsToSelector:@selector(application:openURL:options:)]);
      XCTAssertTrue([delegate respondsToSelector:
                     @selector(application:openURL:sourceApplication:annotation:)]);
    }
    XCTAssertFalse([delegate respondsToSelector:@selector(application:handleOpenURL:)]);

    // Verify the handler is called after being added.
    __weak id weakHandler;
    @autoreleasepool {
      id mockHandler = OCMProtocolMock(@protocol(FIRAuthAppDelegateHandler));
      [proxy addHandler:mockHandler];

      // Verify `application:didRegisterForRemoteNotificationsWithDeviceToken:` is handled.
      OCMExpect([mockHandler setAPNSToken:_deviceToken]);
      [delegate application:_mockApplication
          didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
      OCMVerifyAll(mockHandler);

      // Verify `application:didReceiveRemoteNotification:fetchCompletionHandler:` is handled.
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

      // Verify one of the `application:openURL:...` methods is handled.
      OCMExpect([mockHandler canHandleURL:_url]).andReturn(YES);
      if (_isIOS9orLater) {
        // Verify `application:openURL:options:` is handled.
        XCTAssertTrue([delegate application:_mockApplication openURL:_url options:@{}]);
      } else {
        // Verify `application:openURL:sourceApplication:annotation:` is handled.
        XCTAssertTrue([delegate application:_mockApplication
                                    openURL:_url
                          sourceApplication:@"sourceApplication"
                                 annotation:@"annotaton"]);
      }
      OCMVerifyAll(mockHandler);

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
    if (_isIOS9orLater) {
      XCTAssertFalse([delegate application:_mockApplication openURL:_url options:@{}]);
    } else {
      XCTAssertFalse([delegate application:_mockApplication
                                   openURL:_url
                         sourceApplication:@"sourceApplication"
                                annotation:@"annotaton"]);
    }
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
  if (_isIOS9orLater) {
    XCTAssertFalse([delegate application:_mockApplication openURL:_url options:@{}]);
  } else {
    XCTAssertFalse([delegate application:_mockApplication
                                 openURL:_url
                       sourceApplication:@"sourceApplication"
                              annotation:@"annotaton"]);
  }
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

    // Verify certain methods are swizzled while others are not.
    XCTAssertTrue([delegate respondsToSelector:
                   @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]);
    XCTAssertFalse([delegate respondsToSelector:
                    @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]);
    XCTAssertTrue([delegate respondsToSelector:
                   @selector(application:didReceiveRemoteNotification:)]);
    XCTAssertFalse([delegate respondsToSelector:@selector(application:openURL:options:)]);
    XCTAssertTrue([delegate respondsToSelector:
                   @selector(application:openURL:sourceApplication:annotation:)]);
    XCTAssertFalse([delegate respondsToSelector:@selector(application:handleOpenURL:)]);

    // Verify the handler is called after being added.
    __weak id weakHandler1;
    @autoreleasepool {
      id mockHandler1 = OCMProtocolMock(@protocol(FIRAuthAppDelegateHandler));
      [proxy addHandler:mockHandler1];
      __weak id weakHandler2;
      @autoreleasepool {
        id mockHandler2 = OCMProtocolMock(@protocol(FIRAuthAppDelegateHandler));
        [proxy addHandler:mockHandler2];

        // Verify `application:didRegisterForRemoteNotificationsWithDeviceToken:` is handled.
        OCMExpect([mockHandler1 setAPNSToken:_deviceToken]);
        OCMExpect([mockHandler2 setAPNSToken:_deviceToken]);
        [delegate application:_mockApplication
            didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
        OCMVerifyAll(mockHandler1);
        OCMVerifyAll(mockHandler2);

        // Verify `application:didReceiveRemoteNotification:fetchCompletionHandler:` is handled.
        OCMExpect([mockHandler1 canHandleNotification:_notification]).andReturn(YES);
        // handler2 shouldn't been invoked because it is already handled by handler1.
        [delegate application:_mockApplication didReceiveRemoteNotification:_notification];
        OCMVerifyAll(mockHandler1);
        OCMVerifyAll(mockHandler2);
        XCTAssertNil(delegate.notificationReceived);

        // Verify `application:openURL:sourceApplication:annotation:` is handled.
        OCMExpect([mockHandler1 canHandleURL:_url]).andReturn(YES);
        XCTAssertTrue([delegate application:_mockApplication
                                    openURL:_url
                          sourceApplication:@"sourceApplication"
                                 annotation:@"annotaton"]);
        OCMVerifyAll(mockHandler1);
        OCMVerifyAll(mockHandler2);
        XCTAssertNil(delegate.urlOpened);

        weakHandler2 = mockHandler2;
        XCTAssertNotNil(weakHandler2);
      }
      // Verify the handler2 is not retained by the proxy.
      XCTAssertNil(weakHandler2);

      // Verify `application:didRegisterForRemoteNotificationsWithDeviceToken:` is handled.
      OCMExpect([mockHandler1 setAPNSToken:_deviceToken]);
      [delegate application:_mockApplication
          didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
      OCMVerifyAll(mockHandler1);

      // Verify `application:didReceiveRemoteNotification:fetchCompletionHandler:` is NOT handled.
      OCMExpect([mockHandler1 canHandleNotification:_notification]).andReturn(NO);
      [delegate application:_mockApplication didReceiveRemoteNotification:_notification];
      OCMVerifyAll(mockHandler1);
      XCTAssertEqualObjects(delegate.notificationReceived, _notification);
      delegate.notificationReceived = nil;

      // Verify `application:openURL:sourceApplication:annotation:` is NOT handled.
      OCMExpect([mockHandler1 canHandleURL:_url]).andReturn(NO);
      XCTAssertFalse([delegate application:_mockApplication
                                   openURL:_url
                         sourceApplication:@"sourceApplication"
                                annotation:@"annotation"]);
      OCMVerifyAll(mockHandler1);
      XCTAssertEqualObjects(delegate.urlOpened, _url);
      delegate.urlOpened = nil;

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
    XCTAssertFalse([delegate application:_mockApplication
                                 openURL:_url
                       sourceApplication:@"sourceApplication"
                              annotation:@"annotation"]);
    XCTAssertEqualObjects(delegate.urlOpened, _url);
    delegate.urlOpened = nil;

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
  XCTAssertFalse([delegate application:_mockApplication
                               openURL:_url
                     sourceApplication:@"sourceApplication"
                            annotation:@"annotation"]);
  XCTAssertEqualObjects(delegate.urlOpened, _url);
  delegate.urlOpened = nil;
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

    // Verify certain methods are swizzled while others are not.
    XCTAssertTrue([delegate respondsToSelector:
                   @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)]);
    XCTAssertTrue([delegate respondsToSelector:
                   @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]);
    XCTAssertFalse([delegate respondsToSelector:
                    @selector(application:didReceiveRemoteNotification:)]);
    XCTAssertTrue([delegate respondsToSelector:@selector(application:openURL:options:)]);
    if (_isIOS9orLater) {
      XCTAssertFalse([delegate respondsToSelector:
                      @selector(application:openURL:sourceApplication:annotation:)]);
    } else {
      XCTAssertTrue([delegate respondsToSelector:
                     @selector(application:openURL:sourceApplication:annotation:)]);
    }
    XCTAssertFalse([delegate respondsToSelector:@selector(application:handleOpenURL:)]);

    // Verify the handler is called after being added.
    __weak id weakHandler;
    @autoreleasepool {
      id mockHandler = OCMProtocolMock(@protocol(FIRAuthAppDelegateHandler));
      [proxy addHandler:mockHandler];

      // Verify `application:didRegisterForRemoteNotificationsWithDeviceToken:` is handled.
      OCMExpect([mockHandler setAPNSToken:_deviceToken]);
      [delegate application:_mockApplication
          didRegisterForRemoteNotificationsWithDeviceToken:_deviceToken];
      OCMVerifyAll(mockHandler);
      XCTAssertEqualObjects(delegate.deviceTokenReceived, _deviceToken);
      delegate.deviceTokenReceived = nil;

      // Verify `application:didReceiveRemoteNotification:fetchCompletionHandler:` is handled.
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

      // Verify one of the `application:openURL:...` methods is handled.
      OCMExpect([mockHandler canHandleURL:_url]).andReturn(YES);
      if (_isIOS9orLater) {
        // Verify `application:openURL:options:` is handled.
        XCTAssertTrue([delegate application:_mockApplication openURL:_url options:@{}]);
      } else {
        // Verify `application:openURL:sourceApplication:annotation:` is handled.
        XCTAssertTrue([delegate application:_mockApplication
                                    openURL:_url
                          sourceApplication:@"sourceApplication"
                                 annotation:@"annotaton"]);
      }
      OCMVerifyAll(mockHandler);
      XCTAssertNil(delegate.urlOpened);

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
      XCTAssertFalse([unaffectedDelegate application:_mockApplication openURL:_url options:@{}]);
      XCTAssertEqualObjects(unaffectedDelegate.urlOpened, _url);
      unaffectedDelegate.urlOpened = nil;

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
    XCTAssertFalse([delegate application:_mockApplication openURL:_url options:@{}]);
    XCTAssertEqualObjects(delegate.urlOpened, _url);
    delegate.urlOpened = nil;

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
  XCTAssertFalse([delegate application:_mockApplication openURL:_url options:@{}]);
  XCTAssertEqualObjects(delegate.urlOpened, _url);
  delegate.urlOpened = nil;
}

/** @fn testOtherLegacyDelegateHandleOpenURL
    @brief Tests that the proxy works against another legacy @c UIApplicationDelegate for
        `application:handleOpenURL:`.
 */
- (void)testOtherLegacyDelegateHandleOpenURL {
  FIRAuthOtherLegacyAppDelegate *delegate = [[FIRAuthOtherLegacyAppDelegate alloc] init];
  OCMExpect([_mockApplication delegate]).andReturn(delegate);
  __weak id weakProxy;
  @autoreleasepool {
    FIRAuthAppDelegateProxy *proxy =
        [[FIRAuthAppDelegateProxy alloc] initWithApplication:_mockApplication];
    XCTAssertNotNil(proxy);

    // Verify certain methods are swizzled while others are not.
    XCTAssertFalse([delegate respondsToSelector:@selector(application:openURL:options:)]);
    XCTAssertFalse([delegate respondsToSelector:
                    @selector(application:openURL:sourceApplication:annotation:)]);
    XCTAssertTrue([delegate respondsToSelector:@selector(application:handleOpenURL:)]);

    // Verify the handler is called after being added.
    __weak id weakHandler;
    @autoreleasepool {
      id mockHandler = OCMProtocolMock(@protocol(FIRAuthAppDelegateHandler));
      [proxy addHandler:mockHandler];

      // Verify `application:handleOpenURL:` is handled.
      OCMExpect([mockHandler canHandleURL:_url]).andReturn(YES);
      XCTAssertTrue([delegate application:_mockApplication handleOpenURL:_url]);
      OCMVerifyAll(mockHandler);

      weakHandler = mockHandler;
      XCTAssertNotNil(weakHandler);
    }
    // Verify the handler is not retained by the proxy.
    XCTAssertNil(weakHandler);

    // Verify nothing bad happens after the handler is released.
    XCTAssertFalse([delegate application:_mockApplication handleOpenURL:_url]);
    XCTAssertEqualObjects(delegate.urlOpened, _url);
    delegate.urlOpened = nil;

    weakProxy = proxy;
    XCTAssertNotNil(weakProxy);
  }
  // Verify the proxy does not retain itself.
  XCTAssertNil(weakProxy);
  // Verify nothing bad happens after the proxy is released.
  XCTAssertFalse([delegate application:_mockApplication handleOpenURL:_url]);
  XCTAssertEqualObjects(delegate.urlOpened, _url);
  delegate.urlOpened = nil;
}

#pragma clang diagnostic pop  // ignored "-Wdeprecated-declarations"

@end

NS_ASSUME_NONNULL_END
