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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseInAppMessaging/Sources/FIRCore+InAppMessaging.h"
#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMFetchResponseParser.h"
#import "FirebaseInAppMessaging/Sources/Private/DisplayTrigger/FIRIAMDisplayTriggerDefinition.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMDisplayCheckOnAnalyticEventsFlow.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMMessageClientCache.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMServerMsgFetchStorage.h"

@interface FIRIAMMessageClientCache ()

// messages not for client-side testing
@property(nonatomic) NSMutableArray<FIRIAMMessageDefinition *> *regularMessages;
// messages for client-side testing
@property(nonatomic) NSMutableArray<FIRIAMMessageDefinition *> *testMessages;
@property(nonatomic, weak) id<FIRIAMCacheDataObserver> observer;
@property(nonatomic) NSMutableSet<NSString *> *firebaseAnalyticEventsToWatch;
@property(nonatomic) id<FIRIAMBookKeeper> bookKeeper;
@property(readonly, nonatomic) FIRIAMFetchResponseParser *responseParser;

@end

// Methods doing read and write operations on messages field is synchronized to avoid
// race conditions like change the array while iterating through it
@implementation FIRIAMMessageClientCache
- (instancetype)initWithBookkeeper:(id<FIRIAMBookKeeper>)bookKeeper
               usingResponseParser:(FIRIAMFetchResponseParser *)responseParser {
  if (self = [super init]) {
    _bookKeeper = bookKeeper;
    _responseParser = responseParser;
  }
  return self;
}

- (void)setDataObserver:(id<FIRIAMCacheDataObserver>)observer {
  self.observer = observer;
}

// reset messages data
- (void)setMessageData:(NSArray<FIRIAMMessageDefinition *> *)messages {
  @synchronized(self) {
    NSSet<NSString *> *impressionSet =
        [NSSet setWithArray:[self.bookKeeper getMessageIDsFromImpressions]];

    NSMutableArray<FIRIAMMessageDefinition *> *regularMessages = [[NSMutableArray alloc] init];
    self.testMessages = [[NSMutableArray alloc] init];

    // split between test vs non-test messages
    for (FIRIAMMessageDefinition *next in messages) {
      if (next.isTestMessage) {
        [self.testMessages addObject:next];
      } else {
        [regularMessages addObject:next];
      }
    }

    // while resetting the whole message set, we do prefiltering based on the impressions
    // data to get rid of messages we don't care so that the future searches are more efficient
    NSPredicate *notImpressedPredicate =
        [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
          FIRIAMMessageDefinition *message = (FIRIAMMessageDefinition *)evaluatedObject;
          return ![impressionSet containsObject:message.renderData.messageID];
        }];

    self.regularMessages =
        [[regularMessages filteredArrayUsingPredicate:notImpressedPredicate] mutableCopy];
    [self setupAnalyticsEventListening];
  }

  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM160001",
              @"There are %lu test messages and %lu regular messages and "
               "%lu Firebase Analytics events to watch after "
               "resetting the message cache",
              (unsigned long)self.testMessages.count, (unsigned long)self.regularMessages.count,
              (unsigned long)self.firebaseAnalyticEventsToWatch.count);
  [self.observer dataChanged];
}

// triggered after self.messages are updated so that we can correctly enable/disable listening
// on analytics event based on current fiam message set
- (void)setupAnalyticsEventListening {
  self.firebaseAnalyticEventsToWatch = [[NSMutableSet alloc] init];
  for (FIRIAMMessageDefinition *nextMessage in self.regularMessages) {
    // if it's event based triggering, add it to the watch set
    for (FIRIAMDisplayTriggerDefinition *nextTrigger in nextMessage.renderTriggers) {
      if (nextTrigger.triggerType == FIRIAMRenderTriggerOnFirebaseAnalyticsEvent) {
        [self.firebaseAnalyticEventsToWatch addObject:nextTrigger.firebaseEventName];
      }
    }
  }

  if (self.analycisEventDislayCheckFlow) {
    if ([self.firebaseAnalyticEventsToWatch count] > 0) {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM160010",
                  @"There are analytics event trigger based messages, enable listening");
      [self.analycisEventDislayCheckFlow start];
    } else {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM160011",
                  @"No analytics event trigger based messages, disable listening");
      [self.analycisEventDislayCheckFlow stop];
    }
  }
}

