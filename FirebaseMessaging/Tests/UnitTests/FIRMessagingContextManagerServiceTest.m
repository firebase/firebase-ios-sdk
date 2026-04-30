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

#import "FirebaseMessaging/Sources/FIRMessagingContextManagerService.h"

static NSString *const kBody = @"Save 20% off!";
static NSString *const kTitle = @"Sparky WFH";
static NSString *const kSoundName = @"default";
static NSString *const kAction = @"open";
static NSString *const kUserInfoKey1 = @"level";
static NSString *const kUserInfoKey2 = @"isPayUser";
static NSString *const kUserInfoValue1 = @"5";
static NSString *const kUserInfoValue2 = @"Yes";
static NSString *const kMessageIdentifierKey = @"gcm.message_id";
static NSString *const kMessageIdentifierValue = @"1584748495200141";

@interface FIRMessagingContextManagerService (ExposedForTest)
+ (void)scheduleiOS10LocalNotificationForMessage:(NSDictionary *)message atDate:(NSDate *)date;
+ (UNMutableNotificationContent *)contentFromContextualMessage:(NSDictionary *)message
    API_AVAILABLE(macos(10.14));
@end

API_AVAILABLE(macos(10.14))
@interface FIRMessagingContextManagerServiceTest : XCTestCase

@property(nonatomic, readwrite, strong) NSDateFormatter *dateFormatter;
@property(nonatomic, readwrite, strong) NSMutableArray *scheduledLocalNotifications;
@property(nonatomic, readwrite, strong) NSMutableArray<UNNotificationRequest *> *requests;

@end

@implementation FIRMessagingContextManagerServiceTest

- (void)setUp {
  [super setUp];
  self.dateFormatter = [[NSDateFormatter alloc] init];
  self.dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  [self.dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
  self.scheduledLocalNotifications = [[NSMutableArray alloc] init];
  if (@available(macOS 10.14, *)) {
    self.requests = [[NSMutableArray alloc] init];
  }

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
    kFIRMessagingContextManagerLocalTimeStart : @"2015-12-12 00:00:00",
    @"hello" : @"world",
  };
  XCTAssertTrue([FIRMessagingContextManagerService isContextManagerMessage:message]);
}

/**
 *  Context Manager message with future start date should be successfully scheduled.
 */
- (void)testMessageWithFutureStartTime {
  // way into the future
  NSString *startTimeString = [self.dateFormatter stringFromDate:[NSDate distantFuture]];
  NSDictionary *message = @{
    kFIRMessagingContextManagerLocalTimeStart : startTimeString,
    kFIRMessagingContextManagerBodyKey : kBody,
    kMessageIdentifierKey : kMessageIdentifierValue,
    kUserInfoKey1 : kUserInfoValue1,
    kUserInfoKey2 : kUserInfoValue2
  };
  XCTAssertTrue([FIRMessagingContextManagerService handleContextManagerMessage:message]);

  if (@available(macOS 10.14, *)) {
    XCTAssertEqual(self.requests.count, 1);
    UNNotificationRequest *request = self.requests.firstObject;
    XCTAssertEqualObjects(request.identifier, kMessageIdentifierValue);
#if !TARGET_OS_TV
    XCTAssertEqualObjects(request.content.body, kBody);
    XCTAssertEqualObjects(request.content.userInfo[kUserInfoKey1], kUserInfoValue1);
    XCTAssertEqualObjects(request.content.userInfo[kUserInfoKey2], kUserInfoValue2);
#endif  // TARGET_OS_TV
    return;
  }

#if TARGET_OS_IOS
  XCTAssertEqual(self.scheduledLocalNotifications.count, 1);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  UILocalNotification *notification = self.scheduledLocalNotifications.firstObject;
#pragma clang diagnostic pop
  NSDate *date = [self.dateFormatter dateFromString:startTimeString];
  XCTAssertEqual([notification.fireDate compare:date], NSOrderedSame);
  XCTAssertEqualObjects(notification.alertBody, kBody);
  XCTAssertEqualObjects(notification.userInfo[kUserInfoKey1], kUserInfoValue1);
  XCTAssertEqualObjects(notification.userInfo[kUserInfoKey2], kUserInfoValue2);
#endif  // TARGET_OS_IOS
}

/**
 *  Context Manager message with past end date should not be scheduled.
 */
- (void)testMessageWithPastEndTime {
#if TARGET_OS_IOS
  NSString *startTimeString = @"2010-01-12 12:00:00";  // way into the past
  NSString *endTimeString = @"2011-01-12 12:00:00";    // way into the past
  NSDictionary *message = @{
    kFIRMessagingContextManagerLocalTimeStart : startTimeString,
    kFIRMessagingContextManagerLocalTimeEnd : endTimeString,
    kFIRMessagingContextManagerBodyKey : kBody,
    kMessageIdentifierKey : kMessageIdentifierValue,
    @"hello" : @"world"
  };

  XCTAssertTrue([FIRMessagingContextManagerService handleContextManagerMessage:message]);
  if (@available(macOS 10.14, *)) {
    XCTAssertEqual(self.requests.count, 0);
    return;
  }
  XCTAssertEqual(self.scheduledLocalNotifications.count, 0);
#endif
}

