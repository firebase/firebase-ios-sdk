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

#import <OCMock/OCMock.h>
#import <UserNotifications/UserNotifications.h>
#import <XCTest/XCTest.h>

#import <GoogleUtilities/GULAppDelegateSwizzler.h>
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"

#import "FirebaseMessaging/Sources/FIRMessagingRemoteNotificationsProxy.h"

#pragma mark - Invalid App Delegate or UNNotificationCenter

@interface RandomObject : NSObject
@property(nonatomic, weak) id delegate;
@end
@implementation RandomObject
- (void)application:(GULApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo {
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:
             (void (^)(UNNotificationPresentationOptions options))completionHandler
    API_AVAILABLE(ios(10.0), macos(10.14), tvos(10.0)) {
}

#if !TARGET_OS_TV
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    didReceiveNotificationResponse:(UNNotificationResponse *)response
             withCompletionHandler:(void (^)(void))completionHandler
    API_AVAILABLE(macos(10.14), ios(10.0)) {
}
#endif  // !TARGET_OS_TV

@end

#pragma mark - Incomplete App Delegate
@interface IncompleteAppDelegate : NSObject <GULApplicationDelegate>
@end
@implementation IncompleteAppDelegate
@end

#pragma mark - Fake AppDelegate
@interface FakeAppDelegate : NSObject <GULApplicationDelegate>
@property(nonatomic) BOOL remoteNotificationMethodWasCalled;
@property(nonatomic) BOOL remoteNotificationWithFetchHandlerWasCalled;
@property(nonatomic, strong) NSData *deviceToken;
@property(nonatomic, strong) NSError *registerForRemoteNotificationsError;
@end
@implementation FakeAppDelegate

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  self.remoteNotificationWithFetchHandlerWasCalled = YES;
  completionHandler(UIBackgroundFetchResultNewData);
}
#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION

- (void)application:(GULApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  self.deviceToken = deviceToken;
}

- (void)application:(GULApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  self.registerForRemoteNotificationsError = error;
}

@end

#pragma mark - Incomplete UNUserNotificationCenterDelegate
@interface IncompleteUserNotificationCenterDelegate : NSObject <UNUserNotificationCenterDelegate>
@end
@implementation IncompleteUserNotificationCenterDelegate
@end

#pragma mark - Fake UNUserNotificationCenterDelegate

@interface FakeUserNotificationCenterDelegate : NSObject <UNUserNotificationCenterDelegate>
@property(nonatomic) BOOL willPresentWasCalled;
@property(nonatomic) BOOL didReceiveResponseWasCalled;
@end
@implementation FakeUserNotificationCenterDelegate
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:
             (void (^)(UNNotificationPresentationOptions options))completionHandler
    API_AVAILABLE(ios(10.0), macos(10.14), tvos(10.0)) {
  self.willPresentWasCalled = YES;
}
#if !TARGET_OS_TV
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    didReceiveNotificationResponse:(UNNotificationResponse *)response
             withCompletionHandler:(void (^)(void))completionHandler
    API_AVAILABLE(ios(10.0), macos(10.14)) {
  self.didReceiveResponseWasCalled = YES;
}
#endif  // !TARGET_OS_TV
@end

@interface GULAppDelegateSwizzler (FIRMessagingRemoteNotificationsProxyTest)
+ (void)resetProxyOriginalDelegateOnceToken;
@end

#pragma mark - Local, Per-Test Properties

@interface FIRMessagingRemoteNotificationsProxyTest : XCTestCase

@property(nonatomic, strong) FIRMessagingRemoteNotificationsProxy *proxy;
@property(nonatomic, strong) id mockProxyClass;
@property(nonatomic, strong) id mockMessaging;
@property(nonatomic, strong) id mockUserNotificationCenter;

@end

@implementation FIRMessagingRemoteNotificationsProxyTest

- (void)setUp {
  [super setUp];

  [GULAppDelegateSwizzler resetProxyOriginalDelegateOnceToken];

  _mockMessaging = OCMClassMock([FIRMessaging class]);
  OCMStub([_mockMessaging messaging]).andReturn(_mockMessaging);

  _proxy = [[FIRMessagingRemoteNotificationsProxy alloc] init];
  _mockProxyClass = OCMClassMock([FIRMessagingRemoteNotificationsProxy class]);
  // Update +sharedProxy to always return our test instance
  OCMStub([_mockProxyClass sharedProxy]).andReturn(self.proxy);
  if (@available(macOS 10.14, iOS 10.0, *)) {
    _mockUserNotificationCenter = OCMClassMock([UNUserNotificationCenter class]);
    OCMStub([_mockUserNotificationCenter currentNotificationCenter])
        .andReturn(_mockUserNotificationCenter);
  }
}

- (void)tearDown {
  [_mockProxyClass stopMocking];
  _mockProxyClass = nil;

  [_mockMessaging stopMocking];
  _mockMessaging = nil;

  if (@available(macOS 10.14, iOS 10.0, *)) {
    [_mockUserNotificationCenter stopMocking];
    _mockUserNotificationCenter = nil;
  }

  _proxy = nil;
  [super tearDown];
}

#pragma mark - Method Swizzling Tests
#if !TARGET_OS_WATCH  // TODO(chliangGoogle) Figure out why WKExtension is not recognized here.
- (void)testSwizzlingNonAppDelegate {
  RandomObject *invalidAppDelegate = [[RandomObject alloc] init];
  [[GULAppDelegateSwizzler sharedApplication]
      setDelegate:(id<GULApplicationDelegate>)invalidAppDelegate];
  [self.proxy swizzleMethodsIfPossible];

  OCMReject([self.mockMessaging appDidReceiveMessage:[OCMArg any]]);

  [invalidAppDelegate application:[GULAppDelegateSwizzler sharedApplication]
      didReceiveRemoteNotification:@{}];
}
#endif  // !TARGET_OS_WATCH

#if !SWIFT_PACKAGE
// The next 3 tests depend on a sharedApplication which is not available in the Swift PM test env.
- (void)testSwizzledIncompleteAppDelegateRemoteNotificationMethod {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];
  IncompleteAppDelegate *incompleteAppDelegate = [[IncompleteAppDelegate alloc] init];
  [[GULAppDelegateSwizzler sharedApplication] setDelegate:incompleteAppDelegate];
  [self.proxy swizzleMethodsIfPossible];

  NSDictionary *notification = @{@"test" : @""};
  OCMExpect([self.mockMessaging appDidReceiveMessage:notification]);

  [incompleteAppDelegate application:[GULAppDelegateSwizzler sharedApplication]
        didReceiveRemoteNotification:notification
              fetchCompletionHandler:^(UIBackgroundFetchResult result) {
                [expectation fulfill];
              }];

  [self.mockMessaging verify];
  [self waitForExpectationsWithTimeout:0.5 handler:nil];
}

