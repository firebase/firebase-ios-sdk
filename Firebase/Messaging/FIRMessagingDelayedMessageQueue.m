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

#import "Firebase/Messaging/FIRMessagingDelayedMessageQueue.h"

#import "Firebase/Messaging/Protos/GtalkCore.pbobjc.h"

#import "Firebase/Messaging/FIRMessagingDefines.h"
#import "Firebase/Messaging/FIRMessagingRmqManager.h"
#import "Firebase/Messaging/FIRMessagingUtilities.h"

static const int kMaxQueuedMessageCount = 10;

@interface FIRMessagingDelayedMessageQueue ()

@property(nonatomic, readonly, weak) id<FIRMessagingRmqScanner> rmqScanner;
@property(nonatomic, readonly, copy) FIRMessagingSendDelayedMessagesHandler sendDelayedMessagesHandler;

@property(nonatomic, readwrite, assign) int persistedMessageCount;
// the scheduled timeout or -1 if not set
@property(nonatomic, readwrite, assign) int64_t scheduledTimeoutMilliseconds;
// The time  of the last scan of the message DB,
// used to avoid retrieving messages more than once.
@property(nonatomic, readwrite, assign) int64_t lastDBScanTimestampSeconds;

@property(nonatomic, readwrite, strong) NSMutableArray *messages;
@property(nonatomic, readwrite, strong) NSTimer *sendTimer;

@end

@implementation FIRMessagingDelayedMessageQueue

- (instancetype)init {
  FIRMessagingInvalidateInitializer();
}

- (instancetype)initWithRmqScanner:(id<FIRMessagingRmqScanner>)rmqScanner
        sendDelayedMessagesHandler:(FIRMessagingSendDelayedMessagesHandler)sendDelayedMessagesHandler {
  self = [super init];
  if (self) {
    _rmqScanner = rmqScanner;
    _sendDelayedMessagesHandler = sendDelayedMessagesHandler;
    _messages = [NSMutableArray arrayWithCapacity:10];
    _scheduledTimeoutMilliseconds = -1;
  }
  return self;
}

- (BOOL)queueMessage:(GtalkDataMessageStanza *)message {
  if (self.messages.count >= kMaxQueuedMessageCount) {
    return NO;
  }
  if (message.ttl == 0) {
    // ttl=0 messages aren't persisted, add it to memory
    [self.messages addObject:message];
  } else {
    self.persistedMessageCount++;
  }
  int64_t timeoutMillis = [self calculateTimeoutInMillisWithDelayInSeconds:message.maxDelay];
  if (![self isTimeoutScheduled] || timeoutMillis < self.scheduledTimeoutMilliseconds) {
    [self scheduleTimeoutInMillis:timeoutMillis];
  }
  return YES;
}

- (NSArray *)removeDelayedMessages {
  [self cancelTimeout];
  if ([self messageCount] == 0) {
    return @[];
  }

  NSMutableArray *delayedMessages = [NSMutableArray array];
  // add the ttl=0 messages
  if (self.messages.count) {
    [delayedMessages addObjectsFromArray:delayedMessages];
    [self.messages removeAllObjects];
  }

  // add persistent messages
  if (self.persistedMessageCount > 0) {
    FIRMessaging_WEAKIFY(self);
    [self.rmqScanner scanWithRmqMessageHandler:nil
                            dataMessageHandler:^(int64_t rmqId, GtalkDataMessageStanza *stanza) {
                              FIRMessaging_STRONGIFY(self);
                              if ([stanza hasMaxDelay] &&
                                  [stanza sent] >= self.lastDBScanTimestampSeconds) {
                                [delayedMessages addObject:stanza];
                              }
                            }];
    self.lastDBScanTimestampSeconds = FIRMessagingCurrentTimestampInSeconds();
    self.persistedMessageCount = 0;
  }
  return delayedMessages;
}

- (void)sendMessages {
  if (self.sendDelayedMessagesHandler) {
    self.sendDelayedMessagesHandler([self removeDelayedMessages]);
  }
}

#pragma mark - Private

- (NSInteger)messageCount {
  return self.messages.count + self.persistedMessageCount;
}

- (BOOL)isTimeoutScheduled {
  return self.scheduledTimeoutMilliseconds > 0;
}

- (int64_t)calculateTimeoutInMillisWithDelayInSeconds:(int)delay {
  return FIRMessagingCurrentTimestampInMilliseconds() + delay * 1000.0;
}

- (void)scheduleTimeoutInMillis:(int64_t)time {
  [self cancelTimeout];
  self.scheduledTimeoutMilliseconds = time;
  double delay = (time - FIRMessagingCurrentTimestampInMilliseconds()) / 1000.0;
  [self performSelector:@selector(sendMessages) withObject:self afterDelay:delay];
}

- (void)cancelTimeout {
  if ([self isTimeoutScheduled]) {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(sendMessages)
                                               object:nil];
    self.scheduledTimeoutMilliseconds = -1;
  }
}

@end
