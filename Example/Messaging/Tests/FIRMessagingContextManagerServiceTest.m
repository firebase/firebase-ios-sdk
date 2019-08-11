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

#import "Firebase/Messaging/FIRMessagingContextManagerService.h"

@interface FIRMessagingContextManagerServiceTest : XCTestCase

@property(nonatomic, readwrite, strong) NSDateFormatter *dateFormatter;
@property(nonatomic, readwrite, strong) NSMutableArray *scheduledLocalNotifications;

@end

@implementation FIRMessagingContextManagerServiceTest

- (void)setUp {
  [super setUp];
  self.dateFormatter = [[NSDateFormatter alloc] init];
  self.dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  [self.dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
  self.scheduledLocalNotifications = [NSMutableArray array];
  [self mockSchedulingLocalNotifications];
}

- (void)tearDown {
  [super tearDown];
}

/**
 *  Test invalid context manager message, missing lt_start string.
 */
- (void)testInvalidContextManagerMessage_missingStartTime {
  NSDictionary *message = @{
    @"hello" : @"world",
  };
  XCTAssertFalse([FIRMessagingContextManagerService isContextManagerMessage:message]);
}

/**
 *  Test valid context manager message.
 */
- (void)testValidContextManagerMessage {
  NSDictionary *message = @{
    kFIRMessagingContextManagerLocalTimeStart: @"2015-12-12 00:00:00",
    @"hello" : @"world",
  };
  XCTAssertTrue([FIRMessagingContextManagerService isContextManagerMessage:message]);
}

// TODO: Enable these tests. They fail because we cannot schedule local
// notifications on OSX without permission. It's better to mock AppDelegate's
// scheduleLocalNotification to mock scheduling behavior.

/**
 *  Context Manager message with future start date should be successfully scheduled.
 */
- (void)testMessageWithFutureStartTime {
#if TARGET_OS_IOS
  NSString *messageIdentifier = @"fcm-cm-test1";
  NSString *startTimeString = @"2020-01-12 12:00:00";  // way into the future
  NSDictionary *message = @{
    kFIRMessagingContextManagerLocalTimeStart: startTimeString,
    kFIRMessagingContextManagerBodyKey : @"Hello world!",
    @"id": messageIdentifier,
    @"hello" : @"world"
  };

  XCTAssertTrue([FIRMessagingContextManagerService handleContextManagerMessage:message]);

  XCTAssertEqual(self.scheduledLocalNotifications.count, 1);

  UILocalNotification *notification = [self.scheduledLocalNotifications firstObject];
  NSDate *date = [self.dateFormatter dateFromString:startTimeString];
  XCTAssertEqual([notification.fireDate compare:date], NSOrderedSame);
#endif
}

/**
 *  Context Manager message with past end date should not be scheduled.
 */
- (void)testMessageWithPastEndTime {
#if TARGET_OS_IOS
  NSString *messageIdentifier = @"fcm-cm-test1";
  NSString *startTimeString = @"2010-01-12 12:00:00";  // way into the past
  NSString *endTimeString = @"2011-01-12 12:00:00";  // way into the past
  NSDictionary *message = @{
    kFIRMessagingContextManagerLocalTimeStart: startTimeString,
    kFIRMessagingContextManagerLocalTimeEnd : endTimeString,
    kFIRMessagingContextManagerBodyKey : @"Hello world!",
    @"id": messageIdentifier,
    @"hello" : @"world"
  };

  XCTAssertTrue([FIRMessagingContextManagerService handleContextManagerMessage:message]);
  XCTAssertEqual(self.scheduledLocalNotifications.count, 0);
#endif
}

/**
 *  Context Manager message with past start and future end date should be successfully
 *  scheduled.
 */
- (void)testMessageWithPastStartAndFutureEndTime {
#if TARGET_OS_IOS
  NSString *messageIdentifier = @"fcm-cm-test1";
  NSDate *startDate = [NSDate dateWithTimeIntervalSinceNow:-1000];  // past
  NSDate *endDate = [NSDate dateWithTimeIntervalSinceNow:1000];  // future
  NSString *startTimeString = [self.dateFormatter stringFromDate:startDate];
  NSString *endTimeString = [self.dateFormatter stringFromDate:endDate];

  NSDictionary *message = @{
    kFIRMessagingContextManagerLocalTimeStart : startTimeString,
    kFIRMessagingContextManagerLocalTimeEnd : endTimeString,
    kFIRMessagingContextManagerBodyKey : @"Hello world!",
    @"id": messageIdentifier,
    @"hello" : @"world"
  };

  XCTAssertTrue([FIRMessagingContextManagerService handleContextManagerMessage:message]);

  XCTAssertEqual(self.scheduledLocalNotifications.count, 1);
  UILocalNotification *notification = [self.scheduledLocalNotifications firstObject];
  // schedule notification after start date
  XCTAssertEqual([notification.fireDate compare:startDate], NSOrderedDescending);
  // schedule notification after end date
  XCTAssertEqual([notification.fireDate compare:endDate], NSOrderedAscending);
#endif
}

/**
 *  Test correctly parsing user data in local notifications.
 */
- (void)testTimedNotificationsUserInfo {
#if TARGET_OS_IOS
  NSString *messageIdentifierKey = @"message.id";
  NSString *messageIdentifier = @"fcm-cm-test1";
  NSString *startTimeString = @"2020-01-12 12:00:00";  // way into the future

  NSString *customDataKey = @"hello";
  NSString *customData = @"world";
  NSDictionary *message = @{
    kFIRMessagingContextManagerLocalTimeStart : startTimeString,
    kFIRMessagingContextManagerBodyKey : @"Hello world!",
    messageIdentifierKey : messageIdentifier,
    customDataKey : customData,
  };

  XCTAssertTrue([FIRMessagingContextManagerService handleContextManagerMessage:message]);

  XCTAssertEqual(self.scheduledLocalNotifications.count, 1);
  UILocalNotification *notification = [self.scheduledLocalNotifications firstObject];
  XCTAssertEqualObjects(notification.userInfo[messageIdentifierKey], messageIdentifier);
  XCTAssertEqualObjects(notification.userInfo[customDataKey], customData);
#endif

}

#pragma mark - Private Helpers

- (void)mockSchedulingLocalNotifications {
#if TARGET_OS_IOS
  id mockApplication = OCMPartialMock([UIApplication sharedApplication]);
  __block UILocalNotification *notificationToSchedule;
  [[[mockApplication stub]
      andDo:^(NSInvocation *invocation) {
        // Mock scheduling a notification
        if (notificationToSchedule) {
          [self.scheduledLocalNotifications addObject:notificationToSchedule];
        }
      }] scheduleLocalNotification:[OCMArg checkWithBlock:^BOOL(id obj) {
        if ([obj isKindOfClass:[UILocalNotification class]]) {
          notificationToSchedule = obj;
          return YES;
        }
        return NO;
      }]];
#endif
}

@end