// This test demonstrates the difference between Firebase 10 and 11. In 10 and earlier the
// swizzler inserts the old `didReceiveRemoteNotification` method. In 11, the new.
- (void)testIncompleteAppDelegateRemoteNotificationWithFetchHandlerMethod {
  IncompleteAppDelegate *incompleteAppDelegate = [[IncompleteAppDelegate alloc] init];
  [[GULAppDelegateSwizzler sharedApplication] setDelegate:incompleteAppDelegate];
  [self.proxy swizzleMethodsIfPossible];

#if TARGET_OS_IOS || TARGET_OS_TV
  SEL remoteNotificationWithFetchHandler = @selector(application:
                                    didReceiveRemoteNotification:fetchCompletionHandler:);
  XCTAssertTrue([incompleteAppDelegate respondsToSelector:remoteNotificationWithFetchHandler]);
#endif  // TARGET_OS_IOS || TARGET_OS_TV

  SEL remoteNotification = @selector(application:didReceiveRemoteNotification:);
  XCTAssertFalse([incompleteAppDelegate respondsToSelector:remoteNotification]);
}

- (void)testSwizzledAppDelegateRemoteNotificationMethods {
  FakeAppDelegate *appDelegate = [[FakeAppDelegate alloc] init];
  [[GULAppDelegateSwizzler sharedApplication] setDelegate:appDelegate];
  [self.proxy swizzleMethodsIfPossible];

  NSDictionary *notification = @{@"test" : @""};

  // Test application:didReceiveRemoteNotification:fetchCompletionHandler:
#if TARGET_OS_IOS || TARGET_OS_TV
  // Verify our swizzled method was called
  OCMExpect([self.mockMessaging appDidReceiveMessage:notification]);

  [appDelegate application:[GULAppDelegateSwizzler sharedApplication]
      didReceiveRemoteNotification:notification
            fetchCompletionHandler:^(UIBackgroundFetchResult result) {
              XCTAssertEqual(result, UIBackgroundFetchResultNewData);
            }];

  // Verify our original method was called
  XCTAssertTrue(appDelegate.remoteNotificationWithFetchHandlerWasCalled);

  [self.mockMessaging verify];
#endif  // TARGET_OS_IOS || TARGET_OS_TV

  // Verify application:didRegisterForRemoteNotificationsWithDeviceToken:
  NSData *deviceToken = [NSData data];

  OCMExpect([self.mockMessaging setAPNSToken:deviceToken]);

  [appDelegate application:[GULAppDelegateSwizzler sharedApplication]
      didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];

  XCTAssertEqual(appDelegate.deviceToken, deviceToken);
  [self.mockMessaging verify];

  // Verify application:didFailToRegisterForRemoteNotificationsWithError:
  NSError *error = [NSError errorWithDomain:@"tests" code:-1 userInfo:nil];

  [appDelegate application:[GULAppDelegateSwizzler sharedApplication]
      didFailToRegisterForRemoteNotificationsWithError:error];

  XCTAssertEqual(appDelegate.registerForRemoteNotificationsError, error);
}
#endif  // !SWIFT_PACKAGE

