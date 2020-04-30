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

#import <FirebaseMessaging/FIRMessaging.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kFIRMessagingDomain;

typedef NS_ENUM(NSUInteger, FIRMessagingInternalErrorCode) {
  // Unknown error.
  kFIRMessagingErrorCodeUnknown = 0,

  kFIRMessagingErrorCodeNetwork = 4,

  kFIRMessagingErrorCodeInvalidRequest = 7,

  kFIRMessagingErrorInvalidTopicName = 8,

  // FIRMessaging generic errors
  kFIRMessagingErrorCodeMissingDeviceID = 501,

  // Upstream send errors
  kFIRMessagingErrorServiceNotAvailable = 1001,
  kFIRMessagingErrorMissingTo = 1003,
  kFIRMessagingErrorSave = 1004,
  kFIRMessagingErrorSizeExceeded = 1005,

  // Already connected with MCS
  kFIRMessagingErrorCodeAlreadyConnected = 2001,

  // PubSub errors
  kFIRMessagingErrorCodePubSubClientNotSetup = 3004,
  kFIRMessagingErrorCodePubSubOperationIsCancelled = 3005,
};

@interface NSError (FIRMessaging)

+ (NSError *)messagingErrorWithCode:(FIRMessagingInternalErrorCode)fcmErrorCode
                      failureReason:(NSString *)failureReason;

@end

NS_ASSUME_NONNULL_END
