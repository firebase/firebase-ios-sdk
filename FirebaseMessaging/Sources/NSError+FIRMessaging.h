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

FOUNDATION_EXPORT NSString *const kFIRMessagingDomain;

// FIRMessaging Internal Error Code
typedef NS_ENUM(NSUInteger, FIRMessagingErrorCode) {
  kFIRMessagingErrorCodeUnknown = 0,

  kFIRMessagingErrorCodeNetwork = 4,

  kFIRMessagingErrorCodeInvalidRequest = 7,

  kFIRMessagingErrorCodeInvalidTopicName = 8,

  // FIRMessaging generic errors
  kFIRMessagingErrorCodeMissingDeviceID = 501,

  // Upstream send errors
  kFIRMessagingErrorCodeServiceNotAvailable = 1001,
  kFIRMessagingErrorCodeMissingTo = 1003,
  kFIRMessagingErrorCodeSave = 1004,
  kFIRMessagingErrorCodeSizeExceeded = 1005,

  // Already connected with MCS
  kFIRMessagingErrorCodeAlreadyConnected = 2001,

  // PubSub errors
  kFIRMessagingErrorCodePubSubClientNotSetup = 3004,
  kFIRMessagingErrorCodePubSubOperationIsCancelled = 3005,
};

@interface NSError (FIRMessaging)

+ (NSError *)messagingErrorWithCode:(FIRMessagingErrorCode)fcmErrorCode
                      failureReason:(NSString *)failureReason;

@end

NS_ASSUME_NONNULL_END
