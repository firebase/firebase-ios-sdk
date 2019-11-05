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

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseInstanceID/FirebaseInstanceID.h>
#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>
#import <FirebaseMessaging/FIRMessaging.h>

#import "Example/Messaging/Tests/FIRMessagingTestUtilities.h"
#import "Firebase/Messaging/FIRMessaging_Private.h"
#import "Firebase/Messaging/FIRMessagingAnalytics.h"
#import "Firebase/Messaging/FIRMessagingRmqManager.h"
#import "Firebase/Messaging/FIRMessagingSyncMessageManager.h"

extern NSString *const kFIRMessagingFCMTokenFetchAPNSOption;

/// The NSUserDefaults domain for testing.
static NSString *const kFIRMessagingDefaultsTestDomain = @"com.messaging.tests";

@interface FIRMessaging ()

@property(nonatomic, readwrite, strong) NSString *defaultFcmToken;
@property(nonatomic, readwrite, strong) FIRInstanceID *instanceID;

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
@property(nonatomic, strong) FIRMessaging *messaging;
@property(nonatomic, strong) id mockMessaging;
@property(nonatomic, strong) id mockInstanceID;
@property(nonatomic, strong) id mockFirebaseApp;
@property(nonatomic, strong) id mockMessagingAnalytics;
@property(nonatomic, strong) FIRMessagingTestUtilities * testUtil;

@end

@implementation FIRMessagingHandlingTest

- (void)setUp {
  [super setUp];

  // Create the messaging instance with all the necessary dependencies.
  NSUserDefaults *defaults =
      [[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingDefaultsTestDomain];
  _testUtil = [[FIRMessagingTestUtilities alloc] initWithUserDefaults:defaults withRMQManager:YES];
  _mockMessaging = _testUtil.mockMessaging;
  _messaging = _testUtil.messaging;
  _mockFirebaseApp = OCMClassMock([FIRApp class]);
   OCMStub([_mockFirebaseApp defaultApp]).andReturn(_mockFirebaseApp);
  _mockInstanceID = _testUtil.mockInstanceID;
  [[NSUserDefaults standardUserDefaults]
      removePersistentDomainForName:[NSBundle mainBundle].bundleIdentifier];
  _mockMessagingAnalytics = OCMClassMock([FIRMessagingAnalytics class]);
}

- (void)tearDown {
  [_testUtil stopMockingMessaging];
  [_mockMessagingAnalytics stopMocking];
  [_mockMessaging stopMocking];
  [_mockInstanceID stopMocking];
  [_mockFirebaseApp stopMocking];
  [super tearDown];
}

-(void)testEmptyNotification {
  XCTAssertEqualObjects(@(FIRMessagingMessageStatusUnknown), @([_mockMessaging appDidReceiveMessage:@{}].status));
}

-(void)testAPNSDisplayNotification {
  NSDictionary *notificationPayload = @{
                                        @"aps": @{
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
  OCMExpect([_mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMExpect([_mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMExpect([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);
  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_mockMessaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_mockMessaging);

  OCMReject([_mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMReject([_mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMReject([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);

  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                          @([_mockMessaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_mockMessaging);

}

-(void)testAPNSContentAvailableNotification {
  NSDictionary *notificationPayload = @{
                                        @"aps": @{
                                            @"content-available" : @1
                                            },
                                        @"gcm.message_id" : @"1566513591299872",
                                        @"image" : @"bunny.png",
                                        @"google.c.a.e" : @1
                                        };
  OCMExpect([_mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMExpect([_mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMExpect([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);
  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_mockMessaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_mockMessaging);

  OCMReject([_mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMReject([_mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMReject([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);

  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_mockMessaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_mockMessaging);

}

-(void)testAPNSContentAvailableContextualNotification {
 
  NSDictionary *notificationPayload = @{
                                        @"aps" : @{
                                            @"content-available": @1
                                        },
                                        @"gcm.message_id": @"1566515531287827",
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
  OCMExpect([_mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMExpect([_mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMExpect([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);
  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_mockMessaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_mockMessaging);

  OCMReject([_mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMReject([_mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMReject([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);

  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_mockMessaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_mockMessaging);

}

-(void)testContextualLocalNotification {
  NSDictionary *notificationPayload = @{
                                        @"gcm.message_id": @"1566515531281975",
                                        @"gcm.n.e" : @1,
                                        @"gcm.notification.body" : @"Local time zone message!",
                                        @"gcm.notification.title" : @"Hello",
                                        @"gcms" : @"gcm.gmsproc.cm",
                                        @"google.c.a.c_id" : @"5941428497527920876",
                                        @"google.c.a.e" : @1,
                                        @"google.c.a.ts" : @1566565920,
                                        @"google.c.a.udt" : @1,
                                        };
  OCMExpect([_mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMExpect([_mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMExpect([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);
  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_mockMessaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_mockMessaging);

  OCMReject([_mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMReject([_mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMReject([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);

  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_mockMessaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_mockMessaging);
}

-(void)testMCSNotification {
  NSDictionary *notificationPayload = @{
                                        @"from" : @"35006771263",
                                        @"image" : @"bunny.png"
                                        };
  OCMExpect([_mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMExpect([_mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMExpect([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);
  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_mockMessaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_mockMessaging);

  OCMExpect([_mockMessaging handleContextManagerMessage:notificationPayload]);
  OCMExpect([_mockMessaging handleIncomingLinkIfNeededFromMessage:notificationPayload]);
  OCMExpect([_mockMessagingAnalytics logMessage:notificationPayload toAnalytics:[OCMArg any]]);

  XCTAssertEqualObjects(@(FIRMessagingMessageStatusNew),
                        @([_mockMessaging appDidReceiveMessage:notificationPayload].status));
  OCMVerifyAll(_mockMessaging);
}

@end
