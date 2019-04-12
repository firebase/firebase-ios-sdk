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

#import "FIRMessagingRegistrar.h"

#import "FIRMessagingDefines.h"
#import "FIRMessagingLogger.h"
#import "FIRMessagingPubSubRegistrar.h"
#import "FIRMessagingUtilities.h"
#import "NSError+FIRMessaging.h"

@interface FIRMessagingRegistrar ()

@property(nonatomic, readwrite, assign) BOOL stopAllSubscriptions;

@property(nonatomic, readwrite, strong) FIRMessagingPubSubRegistrar *pubsubRegistrar;

@end

@implementation FIRMessagingRegistrar

- (instancetype)init {
  self = [super init];
  if (self) {
    // TODO(chliangGoogle): Merge pubsubRegistrar with Registrar as it is hard to track how many
    // checkinService instances by separating classes too often.
    _pubsubRegistrar = [[FIRMessagingPubSubRegistrar alloc] init];
  }
  return self;
}

#pragma mark - Subscribe/Unsubscribe

- (void)updateSubscriptionToTopic:(NSString *)topic
                        withToken:(NSString *)token
                          options:(NSDictionary *)options
                     shouldDelete:(BOOL)shouldDelete
                          handler:(FIRMessagingTopicOperationCompletion)handler {
  _FIRMessagingDevAssert(handler, @"Invalid nil handler");
    [self.pubsubRegistrar updateSubscriptionToTopic:topic
                                          withToken:token
                                            options:options
                                       shouldDelete:shouldDelete
                                            handler:handler];
}

- (void)cancelAllRequests {
  self.stopAllSubscriptions = YES;
  [self.pubsubRegistrar stopAllSubscriptionRequests];
}



@end
