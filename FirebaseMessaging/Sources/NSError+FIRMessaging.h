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

FOUNDATION_EXPORT NSString *const kFIRMessagingDomain;

typedef NS_ENUM(NSUInteger, FIRMessagingInternalErrorCode) {
  // Unknown error.
  kFIRMessagingErrorCodeUnknown = 0,

  // HTTP related errors.
  kFIRMessagingErrorCodeAuthentication = 1,
  kFIRMessagingErrorCodeNoAccess = 2,
  kFIRMessagingErrorCodeTimeout = 3,
  kFIRMessagingErrorCodeNetwork = 4,

  // Another operation is in progress.
  kFIRMessagingErrorCodeOperationInProgress = 5,

  // Failed to perform device check in.
  kFIRMessagingErrorCodeRegistrarFailedToCheckIn = 6,

  kFIRMessagingErrorCodeInvalidRequest = 7,

  // FIRMessaging generic errors
  kFIRMessagingErrorCodeMissingDeviceID = 501,

  // upstream send errors
  kFIRMessagingErrorServiceNotAvailable = 1001,
  kFIRMessagingErrorInvalidParameters = 1002,
  kFIRMessagingErrorMissingTo = 1003,
  kFIRMessagingErrorSave = 1004,
  kFIRMessagingErrorSizeExceeded = 1005,
  // Future Send Errors

  // MCS errors
  // Already connected with MCS
  kFIRMessagingErrorCodeAlreadyConnected = 2001,

  // PubSub errors
  kFIRMessagingErrorCodePubSubAlreadySubscribed = 3001,
  kFIRMessagingErrorCodePubSubAlreadyUnsubscribed = 3002,
  kFIRMessagingErrorCodePubSubInvalidTopic = 3003,
  kFIRMessagingErrorCodePubSubFIRMessagingNotSetup = 3004,
  kFIRMessagingErrorCodePubSubOperationIsCancelled = 3005,
};

@interface NSError (FIRMessaging)

@property(nonatomic, readonly) FIRMessagingInternalErrorCode fcmErrorCode;

+ (NSError *)errorWithFCMErrorCode:(FIRMessagingInternalErrorCode)fcmErrorCode;
+ (NSError *)fcm_errorWithCode:(NSInteger)code userInfo:(NSDictionary *)userInfo;

@end
