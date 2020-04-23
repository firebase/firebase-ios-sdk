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

#import "FirebaseMessaging/Sources/FIRMessagingPendingTopicsList.h"

#import "FirebaseMessaging/Sources/FIRMessagingDefines.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/FIRMessagingPubSub.h"
#import "FirebaseMessaging/Sources/FIRMessaging_Private.h"

NSString *const kPendingTopicBatchActionKey = @"action";
NSString *const kPendingTopicBatchTopicsKey = @"topics";

NSString *const kPendingBatchesEncodingKey = @"batches";
NSString *const kPendingTopicsTimestampEncodingKey = @"ts";

#pragma mark - FIRMessagingTopicBatch

@interface FIRMessagingTopicBatch ()

@property(nonatomic, strong, nonnull)
    NSMutableDictionary<NSString *, NSMutableArray<FIRMessagingTopicOperationCompletion> *>
        *topicHandlers;

@end

@implementation FIRMessagingTopicBatch

- (instancetype)initWithAction:(FIRMessagingTopicAction)action {
  if (self = [super init]) {
    _action = action;
    _topics = [NSMutableSet set];
    _topicHandlers = [NSMutableDictionary dictionary];
  }
  return self;
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeInteger:self.action forKey:kPendingTopicBatchActionKey];
  [aCoder encodeObject:self.topics forKey:kPendingTopicBatchTopicsKey];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  // Ensure that our integer -> enum casting is safe
  NSInteger actionRawValue = [aDecoder decodeIntegerForKey:kPendingTopicBatchActionKey];
  FIRMessagingTopicAction action = FIRMessagingTopicActionSubscribe;
  if (actionRawValue == FIRMessagingTopicActionUnsubscribe) {
    action = FIRMessagingTopicActionUnsubscribe;
  }

  if (self = [self initWithAction:action]) {
    _topics = [aDecoder
        decodeObjectOfClasses:[NSSet setWithObjects:NSMutableSet.class, NSString.class, nil]
                       forKey:kPendingTopicBatchTopicsKey];
    _topicHandlers = [NSMutableDictionary dictionary];
  }
  return self;
}

@end

#pragma mark - FIRMessagingPendingTopicsList

@interface FIRMessagingPendingTopicsList ()

@property(nonatomic, readwrite, strong) NSDate *archiveDate;
@property(nonatomic, strong) NSMutableArray<FIRMessagingTopicBatch *> *topicBatches;

@property(nonatomic, strong) FIRMessagingTopicBatch *currentBatch;
@property(nonatomic, strong) NSMutableSet<NSString *> *topicsInFlight;

@end

@implementation FIRMessagingPendingTopicsList

- (instancetype)init {
  if (self = [super init]) {
    _topicBatches = [NSMutableArray array];
    _topicsInFlight = [NSMutableSet set];
  }
  return self;
}

+ (void)pruneTopicBatches:(NSMutableArray<FIRMessagingTopicBatch *> *)topicBatches {
  // For now, just remove empty batches. In the future we can use this to make the subscriptions
  // more efficient, by actually pruning topic actions that cancel each other out, for example.
  for (NSInteger i = topicBatches.count - 1; i >= 0; i--) {
    FIRMessagingTopicBatch *batch = topicBatches[i];
    if (batch.topics.count == 0) {
      [topicBatches removeObjectAtIndex:i];
    }
  }
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:[NSDate date] forKey:kPendingTopicsTimestampEncodingKey];
  [aCoder encodeObject:self.topicBatches forKey:kPendingBatchesEncodingKey];
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
  if (self = [self init]) {
    _archiveDate =
        [aDecoder decodeObjectOfClass:NSDate.class forKey:kPendingTopicsTimestampEncodingKey];
    _topicBatches =
        [aDecoder decodeObjectOfClasses:[NSSet setWithObjects:NSMutableArray.class,
                                                              FIRMessagingTopicBatch.class, nil]
                                 forKey:kPendingBatchesEncodingKey];
    if (_topicBatches) {
      [FIRMessagingPendingTopicsList pruneTopicBatches:_topicBatches];
    }
    _topicsInFlight = [NSMutableSet set];
  }
  return self;
}

#pragma mark Getters

- (NSUInteger)numberOfBatches {
  return self.topicBatches.count;
}

#pragma mark Adding/Removing topics

