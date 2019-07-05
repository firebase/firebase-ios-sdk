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

NSString *const kFirebaseInstallationsErrorDomain = @"com.firebase.installations";
// NSString *const kFirebaseInstallationsInternalErrorDomain =
// @"com.firebase.installations.internal";

void FIRInstallationsItemSetErrorToPointer(NSError *error, NSError **pointer) {
  if (pointer != NULL) {
    *pointer = error;
  }
}

@implementation FIRInstallationsErrorUtil

+ (NSError *)keyedArchiverErrorWithException:(NSException *)exception {
  NSString *failureReason = [NSString
      stringWithFormat:@"NSKeyedArchiver exception with name: %@, reason: %@, userInfo: %@",
                       exception.name, exception.reason, exception.userInfo];
  return [self publicErrorWithCode:FIRInstallationsErrorCodeUnknown
                     failureReason:failureReason
                   underlyingError:nil];
}

+ (NSError *)keyedArchiverErrorWithError:(NSError *)error {
  NSString *failureReason = [NSString stringWithFormat:@"NSKeyedArchiver error"];
  return [self publicErrorWithCode:FIRInstallationsErrorCodeUnknown
                     failureReason:failureReason
                   underlyingError:error];
}

+ (NSError *)keychainErrorWithFunction:(NSString *)keychainFunction status:(OSStatus)status {
  // TODO: Form a proper error
  NSString *failureReason = [NSString stringWithFormat:@"%@ (%li)", keychainFunction, (long)status];
  return [self publicErrorWithCode:FIRInstallationsErrorCodeKeychain failureReason:failureReason underlyingError:nil];
}

+ (NSError *)installationItemNotFoundForAppID:(NSString *)appID appName:(NSString *)appName {
  NSString *failureReason =
      [NSString stringWithFormat:@"Installation for appID %@ appName %@ not found", appID, appName];
  return [self publicErrorWithCode:FIRInstallationsErrorCodeUnknown failureReason:failureReason underlyingError:nil];
}

+ (NSError *)APIErrorWithHTTPCode:(NSUInteger)HTTPCode {
  NSString *failureReason = [NSString
      stringWithFormat:@"Unexpected server response HTTP code: %lu", (unsigned long)HTTPCode];
  return [self publicErrorWithCode:FIRInstallationsErrorCodeUnknown failureReason:failureReason underlyingError:nil];
}

+ (NSError *)JSONSerializationError:(NSError *)error {
  NSString *failureReason = [NSString stringWithFormat:@"Failed to serialize JSON data."];
  return [self publicErrorWithCode:FIRInstallationsErrorCodeUnknown failureReason:failureReason underlyingError:nil];
}

+ (NSError *)FIDRegestrationErrorWithResponseMissingField:(NSString *)missingFieldName {
  NSString *failureReason = [NSString
      stringWithFormat:@"A required response field with name %@ is missing", missingFieldName];
  return [self publicErrorWithCode:FIRInstallationsErrorCodeUnknown failureReason:failureReason underlyingError:nil];
}

+ (NSError *)networkErrorWithError:(NSError *)error {
  return [self publicErrorWithCode:FIRInstallationsErrorCodeServerUnreachable failureReason:@"Networt connection error" underlyingError:error];
}

+ (NSError *)publicErrorWithCode:(FIRInstallationsErrorCode)code
                   failureReason:(NSString *)failureReason
                 underlyingError:(nullable NSError *)underlyingError {
  NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
  userInfo[NSUnderlyingErrorKey] = underlyingError;
  userInfo[NSLocalizedFailureReasonErrorKey] = failureReason;

  return [NSError errorWithDomain:kFirebaseInstallationsErrorDomain code:code userInfo:userInfo];
}

@end
