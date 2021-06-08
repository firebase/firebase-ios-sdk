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

#import <OCMock/OCMock.h>

#import <GoogleUtilities/GULUserDefaults.h>
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

#import "FirebaseMessaging/Sources/FIRMessagingAnalytics.h"
#import "FirebaseMessaging/Sources/FIRMessagingRmqManager.h"
#import "FirebaseMessaging/Sources/FIRMessagingSyncMessageManager.h"
#import "FirebaseMessaging/Sources/FIRMessaging_Private.h"
#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingTestUtilities.h"

extern NSString *const kFIRMessagingFCMTokenFetchAPNSOption;

@interface FIRMessaging ()

@property(nonatomic, readwrite, strong) NSString *defaultFcmToken;
- (BOOL)handleContextManagerMessage:(NSDictionary *)message;
- (void)handleIncomingLinkIfNeededFromMessage:(NSDictionary *)message;

@end

/*
 * This class checks if we handle the received message properly
 * based on each type of messages. Checks include duplicate message handling,
 * analytics logging, etc.
 */
@interface FIRMessagingHandlingTest : XCTestCase

@property(nonatomic, strong) FIRMessagingAnalytics *messageAnalytics;
@property(nonatomic, strong) id mockFirebaseApp;
@property(nonatomic, strong) id mockMessagingAnalytics;
@property(nonatomic, strong) FIRMessagingTestUtilities *testUtil;

@end

@implementation FIRMessagingHandlingTest

- (void)setUp {
  [super setUp];

  // Create the messaging instance with all the necessary dependencies.
  NSUserDefaults *defaults =
      [[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingDefaultsTestDomain];
  _testUtil = [[FIRMessagingTestUtilities alloc] initWithUserDefaults:defaults withRMQManager:YES];
  _mockFirebaseApp = OCMClassMock([FIRApp class]);
  OCMStub([_mockFirebaseApp defaultApp]).andReturn(_mockFirebaseApp);
  [[NSUserDefaults standardUserDefaults]
      removePersistentDomainForName:[NSBundle mainBundle].bundleIdentifier];
  _mockMessagingAnalytics = OCMClassMock([FIRMessagingAnalytics class]);
}

- (void)tearDown {
  [_testUtil cleanupAfterTest:self];
  [_mockMessagingAnalytics stopMocking];
  [_mockFirebaseApp stopMocking];
  [super tearDown];
}

- (void)testEmptyNotification {
  XCTAssertEqualObjects(@(FIRMessagingMessageStatusUnknown),
                        @([_testUtil.mockMessaging appDidReceiveMessage:@{}].status));
}

- (void)testAPNSDisplayNotification {
  NSDictionary *notificationPayload = @{
    @"aps" : @{
      @"alert" : @{
        @"body" : @"body of notification",
        @"title" : @"title of notification",
      }
    },
    @"gcm.message_id" : @"1566515013484879",
    @"gcm.n.e" : @1,
    @"google.c.a.c_id" : @"7379928225816991517",
    @"google.c.a.e" : @1,
    @"google.c.a.ts" : @1566515009,
    @"google.c.a.udt" : @0
  };
  OCMExpect([_testUtil.mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMExpect([_testUtil.mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMExpect([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);
  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_testUtil.messaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_testUtil.mockMessaging);

  OCMReject([_testUtil.mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMReject([_testUtil.mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMReject([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);

  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_testUtil.messaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_testUtil.mockMessaging);
}

- (void)testAPNSContentAvailableNotification {
  NSDictionary *notificationPayload = @{
    @"aps" : @{@"content-available" : @1},
    @"gcm.message_id" : @"1566513591299872",
    @"image" : @"bunny.png",
    @"google.c.a.e" : @1
  };
  OCMExpect([_testUtil.mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMExpect([_testUtil.mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMExpect([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);
  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_testUtil.messaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_testUtil.mockMessaging);

  OCMReject([_testUtil.mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMReject([_testUtil.mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMReject([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);

  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_testUtil.messaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_testUtil.mockMessaging);
}

- (void)testAPNSContentAvailableContextualNotification {
  NSDictionary *notificationPayload = @{
    @"aps" : @{@"content-available" : @1},
    @"gcm.message_id" : @"1566515531287827",
    @"gcm.n.e" : @1,
    @"gcm.notification.body" : @"Local time zone message!",
    @"gcm.notification.title" : @"Hello",
    @"gcms" : @"gcm.gmsproc.cm",
    @"google.c.a.c_id" : @"5941428497527920876",
    @"google.c.a.e" : @1,
    @"google.c.a.ts" : @1566565920,
    @"google.c.a.udt" : @1,
    @"google.c.cm.cat" : @"com.google.firebase.messaging.testapp.dev",
    @"google.c.cm.lt_end" : @"2019-09-20 13:12:00",
    @"google.c.cm.lt_start" : @"2019-08-23 13:12:00",
  };
  OCMExpect([_testUtil.mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMExpect([_testUtil.mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMExpect([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);
  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_testUtil.messaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_testUtil.mockMessaging);

  OCMReject([_testUtil.mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMReject([_testUtil.mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMReject([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);

  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_testUtil.messaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_testUtil.mockMessaging);
}

- (void)testContextualLocalNotification {
  NSDictionary *notificationPayload = @{
    @"gcm.message_id" : @"1566515531281975",
    @"gcm.n.e" : @1,
    @"gcm.notification.body" : @"Local time zone message!",
    @"gcm.notification.title" : @"Hello",
    @"gcms" : @"gcm.gmsproc.cm",
    @"google.c.a.c_id" : @"5941428497527920876",
    @"google.c.a.e" : @1,
    @"google.c.a.ts" : @1566565920,
    @"google.c.a.udt" : @1,
  };
  OCMExpect([_testUtil.mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMExpect([_testUtil.mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMExpect([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);
  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_testUtil.messaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_testUtil.mockMessaging);

  OCMReject([_testUtil.mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMReject([_testUtil.mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMReject([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);

  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_testUtil.messaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_testUtil.mockMessaging);
}

- (void)testMCSNotification {
  NSDictionary *notificationPayload = @{@"from" : @"35006771263", @"image" : @"bunny.png"};
  OCMExpect([_testUtil.mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMExpect([_testUtil.mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMExpect([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);
  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_testUtil.messaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_testUtil.mockMessaging);

  OCMExpect([_testUtil.mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMExpect([_testUtil.mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMExpect([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);

  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_testUtil.messaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_testUtil.mockMessaging);
}

@end