- (void)addOperationForTopic:(NSString *)topic
                  withAction:(FIRMessagingTopicAction)action
                  completion:(nullable FIRMessagingTopicOperationCompletion)completion {
  FIRMessagingTopicBatch *lastBatch = nil;
  @synchronized(self) {
    lastBatch = self.topicBatches.lastObject;
    if (!lastBatch || lastBatch.action != action) {
      // There either was no last batch, or our last batch's action was not the same, so we have to
      // create a new batch
      lastBatch = [[FIRMessagingTopicBatch alloc] initWithAction:action];
      [self.topicBatches addObject:lastBatch];
    }
    BOOL topicExistedBefore = ([lastBatch.topics member:topic] != nil);
    if (!topicExistedBefore) {
      [lastBatch.topics addObject:topic];
      [self.delegate pendingTopicsListDidUpdate:self];
    }
    // Add the completion handler to the batch
    if (completion) {
      NSMutableArray *handlers = lastBatch.topicHandlers[topic];
      if (!handlers) {
        handlers = [[NSMutableArray alloc] init];
      }
      [handlers addObject:completion];
      lastBatch.topicHandlers[topic] = handlers;
    }
    if (!self.currentBatch) {
      self.currentBatch = lastBatch;
    }
    // This may have been the first topic added, or was added to an ongoing batch
    if (self.currentBatch == lastBatch && !topicExistedBefore) {
      // Add this topic to our ongoing operations
      FIRMessaging_WEAKIFY(self);
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        FIRMessaging_STRONGIFY(self);
        [self resumeOperationsIfNeeded];
      });
    }
  }
}

- (void)resumeOperationsIfNeeded {
  @synchronized(self) {
    // If current batch is not set, set it now
    if (!self.currentBatch) {
      self.currentBatch = self.topicBatches.firstObject;
    }
    if (self.currentBatch.topics.count == 0) {
      return;
    }
    if (!self.delegate) {
      FIRMessagingLoggerError(kFIRMessagingMessageCodePendingTopicsList000,
                              @"Attempted to update pending topics without a delegate");
      return;
    }
    if (![self.delegate pendingTopicsListCanRequestTopicUpdates:self]) {
      return;
    }
    for (NSString *topic in self.currentBatch.topics) {
      if ([self.topicsInFlight member:topic]) {
        // This topic is already active, so skip
        continue;
      }
      [self beginUpdateForCurrentBatchTopic:topic];
    }
  }
}

- (BOOL)subscriptionErrorIsRecoverable:(NSError *)error {
  return [error.domain isEqualToString:NSURLErrorDomain];
}

- (void)beginUpdateForCurrentBatchTopic:(NSString *)topic {
  @synchronized(self) {
    [self.topicsInFlight addObject:topic];
  }
  FIRMessaging_WEAKIFY(self);
  [self.delegate
            pendingTopicsList:self
      requestedUpdateForTopic:topic
                       action:self.currentBatch.action
                   completion:^(NSError *error) {
                     dispatch_async(
                         dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                           FIRMessaging_STRONGIFY(self);
                           @synchronized(self) {
                             [self.topicsInFlight removeObject:topic];

                             BOOL recoverableError = [self subscriptionErrorIsRecoverable:error];
                             if (!error || !recoverableError) {
                               // Notify our handlers and remove the topic from our batch
                               NSMutableArray *handlers = self.currentBatch.topicHandlers[topic];
                               if (handlers.count) {
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                   for (FIRMessagingTopicOperationCompletion handler in handlers) {
                                     handler(error);
                                   }
                                   [handlers removeAllObjects];
                                 });
                               }
                               [self.currentBatch.topics removeObject:topic];
                               [self.currentBatch.topicHandlers removeObjectForKey:topic];
                               if (self.currentBatch.topics.count == 0) {
                                 // All topic updates successfully finished in this batch, move on
                                 // to the next batch
                                 [self.topicBatches removeObject:self.currentBatch];
                                 self.currentBatch = nil;
                               }
                               [self.delegate pendingTopicsListDidUpdate:self];
                               FIRMessaging_WEAKIFY(self);
                               dispatch_async(
                                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                                   ^{
                                     FIRMessaging_STRONGIFY(self);
                                     [self resumeOperationsIfNeeded];
                                   });
                             }
                           }
                         });
                   }];
}

@end
