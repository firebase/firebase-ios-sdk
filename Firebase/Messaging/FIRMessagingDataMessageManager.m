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

#import "FIRMessagingDataMessageManager.h"

#import "Protos/GtalkCore.pbobjc.h"

#import "FIRMessagingClient.h"
#import "FIRMessagingConnection.h"
#import "FIRMessagingConstants.h"
#import "FIRMessagingDefines.h"
#import "FIRMessagingDelayedMessageQueue.h"
#import "FIRMessagingLogger.h"
#import "FIRMessagingReceiver.h"
#import "FIRMessagingRmqManager.h"
#import "FIRMessaging_Private.h"
#import "FIRMessagingSyncMessageManager.h"
#import "FIRMessagingUtilities.h"
#import "NSError+FIRMessaging.h"

static const int kMaxAppDataSizeDefault = 4 * 1024; // 4k
static const int kMinDelaySeconds = 1; // 1 second
static const int kMaxDelaySeconds = 60 * 60; // 1 hour

static NSString *const kFromForFIRMessagingMessages = @"mcs.android.com";
static NSString *const kGSFMessageCategory = @"com.google.android.gsf.gtalkservice";
// TODO: Update Gcm to FIRMessaging in the constants below
static NSString *const kFCMMessageCategory = @"com.google.gcm";
static NSString *const kMessageReservedPrefix = @"google.";

static NSString *const kFCMMessageSpecialMessage = @"message_type";

// special messages sent by the server
static NSString *const kFCMMessageTypeDeletedMessages = @"deleted_messages";

static NSString *const kMCSNotificationPrefix = @"gcm.notification.";
static NSString *const kDataMessageNotificationKey = @"notification";


typedef NS_ENUM(int8_t, UpstreamForceReconnect) {
  // Never force reconnect on upstream messages
  kUpstreamForceReconnectOff = 0,
  // Force reconnect for TTL=0 upstream messages
  kUpstreamForceReconnectTTL0 = 1,
  // Force reconnect for all upstream messages
  kUpstreamForceReconnectAll = 2,
};

@interface FIRMessagingDataMessageManager ()

@property(nonatomic, readwrite, weak) FIRMessagingClient *client;
@property(nonatomic, readwrite, weak) FIRMessagingRmqManager *rmq2Manager;
@property(nonatomic, readwrite, weak) FIRMessagingSyncMessageManager *syncMessageManager;
@property(nonatomic, readwrite, weak) id<FIRMessagingDataMessageManagerDelegate> delegate;
@property(nonatomic, readwrite, strong) FIRMessagingDelayedMessageQueue *delayedMessagesQueue;

@property(nonatomic, readwrite, assign) int ttl;
@property(nonatomic, readwrite, copy) NSString *deviceAuthID;
@property(nonatomic, readwrite, copy) NSString *secretToken;
@property(nonatomic, readwrite, assign) int maxAppDataSize;
@property(nonatomic, readwrite, assign) UpstreamForceReconnect upstreamForceReconnect;

@end

@implementation FIRMessagingDataMessageManager

- (instancetype)initWithDelegate:(id<FIRMessagingDataMessageManagerDelegate>)delegate
                          client:(FIRMessagingClient *)client
                     rmq2Manager:(FIRMessagingRmqManager *)rmq2Manager
              syncMessageManager:(FIRMessagingSyncMessageManager *)syncMessageManager {
  self = [super init];
  if (self) {
    _delegate = delegate;
    _client = client;
    _rmq2Manager = rmq2Manager;
    _syncMessageManager = syncMessageManager;
    _ttl = kFIRMessagingSendTtlDefault;
    _maxAppDataSize = kMaxAppDataSizeDefault;
    // on by default
    _upstreamForceReconnect = kUpstreamForceReconnectAll;
  }
  return self;
}

- (void)setDeviceAuthID:(NSString *)deviceAuthID secretToken:(NSString *)secretToken {
  _FIRMessagingDevAssert([deviceAuthID length] && [secretToken length],
                @"Invalid credentials for FIRMessaging");
  self.deviceAuthID = deviceAuthID;
  self.secretToken = secretToken;
}

