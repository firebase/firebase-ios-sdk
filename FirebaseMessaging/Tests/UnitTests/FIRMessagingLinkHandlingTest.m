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

@end

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

@end