- (void)testListeningForDelegateChangesOnInvalidUserNotificationCenter {
  if (@available(macOS 10.14, iOS 10.0, *)) {
    RandomObject *invalidNotificationCenter = [[RandomObject alloc] init];
    OCMStub([self.mockUserNotificationCenter currentNotificationCenter])
        .andReturn(invalidNotificationCenter);
    [self.proxy swizzleMethodsIfPossible];

    OCMReject([self.mockMessaging appDidReceiveMessage:[OCMArg any]]);

    [(id<UNUserNotificationCenterDelegate>)invalidNotificationCenter.delegate
         userNotificationCenter:self.mockUserNotificationCenter
        willPresentNotification:[UNNotification alloc]
          withCompletionHandler:^(UNNotificationPresentationOptions options){
          }];
  }
}

- (void)testSwizzlingInvalidUserNotificationCenterDelegate {
  if (@available(macOS 10.14, iOS 10.0, *)) {
    RandomObject *invalidDelegate = [[RandomObject alloc] init];
    OCMStub([self.mockUserNotificationCenter delegate]).andReturn(invalidDelegate);
    [self.proxy swizzleMethodsIfPossible];

    OCMReject([self.mockMessaging appDidReceiveMessage:[OCMArg any]]);

    [invalidDelegate userNotificationCenter:self.mockUserNotificationCenter
                    willPresentNotification:[UNNotification alloc]
                      withCompletionHandler:^(UNNotificationPresentationOptions options){
                      }];
  }
}

// Use a fake delegate that doesn't actually implement the needed delegate method.
// Our swizzled method should not be called.