- (void)refreshDelayedMessages {
  FIRMessaging_WEAKIFY(self);
  self.delayedMessagesQueue =
      [[FIRMessagingDelayedMessageQueue alloc] initWithRmqScanner:self.rmq2Manager
                              sendDelayedMessagesHandler:^(NSArray *messages) {
                                FIRMessaging_STRONGIFY(self);
                                [self sendDelayedMessages:messages];
                              }];
}

- (nullable NSDictionary *)processPacket:(GtalkDataMessageStanza *)dataMessage {
  NSString *category = dataMessage.category;
  NSString *from = dataMessage.from;
  if ([kFCMMessageCategory isEqualToString:category] ||
      [kGSFMessageCategory isEqualToString:category]) {
    [self handleMCSDataMessage:dataMessage];
    return nil;
  } else if ([kFromForFIRMessagingMessages isEqualToString:from]) {
    [self handleMCSDataMessage:dataMessage];
    return nil;
  }

  return [self parseDataMessage:dataMessage];
}

- (void)handleMCSDataMessage:(GtalkDataMessageStanza *)dataMessage {
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeDataMessageManager000,
                          @"Received message for FIRMessaging from downstream %@", dataMessage);
}

- (NSDictionary *)parseDataMessage:(GtalkDataMessageStanza *)dataMessage {
  NSMutableDictionary *message = [NSMutableDictionary dictionary];
  NSString *from = [dataMessage from];
  if ([from length]) {
    message[kFIRMessagingFromKey] = from;
  }

  // raw data
  NSData *rawData = [dataMessage rawData];
  if ([rawData length]) {
    message[kFIRMessagingRawDataKey] = rawData;
  }

  NSString *token = [dataMessage token];
  if ([token length]) {
    message[kFIRMessagingCollapseKey] = token;
  }

  // Add the persistent_id. This would be removed later before sending the message to the device.
  NSString *persistentID = [dataMessage persistentId];
  _FIRMessagingDevAssert([persistentID length], @"Invalid MCS message without persistentID");
  if ([persistentID length]) {
    message[kFIRMessagingMessageIDKey] = persistentID;
  }

  // third-party data
  for (GtalkAppData *item in dataMessage.appDataArray) {
    _FIRMessagingDevAssert(item.hasKey && item.hasValue, @"Invalid AppData");

    // do not process the "from" key -- is not useful
    if ([kFIRMessagingFromKey isEqualToString:item.key]) {
      continue;
    }

    // Filter the "gcm.notification." keys in the message
    if ([item.key hasPrefix:kMCSNotificationPrefix]) {
      NSString *key = [item.key substringFromIndex:[kMCSNotificationPrefix length]];
      if ([key length]) {
        if (!message[kDataMessageNotificationKey]) {
          message[kDataMessageNotificationKey] = [NSMutableDictionary dictionary];
        }
        message[kDataMessageNotificationKey][key] = item.value;
      } else {
        _FIRMessagingDevAssert([key length], @"Invalid key in MCS message: %@", key);
        FIRMessagingLoggerError(kFIRMessagingMessageCodeDataMessageManager001,
                                @"Invalid key in MCS message: %@", key);
      }
      continue;
    }

    // Filter the "gcm.duplex" key
    if ([item.key isEqualToString:kFIRMessagingMessageSyncViaMCSKey]) {
      BOOL value = [item.value boolValue];
      message[kFIRMessagingMessageSyncViaMCSKey] = @(value);
      continue;
    }

    // do not allow keys with "reserved" keyword
    if ([[item.key lowercaseString] hasPrefix:kMessageReservedPrefix]) {
      continue;
    }

    [message setObject:item.value forKey:item.key];
  }
  // TODO: Add support for encrypting raw data later
  return [NSDictionary dictionaryWithDictionary:message];
}

