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

#import "Firebase/Messaging/FIRMessagingPubSub.h"

#import <GoogleUtilities/GULUserDefaults.h>
#import <FirebaseMessaging/FIRMessaging.h>

#import "Firebase/Messaging/FIRMessagingClient.h"
#import "Firebase/Messaging/FIRMessagingDefines.h"
#import "Firebase/Messaging/FIRMessagingLogger.h"
#import "Firebase/Messaging/FIRMessagingPendingTopicsList.h"
#import "Firebase/Messaging/FIRMessagingUtilities.h"
#import "Firebase/Messaging/FIRMessaging_Private.h"
#import "Firebase/Messaging/NSDictionary+FIRMessaging.h"
#import "Firebase/Messaging/NSError+FIRMessaging.h"

static NSString *const kPendingSubscriptionsListKey =
    @"com.firebase.messaging.pending-subscriptions";

@interface FIRMessagingPubSub () <FIRMessagingPendingTopicsListDelegate>

@property(nonatomic, readwrite, strong) FIRMessagingPendingTopicsList *pendingTopicUpdates;
@property(nonatomic, readwrite, strong) FIRMessagingClient *client;

@end

@implementation FIRMessagingPubSub

- (instancetype)init {
  FIRMessagingInvalidateInitializer();
  // Need this to disable an Xcode warning.
  return [self initWithClient:nil];
}

- (instancetype)initWithClient:(FIRMessagingClient *)client {
  self = [super init];
  if (self) {
    _client = client;
    [self restorePendingTopicsList];
  }
  return self;
}

- (void)subscribeWithToken:(NSString *)token
                     topic:(NSString *)topic
                   options:(NSDictionary *)options
                   handler:(FIRMessagingTopicOperationCompletion)handler {
  if (!self.client) {
    handler([NSError errorWithFCMErrorCode:kFIRMessagingErrorCodePubSubFIRMessagingNotSetup]);
    return;
  }

  token = [token copy];
  topic = [topic copy];

  if (![options count]) {
    options = @{};
  }

  if (![[self class] isValidTopicWithPrefix:topic]) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodePubSub000,
                            @"Invalid FIRMessaging Pubsub topic %@", topic);
    handler([NSError errorWithFCMErrorCode:kFIRMessagingErrorCodePubSubInvalidTopic]);
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

  [self.client updateSubscriptionWithToken:token
                                     topic:topic
                                   options:options
                              shouldDelete:NO
                                   handler:^void(NSError *error) {
                                     handler(error);
                                   }];
}

- (void)unsubscribeWithToken:(NSString *)token
                       topic:(NSString *)topic
                     options:(NSDictionary *)options
                     handler:(FIRMessagingTopicOperationCompletion)handler {
  if (!self.client) {
    handler([NSError errorWithFCMErrorCode:kFIRMessagingErrorCodePubSubFIRMessagingNotSetup]);
    return;
  }
  token = [token copy];
  topic = [topic copy];
  if (![options count]) {
    options = @{};
  }

  if (![[self class] isValidTopicWithPrefix:topic]) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodePubSub002,
                            @"Invalid FIRMessaging Pubsub topic %@", topic);
    handler([NSError errorWithFCMErrorCode:kFIRMessagingErrorCodePubSubInvalidTopic]);
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

  [self.client updateSubscriptionWithToken:token
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  NSData *pendingData = [NSKeyedArchiver archivedDataWithRootObject:topicsList];
#pragma clang diagnostic pop
  [defaults setObject:pendingData forKey:kPendingSubscriptionsListKey];
  [defaults synchronize];
}

- (void)restorePendingTopicsList {
  GULUserDefaults *defaults = [GULUserDefaults standardUserDefaults];
  NSData *pendingData = [defaults objectForKey:kPendingSubscriptionsListKey];
  FIRMessagingPendingTopicsList *subscriptions;
  @try {
    if (pendingData) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      subscriptions = [NSKeyedUnarchiver unarchiveObjectWithData:pendingData];
#pragma clang diagnostic pop
    }
  } @catch (NSException *exception) {
    // Nothing we can do, just continue as if we don't have pending subscriptions
  } @finally {
    if (subscriptions) {
      self.pendingTopicUpdates = subscriptions;
    } else {
      self.pendingTopicUpdates = [[FIRMessagingPendingTopicsList alloc] init];
    }
    self.pendingTopicUpdates.delegate = self;
  }
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
 *  @param expression The topic expression used to generate a pubsub topic
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
