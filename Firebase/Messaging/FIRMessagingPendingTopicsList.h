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

#import <Foundation/Foundation.h>

#import "FIRMessaging.h"
#import "FIRMessagingTopicsCommon.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  Represents a single batch of topics, with the same action.
 *
 *  Topic operations which have the same action (subscribe or unsubscribe) can be executed
 *  simultaneously, as the order of operations do not matter with the same action. The set of
 *  topics is unique, as it doesn't make sense to apply the same action to the same topic
 *  repeatedly; the result would be the same as the first time.
 */
@interface FIRMessagingTopicBatch : NSObject <NSCoding>

@property(nonatomic, readonly, assign) FIRMessagingTopicAction action;
@property(nonatomic, readonly, copy) NSMutableSet <NSString *> *topics;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithAction:(FIRMessagingTopicAction)action NS_DESIGNATED_INITIALIZER;

@end

@class FIRMessagingPendingTopicsList;
/**
 *  This delegate must be supplied to the instance of FIRMessagingPendingTopicsList, via the
 *  @cdelegate property. It lets the
 *  pending topics list know whether or not it can begin making requests via
 *  @c-pendingTopicsListCanRequestTopicUpdates:, and handles the request to actually
 *  perform the topic operation. The delegate also handles when the pending topics list is updated,
 *  so that it can be archived or persisted.
 *
 *  @see FIRMessagingPendingTopicsList
 */
@protocol FIRMessagingPendingTopicsListDelegate <NSObject>

- (void)pendingTopicsList:(FIRMessagingPendingTopicsList *)list
  requestedUpdateForTopic:(NSString *)topic
                   action:(FIRMessagingTopicAction)action
               completion:(FIRMessagingTopicOperationCompletion)completion;
- (void)pendingTopicsListDidUpdate:(FIRMessagingPendingTopicsList *)list;
- (BOOL)pendingTopicsListCanRequestTopicUpdates:(FIRMessagingPendingTopicsList *)list;

@end

/**
 *  FIRMessagingPendingTopicsList manages a list of topic subscription updates, batched by the same
 *  action (subscribe or unsubscribe). The list roughly maintains the order of the topic operations,
 *  batched together whenever the topic action (subscribe or unsubscribe) changes.
 *
 *  Topics operations are batched by action because it is safe to perform the same topic action
 *  (subscribe or unsubscribe) on many topics simultaneously. After each batch is successfully
 *  completed, the next batch operations can begin.
 *
 *  When asked to resume its operations, FIRMessagingPendingTopicsList will begin performing updates
 *  of its current batch of topics. For example, it may begin subscription operations for topics
 *  [A, B, C] simultaneously.
 *
 *  When the current batch is completed, the next batch of operations will be started. For example
 *  the list may begin unsubscribe operations for [D, A, E]. Note that because A is in both batches,
 *  A will be correctly subscribed in the first batch, then unsubscribed as part of the second batch
 *  of operations. Without batching, it would be ambiguous whether A's subscription operation or the
 *  unsubscription operation would be completed first.
 *
 *  An app can subscribe and unsubscribe from many topics, and this class helps persist the pending
 *  topics and perform the operation safely and correctly.
 *
 *  When a topic fails to subscribe or unsubscribe due to a network error, it is considered a
 *  recoverable error, and so it remains in the current batch until it is succesfully completed.
 *  Topic updates are completed when they either (a) succeed, (b) are cancelled, or (c) result in an
 *  unrecoverable error. Any error outside of `NSURLErrorDomain` is considered an unrecoverable
 *  error.
 *
 *  In addition to maintaining the list of pending topic updates, FIRMessagingPendingTopicsList also
 *  can track completion handlers for topic operations.
 *
 *  @discussion Completion handlers for topic updates are not maintained if it was restored from a
 *  keyed archive. They are only called if the topic operation finished within the same app session.
 *
 *  You must supply an object conforming to FIRMessagingPendingTopicsListDelegate in order for the
 *  topic operations to execute.
 *
 *  @see FIRMessagingPendingTopicsListDelegate
 */
@interface FIRMessagingPendingTopicsList : NSObject <NSCoding>

@property(nonatomic, weak) NSObject <FIRMessagingPendingTopicsListDelegate> *delegate;

@property(nonatomic, readonly, strong, nullable) NSDate *archiveDate;
@property(nonatomic, readonly) NSUInteger numberOfBatches;


- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (void)addOperationForTopic:(NSString *)topic
                  withAction:(FIRMessagingTopicAction)action
                  completion:(nullable FIRMessagingTopicOperationCompletion)completion;
- (void)resumeOperationsIfNeeded;

@end

NS_ASSUME_NONNULL_END