- (void)didReceiveParsedMessage:(NSDictionary *)message {
  if ([message[kFCMMessageSpecialMessage] length]) {
    NSString *messageType = message[kFCMMessageSpecialMessage];
    if ([kFCMMessageTypeDeletedMessages isEqualToString:messageType]) {
      // TODO: Maybe trim down message to remove some unnecessary fields.
      // tell the FCM receiver of deleted messages
      [self.delegate didDeleteMessagesOnServer];
      return;
    }
    FIRMessagingLoggerError(kFIRMessagingMessageCodeDataMessageManager002,
                            @"Invalid message type received: %@", messageType);
  } else if (message[kFIRMessagingMessageSyncViaMCSKey]) {
    // Update SYNC_RMQ with the message
    BOOL isDuplicate = [self.syncMessageManager didReceiveMCSSyncMessage:message];
    if (isDuplicate) {
      return;
    }
  }
  NSString *messageId = message[kFIRMessagingMessageIDKey];
  NSDictionary *filteredMessage = [self filterInternalFIRMessagingKeysFromMessage:message];
  [self.delegate didReceiveMessage:filteredMessage withIdentifier:messageId];
}

- (NSDictionary *)filterInternalFIRMessagingKeysFromMessage:(NSDictionary *)message {
  NSMutableDictionary *newMessage = [NSMutableDictionary dictionaryWithDictionary:message];
  for (NSString *key in message) {
    if ([key hasPrefix:kFIRMessagingMessageInternalReservedKeyword]) {
      [newMessage removeObjectForKey:key];
    }
  }
  return [newMessage copy];
}

- (void)sendDataMessageStanza:(NSMutableDictionary *)dataMessage {
  NSNumber *ttlNumber = dataMessage[kFIRMessagingSendTTL];
  NSString *to = dataMessage[kFIRMessagingSendTo];
  NSString *msgId = dataMessage[kFIRMessagingSendMessageID];
  NSString *appPackage = [self categoryForUpstreamMessages];
  GtalkDataMessageStanza *stanza = [[GtalkDataMessageStanza alloc] init];

  // TODO: enforce TTL (right now only ttl=0 is special, means no storage)
  int ttl = [ttlNumber intValue];
  if (ttl < 0 || ttl > self.ttl) {
    ttl = self.ttl;
  }
  [stanza setTtl:ttl];
  [stanza setSent:FIRMessagingCurrentTimestampInSeconds()];

  int delay = [self delayForMessage:dataMessage];
  if (delay > 0) {
    [stanza setMaxDelay:delay];
  }

  if (msgId) {
    [stanza setId_p:msgId];
  }

  // collapse key as given by the sender
  NSString *token = dataMessage[KFIRMessagingSendMessageAppData][kFIRMessagingCollapseKey];
  if ([token length]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeDataMessageManager003,
                            @"FIRMessaging using %@ as collapse key", token);
    [stanza setToken:token];
  }

  if (!self.secretToken) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeDataMessageManager004,
                            @"Trying to send data message without a secret token. "
                            @"Authentication failed.");
    [self willSendDataMessageFail:stanza
                    withMessageId:msgId
                            error:kFIRMessagingErrorCodeMissingDeviceID];
    return;
  }

  if (![to length]) {
    [self willSendDataMessageFail:stanza withMessageId:msgId error:kFIRMessagingErrorMissingTo];
    return;
  }
  [stanza setTo:to];
  [stanza setCategory:appPackage];
  // required field in the proto this is set by the server
  // set it to a sentinel so the runtime doesn't throw an exception
  [stanza setFrom:@""];

  // MCS itself would set the registration ID
  // [stanza setRegId:nil];

  int size = [self addData:dataMessage[KFIRMessagingSendMessageAppData] toStanza:stanza];
  if (size > kMaxAppDataSizeDefault) {
    [self willSendDataMessageFail:stanza withMessageId:msgId error:kFIRMessagingErrorSizeExceeded];
    return;
  }

  BOOL useRmq = (ttl != 0) && (msgId != nil);
  if (useRmq) {
    if (!self.client.isConnected) {
      // do nothing assuming rmq save is enabled
    }

    NSError *error;
    if (![self.rmq2Manager saveRmqMessage:stanza error:&error]) {
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeDataMessageManager005, @"%@", error);
      [self willSendDataMessageFail:stanza withMessageId:msgId error:kFIRMessagingErrorSave];
      return;
    }

    [self willSendDataMessageSuccess:stanza withMessageId:msgId];
  }

  // if delay > 0 we don't really care about sending the message right now
  // so we piggy-back on any other urgent(delay = 0) message that we are sending
  if (delay > 0 && [self delayMessage:stanza]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeDataMessageManager006, @"Delaying Message %@",
                            dataMessage);
    return;
  }
  // send delayed messages
  [self sendDelayedMessages:[self.delayedMessagesQueue removeDelayedMessages]];

  BOOL sending = [self tryToSendDataMessageStanza:stanza];
  if (!sending) {
    if (useRmq) {
      NSString *event __unused = [NSString stringWithFormat:@"Queued message: %@", [stanza id_p]];
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeDataMessageManager007, @"%@", event);
    } else {
      [self willSendDataMessageFail:stanza
                      withMessageId:msgId
                              error:kFIRMessagingErrorCodeNetwork];
      return;
    }
  }
}

