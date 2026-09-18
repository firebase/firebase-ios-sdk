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
#import <XCTest/XCTest.h>

#import <GoogleUtilities/GULUserDefaults.h>
#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingTestNotificationUtilities.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingTestUtilities.h"

NSString *const kFIRMessagingTestsLinkHandlingSuiteName = @"com.messaging.test_linkhandling";

@interface FIRMessaging ()

- (NSURL *)linkURLFromMessage:(NSDictionary *)message;
- (void)handleIncomingLinkIfNeededFromMessage:(NSDictionary *)message;

@end

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION

#import <GoogleUtilities/GULAppDelegateSwizzler.h>
#import <UIKit/UIKit.h>

@interface FakeLinkHandlingSceneDelegate : NSObject <UISceneDelegate>
@property(nonatomic, strong, nullable) UIScene *scene;
@property(nonatomic, strong, nullable) NSUserActivity *userActivity;
@property(nonatomic) BOOL continueUserActivityWasCalled;
@end

@implementation FakeLinkHandlingSceneDelegate
- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity {
  self.scene = scene;
  self.userActivity = userActivity;
  self.continueUserActivityWasCalled = YES;
}
@end

@interface FakeLinkHandlingNonRespondingSceneDelegate : NSObject <UISceneDelegate>
@end

@implementation FakeLinkHandlingNonRespondingSceneDelegate
@end

@interface FakeLinkHandlingAppDelegate : NSObject <UIApplicationDelegate>
@property(nonatomic, strong, nullable) UIApplication *application;
@property(nonatomic, strong, nullable) NSUserActivity *userActivity;
@property(nonatomic) BOOL continueUserActivityWasCalled;
@end

@implementation FakeLinkHandlingAppDelegate
- (BOOL)application:(UIApplication *)application
    continueUserActivity:(NSUserActivity *)userActivity
      restorationHandler:
          (void (^)(NSArray<id<UIUserActivityRestoring>> *_Nullable restorableObjects))
              restorationHandler {
  self.application = application;
  self.userActivity = userActivity;
  self.continueUserActivityWasCalled = YES;
  return YES;
}
@end

@interface FakeLinkHandlingNonRespondingAppDelegate : NSObject <UIApplicationDelegate>
@end

@implementation FakeLinkHandlingNonRespondingAppDelegate
@end

#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION

@interface FIRMessagingLinkHandlingTest : XCTestCase

@property(nonatomic, readonly, strong) FIRMessaging *messaging;
@property(nonatomic, strong) FIRMessagingTestUtilities *testUtil;

@end

@implementation FIRMessagingLinkHandlingTest

