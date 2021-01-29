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

#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"

NSString *const kFIRMessagingDomain = @"com.google.fcm";

@implementation NSError (FIRMessaging)

+ (NSError *)messagingErrorWithCode:(FIRMessagingErrorCode)errorCode
                      failureReason:(NSString *)failureReason {
  NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
  userInfo[NSLocalizedFailureReasonErrorKey] = failureReason;
  return [NSError errorWithDomain:kFIRMessagingDomain code:errorCode userInfo:userInfo];
}

@end
