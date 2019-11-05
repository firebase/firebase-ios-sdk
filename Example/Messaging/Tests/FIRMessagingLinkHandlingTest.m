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

#import <FirebaseMessaging/FIRMessaging.h>

#import "Example/Messaging/Tests/FIRMessagingTestNotificationUtilities.h"
#import "Example/Messaging/Tests/FIRMessagingTestUtilities.h"
#import "Firebase/Messaging/FIRMessagingConstants.h"


NSString *const kFIRMessagingTestsLinkHandlingSuiteName = @"com.messaging.test_linkhandling";

@interface FIRMessaging ()

- (NSURL *)linkURLFromMessage:(NSDictionary *)message;
- (void)setupRmqManager;

@end

@interface FIRMessagingLinkHandlingTest : XCTestCase {
  id _mockMessaging;
}

@property(nonatomic, readonly, strong) FIRMessaging *messaging;


@end

@implementation FIRMessagingLinkHandlingTest

- (void)setUp {
  [super setUp];

  NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kFIRMessagingTestsLinkHandlingSuiteName];
  _messaging = [FIRMessagingTestUtilities messagingForTestsWithUserDefaults:defaults];
  
  _mockMessaging = OCMPartialMock(_messaging);
  OCMStub([_mockMessaging setupRmqManager]).andReturn(nil);
}

- (void)tearDown {
  [_mockMessaging stopMocking];
  [self.messaging.messagingUserDefaults removePersistentDomainForName:kFIRMessagingTestsLinkHandlingSuiteName];
  _messaging = nil;
  [super tearDown];
}

#pragma mark - Link Handling Testing

- (void)testNonExistentLinkInMessage {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  NSURL *url = [_mockMessaging linkURLFromMessage:notification];
  XCTAssertNil(url);
}

- (void)testEmptyLinkInMessage {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  notification[kFIRMessagingMessageLinkKey] = @"";
  NSURL *url = [_mockMessaging linkURLFromMessage:notification];
  XCTAssertNil(url);
}

- (void)testNonStringLinkInMessage {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  notification[kFIRMessagingMessageLinkKey] = @(5);
  NSURL *url = [_mockMessaging linkURLFromMessage:notification];
  XCTAssertNil(url);
}

- (void)testInvalidURLStringLinkInMessage {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  notification[kFIRMessagingMessageLinkKey] = @"This is not a valid url string";
  NSURL *url = [_mockMessaging linkURLFromMessage:notification];
  XCTAssertNil(url);
}

- (void)testValidURLStringLinkInMessage {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  notification[kFIRMessagingMessageLinkKey] = @"https://www.google.com/";
  NSURL *url = [_mockMessaging linkURLFromMessage:notification];
  XCTAssertTrue([url.absoluteString isEqualToString:@"https://www.google.com/"]);
}

@end