- (void)sendDelayedMessages:(NSArray *)delayedMessages {
  for (GtalkDataMessageStanza *message in delayedMessages) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeDataMessageManager008,
                            @"%@ Sending delayed message %@", @"DMM", message);
    [message setActualDelay:(int)(FIRMessagingCurrentTimestampInSeconds() - message.sent)];
    [self tryToSendDataMessageStanza:message];
  }
}

- (void)didSendDataMessageStanza:(GtalkDataMessageStanza *)message {
  NSString *msgId = [message id_p] ?: @"";
  [self.delegate didSendDataMessageWithID:msgId];
}

- (void)addParamWithKey:(NSString *)key
                  value:(NSString *)val
               toStanza:(GtalkDataMessageStanza *)stanza {
  if (!key || !val) {
    return;
  }
  GtalkAppData *appData = [[GtalkAppData alloc] init];
  [appData setKey:key];
  [appData setValue:val];
  [[stanza appDataArray] addObject:appData];
}

/**
 @return The size of the data being added to stanza.
 */
- (int)addData:(NSDictionary *)data toStanza:(GtalkDataMessageStanza *)stanza {
  int size = 0;
  for (NSString *key in data) {
    NSObject *val = data[key];
    if ([val isKindOfClass:[NSString class]]) {
      NSString *strVal = (NSString *)val;
      [self addParamWithKey:key value:strVal toStanza:stanza];
      size += [key length] + [strVal length];
    } else if ([val isKindOfClass:[NSNumber class]]) {
      NSString *strVal = [(NSNumber *)val stringValue];
      [self addParamWithKey:key value:strVal toStanza:stanza];
      size += [key length] + [strVal length];
    } else if ([kFIRMessagingRawDataKey isEqualToString:key] &&
               [val isKindOfClass:[NSData class]]) {
      NSData *rawData = (NSData *)val;
      [stanza setRawData:[rawData copy]];
      size += [rawData length];
    } else {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeDataMessageManager009, @"Ignoring key: %@",
                              key);
    }
  }
  return size;
}

/**
 * Notify the messenger that send data message completed with success. This is called for
 * TTL=0, after the message has been sent, or when message is saved, to unlock the send()
 * method.
 */
- (void)willSendDataMessageSuccess:(GtalkDataMessageStanza *)stanza
                     withMessageId:(NSString *)messageId {
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeDataMessageManager010,
                          @"send message success: %@", messageId);
  [self.delegate willSendDataMessageWithID:messageId error:nil];
}

/**
 * We send 'send failures' from server as normal FIRMessaging messages, with a 'message_type'
 * extra - same as 'message deleted'.
 *
 * For TTL=0 or errors that can be detected during send ( too many messages, invalid, etc)
 * we throw IOExceptions
 */
- (void)willSendDataMessageFail:(GtalkDataMessageStanza *)stanza
                  withMessageId:(NSString *)messageId
                          error:(FIRMessagingInternalErrorCode)errorCode {
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeDataMessageManager011,
                          @"Send message fail: %@ error: %lu", messageId, (unsigned long)errorCode);

  NSError *error = [NSError errorWithFCMErrorCode:errorCode];
  if ([self.delegate respondsToSelector:@selector(willSendDataMessageWithID:error:)]) {
    [self.delegate willSendDataMessageWithID:messageId error:error];
  }
}

