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

#import "Firebase/Messaging/FIRMessagingReceiver.h"

#import <FirebaseMessaging/FIRMessaging.h>

#import "Firebase/Messaging/FIRMessagingLogger.h"
#import "Firebase/Messaging/FIRMessagingUtilities.h"
#import "Firebase/Messaging/FIRMessaging_Private.h"

static NSString *const kUpstreamMessageIDUserInfoKey = @"messageID";
static NSString *const kUpstreamErrorUserInfoKey = @"error";

static int downstreamMessageID = 0;

@implementation FIRMessagingReceiver

#pragma mark - FIRMessagingDataMessageManager protocol

- (void)didReceiveMessage:(NSDictionary *)message withIdentifier:(nullable NSString *)messageID {
  if (![messageID length]) {
    messageID = [[self class] nextMessageID];
  }

  [self handleDirectChannelMessage:message withIdentifier:messageID];
}

- (void)willSendDataMessageWithID:(NSString *)messageID error:(NSError *)error {
  NSNotification *notification;
  if (error) {
    NSDictionary *userInfo =
        @{kUpstreamMessageIDUserInfoKey : [messageID copy], kUpstreamErrorUserInfoKey : error};
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    notification = [NSNotification notificationWithName:FIRMessagingSendErrorNotification
                                                 object:nil
                                               userInfo:userInfo];
#pragma clang diagnostic pop
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  NSNotification *notification =
      [NSNotification notificationWithName:FIRMessagingSendSuccessNotification
                                    object:nil
                                  userInfo:@{kUpstreamMessageIDUserInfoKey : [messageID copy]}];
#pragma clang diagnostic pop
  [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];
}

- (void)didDeleteMessagesOnServer {
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeReceiver003,
                          @"Will send deleted messages notification");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  NSNotification *notification =
      [NSNotification notificationWithName:FIRMessagingMessagesDeletedNotification object:nil];
  [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP];
}

#pragma mark - Private Helpers
- (void)handleDirectChannelMessage:(NSDictionary *)message withIdentifier:(NSString *)messageID {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  FIRMessagingRemoteMessage *wrappedMessage = [[FIRMessagingRemoteMessage alloc] init];
  wrappedMessage.appData = [message copy];
  wrappedMessage.messageID = messageID;
  [self.delegate receiver:self receivedRemoteMessage:wrappedMessage];
#pragma clang diagnostic pop
}

+ (NSString *)nextMessageID {
  @synchronized(self) {
    ++downstreamMessageID;
    return [NSString stringWithFormat:@"gcm-%d", downstreamMessageID];
  }
}

@end