/**
 *  Context Manager message with past start and future end date should be successfully
 *  scheduled.
 */
- (void)testMessageWithPastStartAndFutureEndTime {
#if TARGET_OS_IOS
  NSDate *startDate = [NSDate dateWithTimeIntervalSinceNow:-1000];  // past
  NSDate *endDate = [NSDate dateWithTimeIntervalSinceNow:1000];     // future
  NSString *startTimeString = [self.dateFormatter stringFromDate:startDate];
  NSString *endTimeString = [self.dateFormatter stringFromDate:endDate];

  NSDictionary *message = @{
    kFIRMessagingContextManagerLocalTimeStart : startTimeString,
    kFIRMessagingContextManagerLocalTimeEnd : endTimeString,
    kFIRMessagingContextManagerBodyKey : kBody,
    kMessageIdentifierKey : kMessageIdentifierValue,
    kUserInfoKey1 : kUserInfoValue1,
    kUserInfoKey2 : kUserInfoValue2
  };

  XCTAssertTrue([FIRMessagingContextManagerService handleContextManagerMessage:message]);

  if (@available(macOS 10.14, *)) {
    XCTAssertEqual(self.requests.count, 1);
    UNNotificationRequest *request = self.requests.firstObject;
    XCTAssertEqualObjects(request.identifier, kMessageIdentifierValue);
    XCTAssertEqualObjects(request.content.body, kBody);
    XCTAssertEqualObjects(request.content.userInfo[kUserInfoKey1], kUserInfoValue1);
    XCTAssertEqualObjects(request.content.userInfo[kUserInfoKey2], kUserInfoValue2);
    return;
  }
  XCTAssertEqual(self.scheduledLocalNotifications.count, 1);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  UILocalNotification *notification = [self.scheduledLocalNotifications firstObject];
#pragma clang diagnostic pop
  // schedule notification after start date
  XCTAssertEqual([notification.fireDate compare:startDate], NSOrderedDescending);
  // schedule notification after end date
  XCTAssertEqual([notification.fireDate compare:endDate], NSOrderedAscending);
  XCTAssertEqualObjects(notification.userInfo[kUserInfoKey1], kUserInfoValue1);
  XCTAssertEqualObjects(notification.userInfo[kUserInfoKey2], kUserInfoValue2);
#endif  // TARGET_OS_IOS
}

/**
 *  Test correctly parsing user data in local notifications.
 */
- (void)testTimedNotificationsUserInfo {
#if TARGET_OS_IOS
  // way into the future
  NSString *startTimeString = [self.dateFormatter stringFromDate:[NSDate distantFuture]];

  NSDictionary *message = @{
    kFIRMessagingContextManagerLocalTimeStart : startTimeString,
    kFIRMessagingContextManagerBodyKey : kBody,
    kMessageIdentifierKey : kMessageIdentifierValue,
    kUserInfoKey1 : kUserInfoValue1,
    kUserInfoKey2 : kUserInfoValue2
  };

  XCTAssertTrue([FIRMessagingContextManagerService handleContextManagerMessage:message]);
  if (@available(macOS 10.14, *)) {
    XCTAssertEqual(self.requests.count, 1);
    UNNotificationRequest *request = self.requests.firstObject;
    XCTAssertEqualObjects(request.identifier, kMessageIdentifierValue);
    XCTAssertEqualObjects(request.content.body, kBody);
    XCTAssertEqualObjects(request.content.userInfo[kUserInfoKey1], kUserInfoValue1);
    XCTAssertEqualObjects(request.content.userInfo[kUserInfoKey2], kUserInfoValue2);
    return;
  }
  XCTAssertEqual(self.scheduledLocalNotifications.count, 1);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  UILocalNotification *notification = [self.scheduledLocalNotifications firstObject];
#pragma clang diagnostic pop
  XCTAssertEqualObjects(notification.userInfo[kUserInfoKey1], kUserInfoValue1);
  XCTAssertEqualObjects(notification.userInfo[kUserInfoKey2], kUserInfoValue2);
#endif  // TARGET_OS_IOS
}

#pragma mark - Private Helpers

