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

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
#import <UserNotifications/UserNotifications.h>
#endif
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "FIRMessaging.h"
#import "FIRMessagingRemoteNotificationsProxy.h"

#import <GoogleUtilities/GULAppDelegateSwizzler.h>

#pragma mark - Invalid App Delegate or UNNotificationCenter

@interface RandomObject : NSObject
@property(nonatomic, weak) id delegate;
@end
@implementation RandomObject
#if TARGET_OS_IOS || TARGET_OS_TV
- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
}
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))
completionHandler {
}
#endif // __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

#if TARGET_OS_IOS
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void(^)(void))completionHandler {
}
#endif // TARGET_OS_IOS

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
#if TARGET_OS_IOS
- (void)application:(GULApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo {
  self.remoteNotificationMethodWasCalled = YES;
}
#endif

#if TARGET_OS_IOS || TARGET_OS_TV
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  self.remoteNotificationWithFetchHandlerWasCalled = YES;
}
#endif

- (void)application:(GULApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  self.deviceToken = deviceToken;
}

- (void)application:(GULApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  self.registerForRemoteNotificationsError = error;
}

@end

#pragma mark - Incompete UNUserNotificationCenterDelegate
@interface IncompleteUserNotificationCenterDelegate : NSObject <UNUserNotificationCenterDelegate>
@end
@implementation IncompleteUserNotificationCenterDelegate
@end

#pragma mark - Fake UNUserNotificationCenterDelegate

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface FakeUserNotificationCenterDelegate : NSObject <UNUserNotificationCenterDelegate>
@property(nonatomic) BOOL willPresentWasCalled;
@property(nonatomic) BOOL didReceiveResponseWasCalled;
@end
@implementation FakeUserNotificationCenterDelegate
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))
    completionHandler {
  self.willPresentWasCalled = YES;
}
#if TARGET_OS_IOS
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {
  self.didReceiveResponseWasCalled = YES;
}
#endif // TARGET_OS_IOS
@end
#endif // __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

@interface GULAppDelegateSwizzler (FIRMessagingRemoteNotificationsProxyTest)
+ (void)resetProxyOriginalDelegateOnceToken;
@end

#pragma mark - Local, Per-Test Properties

@interface FIRMessagingRemoteNotificationsProxyTest : XCTestCase

@property(nonatomic, strong) FIRMessagingRemoteNotificationsProxy *proxy;
@property(nonatomic, strong) id mockProxyClass;
@property(nonatomic, strong) id mockSharedApplication;
@property(nonatomic, strong) id mockMessaging;
@property(nonatomic, strong) id mockUserNotificationCenter;

@end

@implementation FIRMessagingRemoteNotificationsProxyTest

- (void)setUp {
  [super setUp];

  [GULAppDelegateSwizzler resetProxyOriginalDelegateOnceToken];

  _mockSharedApplication = OCMPartialMock([GULApplication sharedApplication]);

  _mockMessaging = OCMClassMock([FIRMessaging class]);
  OCMStub([_mockMessaging messaging]).andReturn(_mockMessaging);

  _proxy = [[FIRMessagingRemoteNotificationsProxy alloc] init];
  _mockProxyClass = OCMClassMock([FIRMessagingRemoteNotificationsProxy class]);
  // Update +sharedProxy to always return our test instance
  OCMStub([_mockProxyClass sharedProxy]).andReturn(self.proxy);

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
  _mockUserNotificationCenter = OCMPartialMock([UNUserNotificationCenter currentNotificationCenter]);
#endif
}

- (void)tearDown {
  [_mockProxyClass stopMocking];
  _mockProxyClass = nil;

  [_mockMessaging stopMocking];
  _mockMessaging = nil;

  [_mockSharedApplication stopMocking];
  _mockSharedApplication = nil;

  [_mockUserNotificationCenter stopMocking];
  _mockUserNotificationCenter = nil;

  _proxy = nil;
  [super tearDown];
}

#pragma mark - Method Swizzling Tests

- (void)testSwizzlingNonAppDelegate {
#if TARGET_OS_IOS || TARGET_OS_TV
  RandomObject *invalidAppDelegate = [[RandomObject alloc] init];
  [OCMStub([self.mockSharedApplication delegate]) andReturn:invalidAppDelegate];
  [self.proxy swizzleMethodsIfPossible];

  OCMReject([self.mockMessaging appDidReceiveMessage:[OCMArg any]]);

  [invalidAppDelegate application:self.mockSharedApplication
     didReceiveRemoteNotification:@{}
           fetchCompletionHandler:^(UIBackgroundFetchResult result) {}];
#endif
}

