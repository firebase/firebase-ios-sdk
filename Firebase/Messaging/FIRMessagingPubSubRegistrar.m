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

#import "FIRMessagingPubSubRegistrar.h"

#import "FIRMessagingDefines.h"
#import "FIRMessagingPubSubRegistrar.h"
#import "FIRMessagingTopicsCommon.h"
#import "NSError+FIRMessaging.h"

@interface FIRMessagingPubSubRegistrar ()

@property(nonatomic, readonly, strong) NSOperationQueue *topicOperations;
// Common errors, instantiated, to avoid generating multiple copies
@property(nonatomic, readwrite, strong) NSError *operationInProgressError;

@end

@implementation FIRMessagingPubSubRegistrar

- (instancetype)init {
  self = [super init];
  if (self) {
    _topicOperations = [[NSOperationQueue alloc] init];
    // Do 10 topic operations at a time; it's enough to keep the TCP connection to the host alive,
    // saving hundreds of milliseconds on each request (compared to a serial queue).
    _topicOperations.maxConcurrentOperationCount = 10;
  }
  return self;
}

- (void)stopAllSubscriptionRequests {
  [self.topicOperations cancelAllOperations];
}

- (void)updateSubscriptionToTopic:(NSString *)topic
                        withToken:(NSString *)token
                          options:(NSDictionary *)options
                     shouldDelete:(BOOL)shouldDelete
                          handler:(FIRMessagingTopicOperationCompletion)handler {

  FIRMessagingTopicAction action = FIRMessagingTopicActionSubscribe;
  if (shouldDelete) {
    action = FIRMessagingTopicActionUnsubscribe;
  }
  FIRMessagingTopicOperation *operation =
      [[FIRMessagingTopicOperation alloc] initWithTopic:topic
                                                 action:action
                                                  token:token
                                                options:options
                                             completion:handler];
  [self.topicOperations addOperation:operation];

}

@end