- (NSArray<FIRIAMMessageDefinition *> *)allRegularMessages {
  return [self.regularMessages copy];
}

- (BOOL)hasTestMessage {
  return self.testMessages.count > 0;
}

- (nullable FIRIAMMessageDefinition *)nextOnAppLaunchDisplayMsg {
  return [self nextMessageForTrigger:FIRIAMRenderTriggerOnAppLaunch];
}

- (nullable FIRIAMMessageDefinition *)nextOnAppOpenDisplayMsg {
  @synchronized(self) {
    // always first check test message which always have higher prirority
    if (self.testMessages.count > 0) {
      FIRIAMMessageDefinition *testMessage = self.testMessages[0];
      // always remove test message right away when being fetched for display
      [self.testMessages removeObjectAtIndex:0];
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM160007",
                  @"Returning a test message for app foreground display");
      return testMessage;
    }
  }

  // otherwise check for a message from a published campaign
  return [self nextMessageForTrigger:FIRIAMRenderTriggerOnAppForeground];
}

- (nullable FIRIAMMessageDefinition *)nextMessageForTrigger:(FIRIAMRenderTrigger)trigger {
  // search from the start to end in the list (which implies the display priority) for the
  // first match (some messages in the cache may not be eligible for the current display
  // message fetch
  NSSet<NSString *> *impressionSet =
      [NSSet setWithArray:[self.bookKeeper getMessageIDsFromImpressions]];

  @synchronized(self) {
    for (FIRIAMMessageDefinition *next in self.regularMessages) {
      // message being active and message not impressed yet
      if ([next messageHasStarted] && ![next messageHasExpired] &&
          ![impressionSet containsObject:next.renderData.messageID] &&
          [next messageRenderedOnTrigger:trigger]) {
        return next;
      }
    }
  }
  return nil;
}

- (nullable FIRIAMMessageDefinition *)nextOnFirebaseAnalyticEventDisplayMsg:(NSString *)eventName {
  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM160005",
              @"Inside nextOnFirebaseAnalyticEventDisplay for checking contextual trigger match");
  if (![self.firebaseAnalyticEventsToWatch containsObject:eventName]) {
    return nil;
  }

  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM160006",
              @"There could be a potential message match for analytics event %@", eventName);
  NSSet<NSString *> *impressionSet =
      [NSSet setWithArray:[self.bookKeeper getMessageIDsFromImpressions]];
  @synchronized(self) {
    for (FIRIAMMessageDefinition *next in self.regularMessages) {
      // message being active and message not impressed yet and the contextual trigger condition
      // match
      if ([next messageHasStarted] && ![next messageHasExpired] &&
          ![impressionSet containsObject:next.renderData.messageID] &&
          [next messageRenderedOnAnalyticsEvent:eventName]) {
        return next;
      }
    }
  }
  return nil;
}

- (void)removeMessageWithId:(NSString *)messageID {
  FIRIAMMessageDefinition *msgToRemove = nil;
  @synchronized(self) {
    for (FIRIAMMessageDefinition *next in self.regularMessages) {
      if ([next.renderData.messageID isEqualToString:messageID]) {
        msgToRemove = next;
        break;
      }
    }

    if (msgToRemove) {
      [self.regularMessages removeObject:msgToRemove];
      [self setupAnalyticsEventListening];
    }
  }

  // triggers the observer outside synchronization block
  if (msgToRemove) {
    [self.observer dataChanged];
  }
}

- (void)loadMessageDataFromServerFetchStorage:(FIRIAMServerMsgFetchStorage *)fetchStorage
                               withCompletion:(void (^)(BOOL success))completion {
  [fetchStorage readResponseDictionary:^(NSDictionary *_Nonnull response, BOOL success) {
    if (success) {
      NSInteger discardCount;
      NSNumber *fetchWaitTime;
      NSArray<FIRIAMMessageDefinition *> *messagesFromStorage =
          [self.responseParser parseAPIResponseDictionary:response
                                        discardedMsgCount:&discardCount
                                   fetchWaitTimeInSeconds:&fetchWaitTime];
      [self setMessageData:messagesFromStorage];
      completion(YES);
    } else {
      completion(NO);
    }
  }];
}
@end

#endif  // TARGET_OS_IOS
