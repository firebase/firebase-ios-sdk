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

#import "FirebaseMessaging/Sources/FIRMessagingPubSub.h"

#import <FirebaseInstanceID/FIRInstanceID_Private.h>
#import <FirebaseMessaging/FIRMessaging.h>
#import "GoogleUtilities/Environment/Private/GULSecureCoding.h"
#import "GoogleUtilities/UserDefaults/Private/GULUserDefaults.h"

#import "FirebaseMessaging/Sources/FIRMessagingClient.h"
#import "FirebaseMessaging/Sources/FIRMessagingDefines.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/FIRMessagingPendingTopicsList.h"
#import "FirebaseMessaging/Sources/FIRMessagingTopicOperation.h"
#import "FirebaseMessaging/Sources/FIRMessagingTopicsCommon.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/FIRMessaging_Private.h"
#import "FirebaseMessaging/Sources/NSDictionary+FIRMessaging.h"
#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"

static NSString *const kPendingSubscriptionsListKey =
    @"com.firebase.messaging.pending-subscriptions";

@interface FIRMessagingPubSub () <FIRMessagingPendingTopicsListDelegate>

@property(nonatomic, readwrite, strong) FIRMessagingPendingTopicsList *pendingTopicUpdates;
@property(nonatomic, readonly, strong) NSOperationQueue *topicOperations;
// Common errors, instantiated, to avoid generating multiple copies
@property(nonatomic, readwrite, strong) NSError *operationInProgressError;

@end

@implementation FIRMessagingPubSub

- (instancetype)init {
  self = [super init];
  if (self) {
    _topicOperations = [[NSOperationQueue alloc] init];
    // Do 10 topic operations at a time; it's enough to keep the TCP connection to the host alive,
    // saving hundreds of milliseconds on each request (compared to a serial queue).
    _topicOperations.maxConcurrentOperationCount = 10;
    [self restorePendingTopicsList];
  }
  return self;
}

- (void)subscribeWithToken:(NSString *)token
                     topic:(NSString *)topic
                   options:(NSDictionary *)options
                   handler:(FIRMessagingTopicOperationCompletion)handler {
  token = [token copy];
  topic = [topic copy];

  if (![options count]) {
    options = @{};
  }

  if (![[self class] isValidTopicWithPrefix:topic]) {
    NSString *failureReason =
        [NSString stringWithFormat:@"Invalid subscription topic :'%@'", topic];
    FIRMessagingLoggerError(kFIRMessagingMessageCodePubSub000, @"%@", failureReason);
    handler([NSError messagingErrorWithCode:kFIRMessagingErrorCodeInvalidTopicName
                              failureReason:failureReason]);
    return;
  }

  if (![self verifyPubSubOptions:options]) {
    // we do not want to quit even if options have some invalid values.
    FIRMessagingLoggerError(kFIRMessagingMessageCodePubSub001,
                            @"Invalid options passed to FIRMessagingPubSub with non-string keys or "
                             "values.");
  }
  // copy the dictionary would trim non-string keys or values if any.
  options = [options fcm_trimNonStringValues];

  [self updateSubscriptionWithToken:token
                              topic:topic
                            options:options
                       shouldDelete:NO
                            handler:handler];
}

- (void)dealloc {
  [self.topicOperations cancelAllOperations];
}

#pragma mark - FIRMessaging subscribe