- (void)testSwizzledIncompleteAppDelegateRemoteNotificationMethod {
#if TARGET_OS_IOS
  IncompleteAppDelegate *incompleteAppDelegate = [[IncompleteAppDelegate alloc] init];
  [OCMStub([self.mockSharedApplication delegate]) andReturn:incompleteAppDelegate];
  [self.proxy swizzleMethodsIfPossible];

  NSDictionary *notification = @{@"test" : @""};
  OCMExpect([self.mockMessaging appDidReceiveMessage:notification]);

  [incompleteAppDelegate application:self.mockSharedApplication
        didReceiveRemoteNotification:notification];

  [self.mockMessaging verify];
#endif // TARGET_OS_IOS
}

- (void)testIncompleteAppDelegateRemoteNotificationWithFetchHandlerMethod {
  IncompleteAppDelegate *incompleteAppDelegate = [[IncompleteAppDelegate alloc] init];
  [OCMStub([self.mockSharedApplication delegate]) andReturn:incompleteAppDelegate];
  [self.proxy swizzleMethodsIfPossible];

  SEL remoteNotificationWithFetchHandler =
      @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:);
  XCTAssertFalse([incompleteAppDelegate respondsToSelector:remoteNotificationWithFetchHandler]);

#if TARGET_OS_IOS
  SEL remoteNotification = @selector(application:didReceiveRemoteNotification:);
  XCTAssertTrue([incompleteAppDelegate respondsToSelector:remoteNotification]);
#endif // TARGET_OS_IOS
}

- (void)testSwizzledAppDelegateRemoteNotificationMethods {
  FakeAppDelegate *appDelegate = [[FakeAppDelegate alloc] init];
  [OCMStub([self.mockSharedApplication delegate]) andReturn:appDelegate];
  [self.proxy swizzleMethodsIfPossible];
    
#if TARGET_OS_IOS || TARGET_OS_TV
  NSDictionary *notification = @{@"test" : @""};

  //Test application:didReceiveRemoteNotification:

  // Verify our swizzled method was called
  OCMExpect([self.mockMessaging appDidReceiveMessage:notification]);

  // Call the method
  [appDelegate application:self.mockSharedApplication
        didReceiveRemoteNotification:notification];

  // Verify our original method was called
  XCTAssertTrue(appDelegate.remoteNotificationMethodWasCalled);
  [self.mockMessaging verify];

  //Test application:didReceiveRemoteNotification:fetchCompletionHandler:

  // Verify our swizzled method was called
  OCMExpect([self.mockMessaging appDidReceiveMessage:notification]);

  [appDelegate application:self.mockSharedApplication
      didReceiveRemoteNotification:notification
      fetchCompletionHandler:^(UIBackgroundFetchResult result) {}];

  // Verify our original method was called
  XCTAssertTrue(appDelegate.remoteNotificationWithFetchHandlerWasCalled);

  [self.mockMessaging verify];
#endif

  // Verify application:didRegisterForRemoteNotificationsWithDeviceToken:
  NSData *deviceToken = [NSData data];

  OCMExpect([self.mockMessaging setAPNSToken:deviceToken]);

  [appDelegate application:self.mockSharedApplication
      didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];

  XCTAssertEqual(appDelegate.deviceToken, deviceToken);
  [self.mockMessaging verify];

  // Verify application:didFailToRegisterForRemoteNotificationsWithError:
  NSError *error = [NSError errorWithDomain:@"tests" code:-1 userInfo:nil];

  [appDelegate application:self.mockSharedApplication
      didFailToRegisterForRemoteNotificationsWithError:error];

  XCTAssertEqual(appDelegate.registerForRemoteNotificationsError, error);

}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

- (void)testListeningForDelegateChangesOnInvalidUserNotificationCenter {
  RandomObject *invalidNotificationCenter = [[RandomObject alloc] init];
  OCMStub([self.mockUserNotificationCenter currentNotificationCenter]).andReturn(invalidNotificationCenter);
  [self.proxy swizzleMethodsIfPossible];

  OCMReject([self.mockMessaging appDidReceiveMessage:[OCMArg any]]);

  [(id<UNUserNotificationCenterDelegate>)invalidNotificationCenter.delegate
   userNotificationCenter:self.mockUserNotificationCenter
   willPresentNotification:OCMClassMock([UNNotification class])
   withCompletionHandler:^(UNNotificationPresentationOptions options) {
   }];
}

- (void)testSwizzlingInvalidUserNotificationCenterDelegate {
  RandomObject *invalidDelegate = [[RandomObject alloc] init];
  OCMStub([self.mockUserNotificationCenter delegate]).andReturn(invalidDelegate);
  [self.proxy swizzleMethodsIfPossible];

  OCMReject([self.mockMessaging appDidReceiveMessage:[OCMArg any]]);

  [invalidDelegate
   userNotificationCenter:self.mockUserNotificationCenter
   willPresentNotification:OCMClassMock([UNNotification class])
   withCompletionHandler:^(UNNotificationPresentationOptions options) {
   }];
}