- (void)testIncompleteUserNotificationCenterDelegateMethod {
  if (@available(macOS 10.14, iOS 10.0, *)) {
    IncompleteUserNotificationCenterDelegate *delegate =
        [[IncompleteUserNotificationCenterDelegate alloc] init];
    OCMStub([self.mockUserNotificationCenter delegate]).andReturn(delegate);
    [self.proxy swizzleMethodsIfPossible];
    // Because the incomplete delete does not implement either of the optional delegate methods, we
    // should swizzle nothing. If we had swizzled them, then respondsToSelector: would return YES
    // even though the delegate does not implement the methods.
    SEL willPresentSelector = @selector(userNotificationCenter:
                                       willPresentNotification:withCompletionHandler:);
    XCTAssertFalse([delegate respondsToSelector:willPresentSelector]);
    SEL didReceiveResponseSelector = @selector(userNotificationCenter:
                                       didReceiveNotificationResponse:withCompletionHandler:);
    XCTAssertFalse([delegate respondsToSelector:didReceiveResponseSelector]);
  }
}

// Use an object that does actually implement the optional methods. Both should be called.
- (void)testSwizzledUserNotificationsCenterDelegate {
#if !TARGET_OS_TV
  FakeUserNotificationCenterDelegate *delegate = [[FakeUserNotificationCenterDelegate alloc] init];
  OCMStub([self.mockUserNotificationCenter delegate]).andReturn(delegate);
  [self.proxy swizzleMethodsIfPossible];

  NSDictionary *message = @{@"message" : @""};

  // Verify userNotificationCenter:willPresentNotification:withCompletionHandler:
  OCMExpect([self.mockMessaging appDidReceiveMessage:message]);
  if (@available(macOS 10.14, iOS 10.0, tvOS 10.0, *)) {
    // Invoking delegate method should also invoke our swizzled method
    // The swizzled method uses the +sharedProxy, which should be
    // returning our proxy.
    // Use non-nil, proper classes, otherwise our SDK bails out.
    [delegate userNotificationCenter:self.mockUserNotificationCenter
             willPresentNotification:[self userNotificationWithMessage:message]
               withCompletionHandler:^(NSUInteger options){
               }];

    // Verify our original method was called
    XCTAssertTrue(delegate.willPresentWasCalled);

    // Verify our swizzled method was called
    [self.mockMessaging verify];
  }

  if (@available(macOS 10.14, iOS 10.0, *)) {
    // Verify userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:
    OCMExpect([self.mockMessaging appDidReceiveMessage:message]);
    [delegate userNotificationCenter:self.mockUserNotificationCenter
        didReceiveNotificationResponse:[self userNotificationResponseWithMessage:message]
                 withCompletionHandler:^{
                 }];

    // Verify our original method was called
    XCTAssertTrue(delegate.didReceiveResponseWasCalled);

    // Verify our swizzled method was called
    [self.mockMessaging verify];
  }
#endif  // !TARGET_OS_TV
}

- (id)userNotificationResponseWithMessage:(NSDictionary *)message {
#if !TARGET_OS_TV
  if (@available(macOS 10.14, iOS 10.0, *)) {
    // Stub out: response.[mock notification above]
    id mockNotificationResponse = OCMClassMock([UNNotificationResponse class]);
    id mockNotification = [self userNotificationWithMessage:message];
    OCMStub([mockNotificationResponse notification]).andReturn(mockNotification);
    return mockNotificationResponse;
  }
#endif  // !TARGET_OS_TV
  return nil;
}

- (UNNotification *)userNotificationWithMessage:(NSDictionary *)message
    API_AVAILABLE(macos(10.14), ios(10.0)) {
  UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
#if !TARGET_OS_TV
  content.userInfo = message;
#endif  // !TARGET_OS_TV
  id notificationRequest = OCMClassMock([UNNotificationRequest class]);
  OCMStub([notificationRequest content]).andReturn(content);
  id notification = OCMClassMock([UNNotification class]);
  OCMStub([notification request]).andReturn(notificationRequest);
  return notification;
}

@end
