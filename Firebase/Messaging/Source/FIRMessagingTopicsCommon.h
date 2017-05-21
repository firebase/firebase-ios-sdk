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

NS_ASSUME_NONNULL_BEGIN

/**
 *  Represents the action taken on a subscription topic.
 */
typedef NS_ENUM(NSInteger, FIRMessagingTopicAction) {
  FIRMessagingTopicActionSubscribe,
  FIRMessagingTopicActionUnsubscribe
};

/**
 * Represents the possible results of a topic operation.
 */
typedef NS_ENUM(NSInteger, FIRMessagingTopicOperationResult) {
  FIRMessagingTopicOperationResultSucceeded,
  FIRMessagingTopicOperationResultError,
  FIRMessagingTopicOperationResultCancelled,
};

/**
 *  Callback to invoke once the HTTP call to FIRMessaging backend for updating
 *  subscription finishes.
 *
 *  @param result         The result of the operation. If the result is
 *                        FIRMessagingTopicOperationResultError, the error parameter will be
 *                        non-nil.
 *  @param error          The error which occurred while updating the subscription topic
 *                        on the FIRMessaging server. This will be nil in case the operation
 *                        was successful, or if the operation was cancelled.
 */
typedef void(^FIRMessagingTopicOperationCompletion)
    (FIRMessagingTopicOperationResult result, NSError * _Nullable error);

NS_ASSUME_NONNULL_END