- (void)updateSubscriptionWithToken:(NSString *)token
                              topic:(NSString *)topic
                            options:(NSDictionary *)options
                       shouldDelete:(BOOL)shouldDelete
                            handler:(FIRMessagingTopicOperationCompletion)handler {
  if ([[FIRInstanceID instanceID] tryToLoadValidCheckinInfo]) {
    FIRMessagingTopicAction action =
        shouldDelete ? FIRMessagingTopicActionUnsubscribe : FIRMessagingTopicActionSubscribe;
    FIRMessagingTopicOperation *operation = [[FIRMessagingTopicOperation alloc]
        initWithTopic:topic
               action:action
                token:token
              options:options
           completion:^(NSError *_Nullable error) {
             if (error) {
               FIRMessagingLoggerError(kFIRMessagingMessageCodeClient001,
                                       @"Failed to subscribe to topic %@", error);
             } else {
               if (shouldDelete) {
                 FIRMessagingLoggerInfo(kFIRMessagingMessageCodeClient002,
                                        @"Successfully unsubscribed from topic %@", topic);
               } else {
                 FIRMessagingLoggerInfo(kFIRMessagingMessageCodeClient003,
                                        @"Successfully subscribed to topic %@", topic);
               }
             }
             if (handler) {
               handler(error);
             }
           }];
    [self.topicOperations addOperation:operation];
  } else {
    NSString *failureReason = @"Device ID and checkin info is not found. Will not proceed with "
                              @"subscription/unsubscription.";
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeRegistrar000, @"%@", failureReason);
    NSError *error = [NSError messagingErrorWithCode:kFIRMessagingErrorCodeMissingDeviceID
                                       failureReason:failureReason];
    handler(error);
  }
}

- (void)unsubscribeWithToken:(NSString *)token
                       topic:(NSString *)topic
                     options:(NSDictionary *)options
                     handler:(FIRMessagingTopicOperationCompletion)handler {
  token = [token copy];
  topic = [topic copy];
  if (![options count]) {
    options = @{};
  }

  if (![[self class] isValidTopicWithPrefix:topic]) {
    NSString *failureReason =
        [NSString stringWithFormat:@"Invalid topic name : '%@' for unsubscription.", topic];
    FIRMessagingLoggerError(kFIRMessagingMessageCodePubSub002, @"%@", failureReason);
    handler([NSError messagingErrorWithCode:kFIRMessagingErrorCodeInvalidTopicName
                              failureReason:failureReason]);
    return;
  }
  if (![self verifyPubSubOptions:options]) {
    // we do not want to quit even if options have some invalid values.
    FIRMessagingLoggerError(
        kFIRMessagingMessageCodePubSub003,
        @"Invalid options passed to FIRMessagingPubSub with non-string keys or values.");
  }
  // copy the dictionary would trim non-string keys or values if any.
  options = [options fcm_trimNonStringValues];

  [self updateSubscriptionWithToken:token
                              topic:topic
                            options:options
                       shouldDelete:YES
                            handler:^void(NSError *error) {
                              handler(error);
                            }];
}

- (void)subscribeToTopic:(NSString *)topic
                 handler:(nullable FIRMessagingTopicOperationCompletion)handler {
  [self.pendingTopicUpdates addOperationForTopic:topic
                                      withAction:FIRMessagingTopicActionSubscribe
                                      completion:handler];
}

- (void)unsubscribeFromTopic:(NSString *)topic
                     handler:(nullable FIRMessagingTopicOperationCompletion)handler {
  [self.pendingTopicUpdates addOperationForTopic:topic
                                      withAction:FIRMessagingTopicActionUnsubscribe
                                      completion:handler];
}

- (void)scheduleSync:(BOOL)immediately {
  NSString *fcmToken = [[FIRMessaging messaging] defaultFcmToken];
  if (fcmToken.length) {
    [self.pendingTopicUpdates resumeOperationsIfNeeded];
  }
}

#pragma mark - FIRMessagingPendingTopicsListDelegate

- (void)pendingTopicsList:(FIRMessagingPendingTopicsList *)list
    requestedUpdateForTopic:(NSString *)topic
                     action:(FIRMessagingTopicAction)action
                 completion:(FIRMessagingTopicOperationCompletion)completion {
  NSString *fcmToken = [[FIRMessaging messaging] defaultFcmToken];
  if (action == FIRMessagingTopicActionSubscribe) {
    [self subscribeWithToken:fcmToken topic:topic options:nil handler:completion];
  } else {
    [self unsubscribeWithToken:fcmToken topic:topic options:nil handler:completion];
  }
}

- (void)pendingTopicsListDidUpdate:(FIRMessagingPendingTopicsList *)list {
  [self archivePendingTopicsList:list];
}