- (void)resendMessagesWithConnection:(FIRMessagingConnection *)connection {
  NSMutableString *rmqIdsResent = [NSMutableString string];
  NSMutableArray *toRemoveRmqIds = [NSMutableArray array];
  FIRMessaging_WEAKIFY(self);
  FIRMessaging_WEAKIFY(connection);
  FIRMessagingRmqMessageHandler messageHandler = ^(int64_t rmqId, int8_t tag, NSData *data) {
    FIRMessaging_STRONGIFY(self);
    FIRMessaging_STRONGIFY(connection);
    GPBMessage *proto =
        [FIRMessagingGetClassForTag((FIRMessagingProtoTag)tag) parseFromData:data error:NULL];
    if ([proto isKindOfClass:GtalkDataMessageStanza.class]) {
      GtalkDataMessageStanza *stanza = (GtalkDataMessageStanza *)proto;

      if (![self handleExpirationForDataMessage:stanza]) {
        // time expired let's delete from RMQ
        [toRemoveRmqIds addObject:stanza.persistentId];
        return;
      }
      [rmqIdsResent appendString:[NSString stringWithFormat:@"%@,", stanza.id_p]];
    }

    [connection sendProto:proto];
  };
  [self.rmq2Manager scanWithRmqMessageHandler:messageHandler
                           dataMessageHandler:nil];

  if ([rmqIdsResent length]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeDataMessageManager012, @"Resent: %@",
                            rmqIdsResent);
  }

  if ([toRemoveRmqIds count]) {
    [self.rmq2Manager removeRmqMessagesWithRmqIds:toRemoveRmqIds];
  }
}

/**
 *  Check the TTL and generate an error if needed.
 *
 *  @return false if the message needs to be deleted
 */
- (BOOL)handleExpirationForDataMessage:(GtalkDataMessageStanza *)message {
  if (message.ttl == 0) {
    return NO;
  }

  int64_t now = FIRMessagingCurrentTimestampInSeconds();
  if (now > message.sent + message.ttl) {
    [self willSendDataMessageFail:message
                    withMessageId:message.id_p
                            error:kFIRMessagingErrorServiceNotAvailable];
    return NO;
  }
  return YES;
}

#pragma mark - Private

- (int)delayForMessage:(NSMutableDictionary *)message {
  int delay = 0; // default
  if (message[kFIRMessagingSendDelay]) {
    delay = [message[kFIRMessagingSendDelay] intValue];
    [message removeObjectForKey:kFIRMessagingSendDelay];
    if (delay < kMinDelaySeconds) {
      delay = 0;
    } else if (delay > kMaxDelaySeconds) {
      delay = kMaxDelaySeconds;
    }
  }
  return delay;
}

// return True if successfully delayed else False
- (BOOL)delayMessage:(GtalkDataMessageStanza *)message {
  return [self.delayedMessagesQueue queueMessage:message];
}

- (BOOL)tryToSendDataMessageStanza:(GtalkDataMessageStanza *)stanza {
  if (self.client.isConnectionActive) {
    [self.client sendMessage:stanza];
    return YES;
  }

  // if we only reconnect for TTL = 0 messages check if we ttl = 0 or
  // if we reconnect for all messages try to reconnect
  if ((self.upstreamForceReconnect == kUpstreamForceReconnectTTL0 && stanza.ttl == 0) ||
      self.upstreamForceReconnect == kUpstreamForceReconnectAll) {
    BOOL isNetworkAvailable = [[FIRMessaging messaging] isNetworkAvailable];
    if (isNetworkAvailable) {
      if (stanza.ttl == 0) {
        // Add TTL = 0 messages to be sent on next connect. TTL != 0 messages are
        // persisted, and will be sent from the RMQ.
        [self.client sendOnConnectOrDrop:stanza];
      }

      [self.client retryConnectionImmediately:YES];
      return YES;
    }
  }
  return NO;
}

- (NSString *)categoryForUpstreamMessages {
  return FIRMessagingAppIdentifier();
}

@end