- (void)setUp {
  [super setUp];

  NSUserDefaults *defaults =
      [[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingTestsLinkHandlingSuiteName];
  _testUtil = [[FIRMessagingTestUtilities alloc] initWithUserDefaults:defaults withRMQManager:NO];
  _messaging = _testUtil.messaging;
}

- (void)tearDown {
  [_testUtil cleanupAfterTest:self];
  _messaging = nil;
  [[[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingTestsLinkHandlingSuiteName]
      removePersistentDomainForName:kFIRMessagingTestsLinkHandlingSuiteName];
  [super tearDown];
}

#pragma mark - Link Handling Testing

- (void)testNonExistentLinkInMessage {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  NSURL *url = [_messaging linkURLFromMessage:notification];
  XCTAssertNil(url);
}

- (void)testEmptyLinkInMessage {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  notification[kFIRMessagingMessageLinkKey] = @"";
  NSURL *url = [_messaging linkURLFromMessage:notification];
  XCTAssertNil(url);
}

- (void)testNonStringLinkInMessage {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  notification[kFIRMessagingMessageLinkKey] = @(5);
  NSURL *url = [_messaging linkURLFromMessage:notification];
  XCTAssertNil(url);
}

- (void)testValidURLStringLinkInMessage {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  notification[kFIRMessagingMessageLinkKey] = @"https://www.google.com/";
  NSURL *url = [_messaging linkURLFromMessage:notification];
  XCTAssertTrue([url.absoluteString isEqualToString:@"https://www.google.com/"]);
}

#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION

- (void)testHandleIncomingLink_sceneDelegateHandlesUserActivity {
  id mockApplication = OCMClassMock([UIApplication class]);
  OCMStub([mockApplication sharedApplication]).andReturn(mockApplication);

  FakeLinkHandlingSceneDelegate *fakeSceneDelegate = [[FakeLinkHandlingSceneDelegate alloc] init];
  id mockScene = OCMClassMock([UIScene class]);
  OCMStub([mockScene delegate]).andReturn(fakeSceneDelegate);
  OCMStub([mockScene activationState]).andReturn(UISceneActivationStateForegroundActive);

  FakeLinkHandlingAppDelegate *fakeAppDelegate = [[FakeLinkHandlingAppDelegate alloc] init];
  OCMStub([mockApplication delegate]).andReturn(fakeAppDelegate);
  OCMStub([mockApplication connectedScenes]).andReturn([NSSet setWithObject:mockScene]);

  NSDictionary *notification = @{kFIRMessagingMessageLinkKey : @"https://www.google.com/"};
  [_messaging handleIncomingLinkIfNeededFromMessage:notification];

  XCTAssertTrue(fakeSceneDelegate.continueUserActivityWasCalled);
  XCTAssertEqual(fakeSceneDelegate.scene, mockScene);
  XCTAssertEqualObjects(fakeSceneDelegate.userActivity.webpageURL.absoluteString,
                        @"https://www.google.com/");
  XCTAssertEqualObjects(fakeSceneDelegate.userActivity.activityType,
                        @"NSUserActivityTypeBrowsingWeb");
  XCTAssertFalse(fakeAppDelegate.continueUserActivityWasCalled);

  [mockApplication stopMocking];
  [mockScene stopMocking];
}

- (void)testHandleIncomingLink_fallbackToAppDelegateWhenNoMatchingScene {
  id mockApplication = OCMClassMock([UIApplication class]);
  OCMStub([mockApplication sharedApplication]).andReturn(mockApplication);

  FakeLinkHandlingNonRespondingSceneDelegate *fakeSceneDelegate =
      [[FakeLinkHandlingNonRespondingSceneDelegate alloc] init];
  id mockScene = OCMClassMock([UIScene class]);
  OCMStub([mockScene delegate]).andReturn(fakeSceneDelegate);
  OCMStub([mockScene activationState]).andReturn(UISceneActivationStateForegroundActive);

  FakeLinkHandlingAppDelegate *fakeAppDelegate = [[FakeLinkHandlingAppDelegate alloc] init];
  OCMStub([mockApplication delegate]).andReturn(fakeAppDelegate);
  OCMStub([mockApplication connectedScenes]).andReturn([NSSet setWithObject:mockScene]);

  NSDictionary *notification = @{kFIRMessagingMessageLinkKey : @"https://www.google.com/"};
  [_messaging handleIncomingLinkIfNeededFromMessage:notification];

  XCTAssertTrue(fakeAppDelegate.continueUserActivityWasCalled);
  XCTAssertEqual(fakeAppDelegate.application, mockApplication);
  XCTAssertEqualObjects(fakeAppDelegate.userActivity.webpageURL.absoluteString,
                        @"https://www.google.com/");
  XCTAssertEqualObjects(fakeAppDelegate.userActivity.activityType,
                        @"NSUserActivityTypeBrowsingWeb");

  [mockApplication stopMocking];
  [mockScene stopMocking];
}

- (void)testHandleIncomingLink_fallbackToAppDelegateWhenConnectedScenesEmpty {
  id mockApplication = OCMClassMock([UIApplication class]);
  OCMStub([mockApplication sharedApplication]).andReturn(mockApplication);

  FakeLinkHandlingAppDelegate *fakeAppDelegate = [[FakeLinkHandlingAppDelegate alloc] init];
  OCMStub([mockApplication delegate]).andReturn(fakeAppDelegate);
  OCMStub([mockApplication connectedScenes]).andReturn([NSSet set]);

  NSDictionary *notification = @{kFIRMessagingMessageLinkKey : @"https://www.google.com/"};
  [_messaging handleIncomingLinkIfNeededFromMessage:notification];

  XCTAssertTrue(fakeAppDelegate.continueUserActivityWasCalled);
  XCTAssertEqual(fakeAppDelegate.application, mockApplication);
  XCTAssertEqualObjects(fakeAppDelegate.userActivity.webpageURL.absoluteString,
                        @"https://www.google.com/");

  [mockApplication stopMocking];
}

- (void)testHandleIncomingLink_noThrowWhenNeitherResponds {
  id mockApplication = OCMClassMock([UIApplication class]);
  OCMStub([mockApplication sharedApplication]).andReturn(mockApplication);

  FakeLinkHandlingNonRespondingAppDelegate *fakeAppDelegate =
      [[FakeLinkHandlingNonRespondingAppDelegate alloc] init];
  OCMStub([mockApplication delegate]).andReturn(fakeAppDelegate);
  OCMStub([mockApplication connectedScenes]).andReturn([NSSet set]);

  NSDictionary *notification = @{kFIRMessagingMessageLinkKey : @"https://www.google.com/"};
  XCTAssertNoThrow([_messaging handleIncomingLinkIfNeededFromMessage:notification]);

  [mockApplication stopMocking];
}

- (void)testHandleIncomingLink_noLinkInMessageDoesNothing {
  id mockApplication = OCMClassMock([UIApplication class]);
  OCMReject([mockApplication sharedApplication]);

  NSDictionary *notification = @{@"some_key" : @"some_value"};
  [_messaging handleIncomingLinkIfNeededFromMessage:notification];

  [mockApplication stopMocking];
}

- (void)testHandleIncomingLink_calledFromBackgroundThreadDispatchesToMain {
  id mockApplication = OCMClassMock([UIApplication class]);
  OCMStub([mockApplication sharedApplication]).andReturn(mockApplication);

  FakeLinkHandlingSceneDelegate *fakeSceneDelegate = [[FakeLinkHandlingSceneDelegate alloc] init];
  id mockScene = OCMClassMock([UIScene class]);
  OCMStub([mockScene delegate]).andReturn(fakeSceneDelegate);
  OCMStub([mockScene activationState]).andReturn(UISceneActivationStateForegroundActive);

  OCMStub([mockApplication connectedScenes]).andReturn([NSSet setWithObject:mockScene]);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Dispatches to main thread and calls scene delegate"];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSDictionary *notification = @{kFIRMessagingMessageLinkKey : @"https://www.google.com/"};
    [self.messaging handleIncomingLinkIfNeededFromMessage:notification];
    dispatch_async(dispatch_get_main_queue(), ^{
      XCTAssertTrue(fakeSceneDelegate.continueUserActivityWasCalled);
      [expectation fulfill];
    });
  });

  [self waitForExpectations:@[ expectation ] timeout:1.0];

  [mockApplication stopMocking];
  [mockScene stopMocking];
}

#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION

@end
