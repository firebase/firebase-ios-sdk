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

#import "Firebase/Messaging/FIRMessagingContextManagerService.h"

#import "Firebase/Messaging/FIRMessagingDefines.h"
#import "Firebase/Messaging/FIRMessagingLogger.h"
#import "Firebase/Messaging/FIRMessagingUtilities.h"

#import <GoogleUtilities/GULAppDelegateSwizzler.h>

#define kFIRMessagingContextManagerPrefixKey @"google.c.cm."
#define kFIRMessagingContextManagerNotificationKeyPrefix @"gcm.notification."

static NSString *const kLogTag = @"FIRMessagingAnalytics";

static NSString *const kLocalTimeFormatString = @"yyyy-MM-dd HH:mm:ss";

static NSString *const kContextManagerPrefixKey = kFIRMessagingContextManagerPrefixKey;

// Local timed messages (format yyyy-mm-dd HH:mm:ss)
NSString *const kFIRMessagingContextManagerLocalTimeStart = kFIRMessagingContextManagerPrefixKey @"lt_start";
NSString *const kFIRMessagingContextManagerLocalTimeEnd = kFIRMessagingContextManagerPrefixKey @"lt_end";

// Local Notification Params
NSString *const kFIRMessagingContextManagerBodyKey = kFIRMessagingContextManagerNotificationKeyPrefix @"body";
NSString *const kFIRMessagingContextManagerTitleKey = kFIRMessagingContextManagerNotificationKeyPrefix @"title";
NSString *const kFIRMessagingContextManagerBadgeKey = kFIRMessagingContextManagerNotificationKeyPrefix @"badge";
NSString *const kFIRMessagingContextManagerCategoryKey =
    kFIRMessagingContextManagerNotificationKeyPrefix @"click_action";
NSString *const kFIRMessagingContextManagerSoundKey = kFIRMessagingContextManagerNotificationKeyPrefix @"sound";
NSString *const kFIRMessagingContextManagerContentAvailableKey =
    kFIRMessagingContextManagerNotificationKeyPrefix @"content-available";

typedef NS_ENUM(NSUInteger, FIRMessagingContextManagerMessageType) {
  FIRMessagingContextManagerMessageTypeNone,
  FIRMessagingContextManagerMessageTypeLocalTime,
};

@implementation FIRMessagingContextManagerService

+ (BOOL)isContextManagerMessage:(NSDictionary *)message {
  // For now we only support local time in ContextManager.
  if (![message[kFIRMessagingContextManagerLocalTimeStart] length]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeContextManagerService000,
                            @"Received message missing local start time, dropped.");
    return NO;
  }

  return YES;
}

+ (BOOL)handleContextManagerMessage:(NSDictionary *)message {
  NSString *startTimeString = message[kFIRMessagingContextManagerLocalTimeStart];
  if (startTimeString.length) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeContextManagerService001,
                            @"%@ Received context manager message with local time %@", kLogTag,
                            startTimeString);
    return [self handleContextManagerLocalTimeMessage:message];
  }

  return NO;
}

+ (BOOL)handleContextManagerLocalTimeMessage:(NSDictionary *)message {
  NSString *startTimeString = message[kFIRMessagingContextManagerLocalTimeStart];
  if (!startTimeString) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeContextManagerService002,
                              @"Invalid local start date format %@. Message dropped",
                              startTimeString);
    return NO;
  }
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  [dateFormatter setDateFormat:kLocalTimeFormatString];
  NSDate *startDate = [dateFormatter dateFromString:startTimeString];
  NSDate *currentDate = [NSDate date];

  if ([currentDate compare:startDate] == NSOrderedAscending) {
    [self scheduleLocalNotificationForMessage:message
                                       atDate:startDate];
  } else {
    // check end time has not passed
    NSString *endTimeString = message[kFIRMessagingContextManagerLocalTimeEnd];
    if (!endTimeString) {
      FIRMessagingLoggerInfo(
          kFIRMessagingMessageCodeContextManagerService003,
          @"No end date specified for message, start date elapsed. Message dropped.");
      return YES;
    }

    NSDate *endDate = [dateFormatter dateFromString:endTimeString];
    if (!endTimeString) {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeContextManagerService004,
                              @"Invalid local end date format %@. Message dropped", endTimeString);
      return NO;
    }

    if ([endDate compare:currentDate] == NSOrderedAscending) {
      // end date has already passed drop the message
      FIRMessagingLoggerInfo(kFIRMessagingMessageCodeContextManagerService005,
                             @"End date %@ has already passed. Message dropped.", endTimeString);
      return YES;
    }

    // schedule message right now (buffer 10s)
    [self scheduleLocalNotificationForMessage:message
                                       atDate:[currentDate dateByAddingTimeInterval:10]];
  }
  return YES;
}

+ (void)scheduleLocalNotificationForMessage:(NSDictionary *)message
                                     atDate:(NSDate *)date {
#if TARGET_OS_IOS
  NSDictionary *apsDictionary = message;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  UILocalNotification *notification = [[UILocalNotification alloc] init];
#pragma clang diagnostic pop

  // A great way to understand timezones and UILocalNotifications
  // http://stackoverflow.com/questions/18424569/understanding-uilocalnotification-timezone
  notification.timeZone = [NSTimeZone defaultTimeZone];
  notification.fireDate = date;

  // In the current solution all of the display stuff goes into a special "aps" dictionary
  // being sent in the message.
  if ([apsDictionary[kFIRMessagingContextManagerBodyKey] length]) {
    notification.alertBody = apsDictionary[kFIRMessagingContextManagerBodyKey];
  }
  if ([apsDictionary[kFIRMessagingContextManagerTitleKey] length]) {
    // |alertTitle| is iOS 8.2+, so check if we can set it
      if ([notification respondsToSelector:@selector(setAlertTitle:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
      notification.alertTitle = apsDictionary[kFIRMessagingContextManagerTitleKey];
#pragma pop
    }
  }

  if (apsDictionary[kFIRMessagingContextManagerSoundKey]) {
    notification.soundName = apsDictionary[kFIRMessagingContextManagerSoundKey];
  }
  if (apsDictionary[kFIRMessagingContextManagerBadgeKey]) {
    notification.applicationIconBadgeNumber =
        [apsDictionary[kFIRMessagingContextManagerBadgeKey] integerValue];
  }
  if (apsDictionary[kFIRMessagingContextManagerCategoryKey]) {
    // |category| is iOS 8.0+, so check if we can set it
    if ([notification respondsToSelector:@selector(setCategory:)]) {
      notification.category = apsDictionary[kFIRMessagingContextManagerCategoryKey];
    }
  }

  NSDictionary *userInfo = [self parseDataFromMessage:message];
  if (userInfo.count) {
    notification.userInfo = userInfo;
  }
  UIApplication *application = [GULAppDelegateSwizzler sharedApplication];
  if (!application) {
    return;
  }
  [application scheduleLocalNotification:notification];
#endif
}

+ (NSDictionary *)parseDataFromMessage:(NSDictionary *)message {
  NSMutableDictionary *data = [NSMutableDictionary dictionary];
  for (NSObject<NSCopying> *key in message) {
    if ([key isKindOfClass:[NSString class]]) {
      NSString *keyString = (NSString *)key;
      if ([keyString isEqualToString:kFIRMessagingContextManagerContentAvailableKey]) {
        continue;
      } else if ([keyString hasPrefix:kContextManagerPrefixKey]) {
        continue;
      }
    }
    data[[key copy]] = message[key];
  }
  return [data copy];
}

@end