- (void)testSwizzlingUserNotificationsCenterDelegate {
  FakeUserNotificationCenterDelegate *delegate = [[FakeUserNotificationCenterDelegate alloc] init];
  OCMStub([self.mockUserNotificationCenter delegate]).andReturn(delegate);
  [self.proxy swizzleMethodsIfPossible];

  NSDictionary *message = @{@"message": @""};
  id notification = [self userNotificationWithMessage:message];

  OCMExpect([self.mockMessaging appDidReceiveMessage:message]);

  [delegate
   userNotificationCenter:self.mockUserNotificationCenter
   willPresentNotification:notification
   withCompletionHandler:^(UNNotificationPresentationOptions options) {
   }];

  [self.mockMessaging verify];
}

// Use a fake delegate that doesn't actually implement the needed delegate method.
// Our swizzled method should not be called.

- (void)testIncompleteUserNotificationCenterDelegateMethod {
  // Early exit if running on pre iOS 10
  if (![UNNotification class]) {
    return;
  }
  IncompleteUserNotificationCenterDelegate *delegate =
      [[IncompleteUserNotificationCenterDelegate alloc] init];
  OCMStub([self.mockUserNotificationCenter delegate]).andReturn(delegate);
  [self.proxy swizzleMethodsIfPossible];
  // Because the incomplete delete does not implement either of the optional delegate methods, we
  // should swizzle nothing. If we had swizzled them, then respondsToSelector: would return YES
  // even though the delegate does not implement the methods.
  SEL willPresentSelector = @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:);
  XCTAssertFalse([delegate respondsToSelector:willPresentSelector]);
  SEL didReceiveResponseSelector =
      @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:);
  XCTAssertFalse([delegate respondsToSelector:didReceiveResponseSelector]);
}

// Use an object that does actually implement the optional methods. Both should be called.
- (void)testSwizzledUserNotificationsCenterDelegate {
  FakeUserNotificationCenterDelegate *delegate = [[FakeUserNotificationCenterDelegate alloc] init];
  OCMStub([self.mockUserNotificationCenter delegate]).andReturn(delegate);
  [self.proxy swizzleMethodsIfPossible];

  NSDictionary *message = @{@"message": @""};

  // Verify userNotificationCenter:willPresentNotification:withCompletionHandler:
  OCMExpect([self.mockMessaging appDidReceiveMessage:message]);

  // Invoking delegate method should also invoke our swizzled method
  // The swizzled method uses the +sharedProxy, which should be
  // returning our proxy.
  // Use non-nil, proper classes, otherwise our SDK bails out.
  [delegate userNotificationCenter:self.mockUserNotificationCenter
           willPresentNotification:[self userNotificationWithMessage:message]
             withCompletionHandler:^(NSUInteger options) {}];

  // Verify our original method was called
  XCTAssertTrue(delegate.willPresentWasCalled);

  // Verify our swizzled method was called
  [self.mockMessaging verify];

#if TARGET_OS_IOS
  // Verify userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:

  OCMExpect([self.mockMessaging appDidReceiveMessage:message]);

  [delegate userNotificationCenter:self.mockUserNotificationCenter
    didReceiveNotificationResponse:[self userNotificationResponseWithMessage:message]
             withCompletionHandler:^{}];

  // Verify our original method was called
  XCTAssertTrue(delegate.didReceiveResponseWasCalled);

  // Verify our swizzled method was called
  [self.mockMessaging verify];
#endif // TARGET_OS_IOS
}

- (id)userNotificationResponseWithMessage:(NSDictionary *)message {
  // Stub out: response.[mock notification above]
#if TARGET_OS_IOS
  id mockNotificationResponse = OCMClassMock([UNNotificationResponse class]);
  id mockNotification = [self userNotificationWithMessage:message];
  OCMStub([mockNotificationResponse notification]).andReturn(mockNotification);
  return mockNotificationResponse;
#else // TARGET_OS_IOS
  return nil;
#endif // TARGET_OS_IOS
}

- (UNNotification *)userNotificationWithMessage:(NSDictionary *)message {
  UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
  content.userInfo = message;
  id notificationRequest = OCMClassMock([UNNotificationRequest class]);
  OCMStub([notificationRequest content]).andReturn(content);
  id notification = OCMClassMock([UNNotification class]);
  OCMStub([notification request]).andReturn(notificationRequest);

  return notification;
}

#endif // __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

@end
