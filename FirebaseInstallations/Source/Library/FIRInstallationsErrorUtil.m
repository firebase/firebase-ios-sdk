/*
 * Copyright 2019 Google
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

#import "FIRInstallationsErrorUtil.h"

void FIRInstallationsItemSetErrorToPointer(NSError *error, NSError **pointer) {
  if (pointer != NULL) {
    *pointer = error;
  }
}

@implementation FIRInstallationsErrorUtil

+ (NSError *)keyedArchiverErrorWithException:(NSException *)exception {
  // TODO: Form a proper error
  return [NSError errorWithDomain:@"NSKeyedArchiver" code:-1 userInfo:exception.userInfo];
}

+ (NSError *)keychainErrorWithFunction:(NSString *)keychainFunction status:(OSStatus)status {
  // TODO: Form a proper error
  NSString *failureReason = [NSString stringWithFormat:@"%@ (%li)", keychainFunction, (long)status];
  return [NSError errorWithDomain:@"FIRInstallationsError"
                             code:-1
                         userInfo:@{
                           NSLocalizedFailureReasonErrorKey : failureReason,
                         }];
}

+ (NSError *)installationItemNotFoundForAppID:(NSString *)appID appName:(NSString *)appName {
  // TODO: Form a proper error
  NSString *failureReason =
      [NSString stringWithFormat:@"Installation for appID %@ appName %@ not found", appID, appName];
  return [NSError errorWithDomain:@"FIRInstallationsError"
                             code:-1
                         userInfo:@{
                           NSLocalizedFailureReasonErrorKey : failureReason,
                         }];
}

+ (NSError *)APIErrorWithHTTPCode:(NSUInteger)HTTPCode {
  // TODO: Form a proper error.
  NSString *failureReason = [NSString
      stringWithFormat:@"Unexpected server response HTTP code: %lu", (unsigned long)HTTPCode];
  return [NSError errorWithDomain:@"FIRInstallationsError"
                             code:-1
                         userInfo:@{
                           NSLocalizedFailureReasonErrorKey : failureReason,
                         }];
}

+ (NSError *)JSONSerializationError:(NSError *)error {
  // TODO: Form a proper error.
  NSString *failureReason = [NSString stringWithFormat:@"Failed to serialize JSON data."];
  return [NSError errorWithDomain:@"FIRInstallationsError"
                             code:-1
                         userInfo:@{
                           NSLocalizedFailureReasonErrorKey : failureReason,
                           NSUnderlyingErrorKey : error,
                         }];
  return error;
}

+ (NSError *)FIDRegestrationErrorWithResponseMissingField:(NSString *)missingFieldName {
  // TODO: Form a proper error.
  NSString *failureReason = [NSString
      stringWithFormat:@"A required response field with name %@ is missing", missingFieldName];
  return [NSError errorWithDomain:@"FIRInstallationsError"
                             code:-1
                         userInfo:@{
                           NSLocalizedFailureReasonErrorKey : failureReason,
                         }];
}

@end
