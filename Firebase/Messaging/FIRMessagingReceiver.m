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

#import "FIRMessagingReceiver.h"

#import <UIKit/UIKit.h>

#import <GoogleUtilities/GULAppEnvironmentUtil.h>

#import "FIRMessaging.h"
#import "FIRMessagingLogger.h"
#import "FIRMessagingUtilities.h"
#import "FIRMessaging_Private.h"

static NSString *const kUpstreamMessageIDUserInfoKey = @"messageID";
static NSString *const kUpstreamErrorUserInfoKey = @"error";
/// "Should use Messaging delegate" key stored in NSUserDefaults
NSString *const kFIRMessagingUserDefaultsKeyUseMessagingDelegate =
    @"com.firebase.messaging.useMessagingDelegate";
/// "Should use Messaging Delegate" key stored in Info.plist
NSString *const kFIRMessagingPlistUseMessagingDelegate =
    @"FirebaseMessagingUseMessagingDelegateForDirectChannel";

static int downstreamMessageID = 0;

@implementation FIRMessagingReceiver

#pragma mark - FIRMessagingDataMessageManager protocol

- (void)didReceiveMessage:(NSDictionary *)message withIdentifier:(nullable NSString *)messageID {
  if (![messageID length]) {
    messageID = [[self class] nextMessageID];
  }

  NSInteger majorOSVersion = [[GULAppEnvironmentUtil systemVersion] integerValue];
  if (majorOSVersion >= 10 || self.useDirectChannel) {
    // iOS 10 and above or use direct channel is enabled.
    [self scheduleIos10NotificationForMessage:message withIdentifier:messageID];
  } else {
    // Post notification directly to AppDelegate handlers. This is valid pre-iOS 10.
    [self scheduleNotificationForMessage:message];
  }
}

- (void)willSendDataMessageWithID:(NSString *)messageID error:(NSError *)error {
  NSNotification *notification;
  if (error) {
    NSDictionary *userInfo = @{
      kUpstreamMessageIDUserInfoKey : [messageID copy],
      kUpstreamErrorUserInfoKey : error
    };
    notification = [NSNotification notificationWithName:FIRMessagingSendErrorNotification
                                                 object:nil
                                               userInfo:userInfo];
    [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeReceiver000,
                            @"Fail to send upstream message: %@ error: %@", messageID, error);
  } else {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeReceiver001, @"Will send upstream message: %@",
                            messageID);
  }
}

- (void)didSendDataMessageWithID:(NSString *)messageID {
  // invoke the callbacks asynchronously
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeReceiver002, @"Did send upstream message: %@",
                          messageID);
  NSNotification * notification =
      [NSNotification notificationWithName:FIRMessagingSendSuccessNotification
                                    object:nil
                                  userInfo:@{ kUpstreamMessageIDUserInfoKey : [messageID copy] }];

  [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];
}

- (void)didDeleteMessagesOnServer {
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeReceiver003,
                          @"Will send deleted messages notification");
  NSNotification * notification =
      [NSNotification notificationWithName:FIRMessagingMessagesDeletedNotification
                                    object:nil];

  [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];
}

#pragma mark - Private Helpers
// As the new UserNotifications framework in iOS 10 doesn't support constructor/mutation for
// UNNotification object, FCM can't inject the message to the app with UserNotifications framework.
// Define our own protocol, which means app developers need to implement two interfaces to receive
// display notifications and data messages respectively for devices running iOS 10 or above. Devices
// running iOS 9 or below are not affected.
- (void)scheduleIos10NotificationForMessage:(NSDictionary *)message
                             withIdentifier:(NSString *)messageID {
  FIRMessagingRemoteMessage *wrappedMessage = [[FIRMessagingRemoteMessage alloc] init];
  // TODO: wrap title, body, badge and other fields
  wrappedMessage.appData = [message copy];
  wrappedMessage.messageID = messageID;
  [self.delegate receiver:self receivedRemoteMessage:wrappedMessage];
}

- (void)scheduleNotificationForMessage:(NSDictionary *)message {
  SEL newNotificationSelector =
      @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:);
  SEL oldNotificationSelector = @selector(application:didReceiveRemoteNotification:);

  dispatch_async(dispatch_get_main_queue(), ^{
    UIApplication *application = FIRMessagingUIApplication();
    if (!application) {
      return;
    }
    id<UIApplicationDelegate> appDelegate = [application delegate];
    if ([appDelegate respondsToSelector:newNotificationSelector]) {
      // Try the new remote notification callback
      [appDelegate application:application
          didReceiveRemoteNotification:message
                fetchCompletionHandler:^(UIBackgroundFetchResult result) {
                }];

    } else if ([appDelegate respondsToSelector:oldNotificationSelector]) {
      // Try the old remote notification callback
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      [appDelegate application:application didReceiveRemoteNotification:message];
#pragma clang diagnostic pop
    } else {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeReceiver005,
                              @"None of the remote notification callbacks implemented by "
                              @"UIApplicationDelegate");
    }
  });
}

+ (NSString *)nextMessageID {
  @synchronized (self) {
    ++downstreamMessageID;
    return [NSString stringWithFormat:@"gcm-%d", downstreamMessageID];
  }
}

- (BOOL)useDirectChannel {
  // Check storage
  NSUserDefaults *messagingDefaults = [NSUserDefaults standardUserDefaults];
  id shouldUseMessagingDelegate =
      [messagingDefaults objectForKey:kFIRMessagingUserDefaultsKeyUseMessagingDelegate];
  if (shouldUseMessagingDelegate) {
    return [shouldUseMessagingDelegate boolValue];
  }

  // Check Info.plist
  shouldUseMessagingDelegate =
      [[NSBundle mainBundle] objectForInfoDictionaryKey:kFIRMessagingPlistUseMessagingDelegate];
  if (shouldUseMessagingDelegate) {
    return [shouldUseMessagingDelegate boolValue];
  }
  // If none of above exists, we go back to default behavior which is NO.
  return NO;
}

- (void)setUseDirectChannel:(BOOL)useDirectChannel {
  NSUserDefaults *messagingDefaults = [NSUserDefaults standardUserDefaults];
  BOOL shouldUseMessagingDelegate = [self useDirectChannel];
  if (useDirectChannel != shouldUseMessagingDelegate) {
    [messagingDefaults setBool:useDirectChannel
                        forKey:kFIRMessagingUserDefaultsKeyUseMessagingDelegate];
    [messagingDefaults synchronize];
  }
}

@end