- (void)mockSchedulingLocalNotifications {
  if (@available(macOS 10.14, iOS 10.0, watchOS 3.0, tvOS 10.0, *)) {
    id mockNotificationCenter =
        OCMPartialMock([UNUserNotificationCenter currentNotificationCenter]);
    __block UNNotificationRequest *request;
    [[[mockNotificationCenter stub] andDo:^(NSInvocation *invocation) {
      [self.requests addObject:request];
    }] addNotificationRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
         if ([obj isKindOfClass:[UNNotificationRequest class]]) {
           request = obj;
           [self.requests addObject:request];
           return YES;
         }
         return NO;
       }]
        withCompletionHandler:^(NSError *_Nullable error){
        }];
    return;
  }
#if TARGET_OS_IOS
  id mockApplication = OCMPartialMock([UIApplication sharedApplication]);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  __block UILocalNotification *notificationToSchedule;
  [[[mockApplication stub] andDo:^(NSInvocation *invocation) {
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
#pragma clang diagnostic pop
#endif  // TARGET_OS_IOS
}

- (void)testScheduleiOS10LocalNotification {
  if (@available(macOS 10.14, *)) {
    id mockContextManagerService = OCMClassMock([FIRMessagingContextManagerService class]);
    NSDictionary *message = @{};

    [FIRMessagingContextManagerService scheduleiOS10LocalNotificationForMessage:message
                                                                         atDate:[NSDate date]];
    OCMVerify([mockContextManagerService contentFromContextualMessage:message]);
    [mockContextManagerService stopMocking];
  }
}

- (void)testContentFromConetxtualMessage {
  if (@available(macOS 10.14, *)) {
    NSDictionary *message = @{
      @"aps" : @{@"content-available" : @1},
      @"gcm.message_id" : @1623702615599207,
      @"gcm.n.e" : @1,
      @"gcm.notification.badge" : @1,
      @"gcm.notification.body" : kBody,
      @"gcm.notification.image" :
          @"https://firebasestorage.googleapis.com/v0/b/fir-ios-app-extensions.appspot.com/o/"
          @"sparkyWFH.png?alt=media&token=f4dc1533-4d80-4ed6-9870-8df528593157",
      @"gcm.notification.mutable_content" : @1,
      @"gcm.notification.sound" : kSoundName,
      @"gcm.notification.sound2" : kSoundName,
      @"gcm.notification.title" : kTitle,
      // This field is not popped out from console
      // Manual add here to test unit test
      @"gcm.notification.click_action" : kAction,
      @"gcms" : @"gcm.gmsproc.cm",
      @"google.c.a.c_id" : @2159728303499680621,
      @"google.c.a.c_l" : @"test local send with sound",
      @"google.c.a.e" : @1,
      @"google.c.a.ts" : @1623753000,
      @"google.c.a.udt" : @1,
      @"google.c.cm.lt_end" : @"2021-07-13 10:30:00",
      @"google.c.cm.lt_start" : @"2021-06-15 10:30:00",
      @"google.c.sender.id" : @449451107265,
    };
    UNMutableNotificationContent *content =
        [FIRMessagingContextManagerService contentFromContextualMessage:message];
    XCTAssertEqualObjects(content.badge, @1);

#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_WATCH
    XCTAssertEqualObjects(content.body, kBody);
    XCTAssertEqualObjects(content.title, kTitle);
#if !TARGET_OS_WATCH
    XCTAssertEqualObjects(content.sound, [UNNotificationSound soundNamed:kSoundName]);
#else   // !TARGET_OS_WATCH
    XCTAssertEqualObjects(content.sound, [UNNotificationSound defaultSound]);
#endif  // !TARGET_OS_WATCH
    XCTAssertEqualObjects(content.categoryIdentifier, kAction);
    NSDictionary *userInfo = @{
      @"gcm.message_id" : @1623702615599207,
      @"gcm.n.e" : @1,
      @"gcm.notification.badge" : @1,
      @"gcm.notification.body" : kBody,
      @"gcm.notification.image" :
          @"https://firebasestorage.googleapis.com/v0/b/fir-ios-app-extensions.appspot.com/o/"
          @"sparkyWFH.png?alt=media&token=f4dc1533-4d80-4ed6-9870-8df528593157",
      @"gcm.notification.mutable_content" : @1,
      @"gcm.notification.sound" : kSoundName,
      @"gcm.notification.sound2" : kSoundName,
      @"gcm.notification.title" : kTitle,
      // This field is not popped out from console
      // Manual add here to test unit test
      @"gcm.notification.click_action" : kAction,
      @"gcms" : @"gcm.gmsproc.cm",
      @"google.c.a.c_id" : @2159728303499680621,
      @"google.c.a.c_l" : @"test local send with sound",
      @"google.c.a.e" : @1,
      @"google.c.a.ts" : @1623753000,
      @"google.c.a.udt" : @1,
      @"google.c.sender.id" : @449451107265
    };
    XCTAssertEqualObjects(content.userInfo, userInfo);
#endif  // TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_WATCH
  }
}

@end