- (BOOL)pendingTopicsListCanRequestTopicUpdates:(FIRMessagingPendingTopicsList *)list {
  NSString *fcmToken = [[FIRMessaging messaging] defaultFcmToken];
  return (fcmToken.length > 0);
}

#pragma mark - Storing Pending Topics

- (void)archivePendingTopicsList:(FIRMessagingPendingTopicsList *)topicsList {
  GULUserDefaults *defaults = [GULUserDefaults standardUserDefaults];
  NSError *error;
  NSData *pendingData = [GULSecureCoding archivedDataWithRootObject:topicsList error:&error];
  if (error) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodePubSubArchiveError,
                            @"Failed to archive topic list data %@", error);
    return;
  }
  [defaults setObject:pendingData forKey:kPendingSubscriptionsListKey];
  [defaults synchronize];
}

- (void)restorePendingTopicsList {
  GULUserDefaults *defaults = [GULUserDefaults standardUserDefaults];
  NSData *pendingData = [defaults objectForKey:kPendingSubscriptionsListKey];
  FIRMessagingPendingTopicsList *subscriptions;
  if (pendingData) {
    NSError *error;
    subscriptions = [GULSecureCoding
        unarchivedObjectOfClasses:[NSSet setWithObjects:FIRMessagingPendingTopicsList.class, nil]
                         fromData:pendingData
                            error:&error];
    if (error) {
      FIRMessagingLoggerError(kFIRMessagingMessageCodePubSubUnarchiveError,
                              @"Failed to unarchive topic list data %@", error);
    }
  }
  if (subscriptions) {
    self.pendingTopicUpdates = subscriptions;
  } else {
    self.pendingTopicUpdates = [[FIRMessagingPendingTopicsList alloc] init];
  }
  self.pendingTopicUpdates.delegate = self;
}

#pragma mark - Private Helpers

- (BOOL)verifyPubSubOptions:(NSDictionary *)options {
  return ![options fcm_hasNonStringKeysOrValues];
}

#pragma mark - Topic Name Helpers

static NSString *const kTopicsPrefix = @"/topics/";
static NSString *const kTopicRegexPattern = @"/topics/([a-zA-Z0-9-_.~%]+)";

+ (NSString *)addPrefixToTopic:(NSString *)topic {
  if (![self hasTopicsPrefix:topic]) {
    return [NSString stringWithFormat:@"%@%@", kTopicsPrefix, topic];
  } else {
    return [topic copy];
  }
}

+ (NSString *)removePrefixFromTopic:(NSString *)topic {
  if ([self hasTopicsPrefix:topic]) {
    return [topic substringFromIndex:kTopicsPrefix.length];
  } else {
    return [topic copy];
  }
}

+ (BOOL)hasTopicsPrefix:(NSString *)topic {
  return [topic hasPrefix:kTopicsPrefix];
}

/**
 *  Returns a regular expression for matching a topic sender.
 *
 *  @return The topic matching regular expression
 */
+ (NSRegularExpression *)topicRegex {
  // Since this is a static regex pattern, we only only need to declare it once.
  static NSRegularExpression *topicRegex;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSError *error;
    topicRegex =
        [NSRegularExpression regularExpressionWithPattern:kTopicRegexPattern
                                                  options:NSRegularExpressionAnchorsMatchLines
                                                    error:&error];
  });
  return topicRegex;
}

/**
 *  Gets the class describing occurences of topic names and sender IDs in the sender.
 *
 *  @param topic The topic expression used to generate a pubsub topic
 *
 *  @return Representation of captured subexpressions in topic regular expression
 */
+ (BOOL)isValidTopicWithPrefix:(NSString *)topic {
  NSRange topicRange = NSMakeRange(0, topic.length);
  NSRange regexMatchRange = [[self topicRegex] rangeOfFirstMatchInString:topic
                                                                 options:NSMatchingAnchored
                                                                   range:topicRange];
  return NSEqualRanges(topicRange, regexMatchRange);
}

@end
