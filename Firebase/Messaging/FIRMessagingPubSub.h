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

#import "FIRMessaging.h"

NS_ASSUME_NONNULL_BEGIN

@class FIRMessagingClient;
@class FIRMessagingPubSubCache;

/**
 *  FIRMessagingPubSub provides a publish-subscribe model for sending FIRMessaging topic messages.
 *
 *  An app can subscribe to different topics defined by the
 *  developer. The app server can then send messages to the subscribed devices
 *  without having to maintain topic-subscribers mapping. Topics do not
 *  need to be explicitly created before subscribing or publishing&mdash;they
 *  are automatically created when publishing or subscribing.
 *
 *  Messages published to the topic will be received as regular FIRMessaging messages
 *  with `"from"` set to `"/topics/myTopic"`.
 *
 *  Only topic names that match the pattern `"/topics/[a-zA-Z0-9-_.~%]{1,900}"`
 *  are allowed for subscribing and publishing.
 */
@interface FIRMessagingPubSub : NSObject

@property(nonatomic, readonly, strong) FIRMessagingPubSubCache *cache;
@property(nonatomic, readonly, strong) FIRMessagingClient *client;

/**
 *  Initializes an instance of FIRMessagingPubSub.
 *
 *  @return An instance of FIRMessagingPubSub.
 */
- (instancetype)initWithClient:(FIRMessagingClient *)client NS_DESIGNATED_INITIALIZER;

/**
 *  Subscribes an app instance to a topic, enabling it to receive messages
 *  sent to that topic.
 *
 *  This is an asynchronous call. If subscription fails, FIRMessaging
 *  invokes the completion callback with the appropriate error.
 *
 *  @see FIRMessagingPubSub unsubscribeWithToken:topic:handler:
 *
 *  @param token    The registration token as received from the InstanceID
 *                   library for a given `authorizedEntity` and "gcm" scope.
 *  @param topic    The topic to subscribe to. Should be of the form
 *                  `"/topics/<topic-name>"`.
 *  @param options  Unused parameter, please pass nil or empty dictionary.
 *  @param handler  The callback handler invoked when the subscribe call
 *                  ends. In case of success, a nil error is returned. Otherwise,
 *                  an appropriate error object is returned.
 *  @discussion     This method is thread-safe. However, it is not guaranteed to
 *                  return on the main thread.
 */
- (void)subscribeWithToken:(NSString *)token
                     topic:(NSString *)topic
                   options:(nullable NSDictionary *)options
                   handler:(FIRMessagingTopicOperationCompletion)handler;

/**
 *  Unsubscribes an app instance from a topic, stopping it from receiving
 *  any further messages sent to that topic.
 *
 *  This is an asynchronous call. If the attempt to unsubscribe fails,
 *  we invoke the `completion` callback passed in with an appropriate error.
 *
 *  @param token   The token used to subscribe to this topic.
 *  @param topic   The topic to unsubscribe from. Should be of the form
 *                 `"/topics/<topic-name>"`.
 *  @param options Unused parameter, please pass nil or empty dictionary.
 *  @param handler The handler that is invoked once the unsubscribe call ends.
 *                 In case of success, nil error is returned. Otherwise, an
 *                  appropriate error object is returned.
 *  @discussion     This method is thread-safe. However, it is not guaranteed to
 *                  return on the main thread.
 */
- (void)unsubscribeWithToken:(NSString *)token
                       topic:(NSString *)topic
                     options:(nullable NSDictionary *)options
                     handler:(FIRMessagingTopicOperationCompletion)handler;

/**
 *  Asynchronously subscribe to the topic. Adds to the pending list of topic operations.
 *  Retry in case of failures. This makes a repeated attempt to subscribe to the topic
 *  as compared to the `subscribe` method above which tries once.
 *
 *  @param topic The topic name to subscribe to. Should be of the form `"/topics/<topic-name>"`.
 *  @param handler The handler that is invoked once the unsubscribe call ends.
 *                 In case of success, nil error is returned. Otherwise, an
 *                  appropriate error object is returned.
 */
- (void)subscribeToTopic:(NSString *)topic
                 handler:(nullable FIRMessagingTopicOperationCompletion)handler;

/**
 *  Asynchronously unsubscribe from the topic. Adds to the pending list of topic operations.
 *  Retry in case of failures. This makes a repeated attempt to unsubscribe from the topic
 *  as compared to the `unsubscribe` method above which tries once.
 *
 *  @param topic The topic name to unsubscribe from. Should be of the form `"/topics/<topic-name>"`.
 *  @param handler The handler that is invoked once the unsubscribe call ends.
 *                 In case of success, nil error is returned. Otherwise, an
 *                  appropriate error object is returned.
 */
- (void)unsubscribeFromTopic:(NSString *)topic
                     handler:(nullable FIRMessagingTopicOperationCompletion)handler;

/**
 *  Schedule subscriptions sync.
 *
 *  @param immediately YES if the sync should be scheduled immediately else NO if we can delay
 *                     the sync.
 */
- (void)scheduleSync:(BOOL)immediately;

/**
 *  Adds the "/topics/" prefix to the topic.
 *
 *  @param topic The topic to add the prefix to.
 *
 *  @return The new topic name with the "/topics/" prefix added.
 */
+ (NSString *)addPrefixToTopic:(NSString *)topic;

/**
 *  Removes the "/topics/" prefix from the topic.
 *
 *  @param topic The topic to remove the prefix from.
 *
 *  @return The new topic name with the "/topics/" prefix removed.
 */

+ (NSString *)removePrefixFromTopic:(NSString *)topic;

/**
 *  Check if the topic name has "/topics/" prefix.
 *
 *  @param topic The topic name to verify.
 *
 *  @return YES if the topic name has "/topics/" prefix else NO.
 */
+ (BOOL)hasTopicsPrefix:(NSString *)topic;

/**
 *  Check if it's a valid topic name. This includes "/topics/" prefix in the topic name.
 *
 *  @param topic The topic name to verify.
 *
 *  @return YES if the topic name satisfies the regex "/topics/[a-zA-Z0-9-_.~%]{1,900}".
 */
+ (BOOL)isValidTopicWithPrefix:(NSString *)topic;

@end

NS_ASSUME_NONNULL_END
