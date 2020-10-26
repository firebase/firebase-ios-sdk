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

#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"

#import "FirebaseMessaging/Sources/FIRMessagingTopicsCommon.h"

NS_ASSUME_NONNULL_BEGIN

@class FIRMessagingTokenManager;

/**
 *  An asynchronous NSOperation subclass which performs a single network request for a topic
 *  subscription operation. Once completed, it calls its provided completion handler.
 */
@interface FIRMessagingTopicOperation : NSOperation

@property(nonatomic, readonly, copy) NSString *topic;
@property(nonatomic, readonly, assign) FIRMessagingTopicAction action;
@property(nonatomic, readonly, copy) NSString *token;
@property(nonatomic, readonly, copy, nullable) NSDictionary *options;

- (instancetype)initWithTopic:(NSString *)topic
                       action:(FIRMessagingTopicAction)action
                 tokenManager:(FIRMessagingTokenManager *)tokenManager
                      options:(nullable NSDictionary *)options
                   completion:(FIRMessagingTopicOperationCompletion)completion;

@end

NS_ASSUME_NONNULL_END
