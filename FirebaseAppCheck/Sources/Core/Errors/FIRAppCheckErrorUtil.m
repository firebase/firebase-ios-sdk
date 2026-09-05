/*
 * Copyright 2020 Google LLC
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

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"

#if __has_include(<AppCheckCore/AppCheckCore-Swift.h>)
#import <AppCheckCore/AppCheckCore-Swift.h>
#elif __has_include("AppCheckCore-Swift.h")
#import "AppCheckCore-Swift.h"
#else
@import AppCheckCore;
#endif

@implementation FIRAppCheckErrorUtil

+ (NSError *)publicDomainErrorWithError:(NSError *)error {
  if ([error.domain isEqualToString:@"com.google.app_check_core"]) {
    return [self publicDomainErrorWithGACError:error];
  } else if ([error.domain isEqualToString:FIRAppCheckErrorDomain]) {
    return error;
  }

  return [self unknownErrorWithError:error];
}

/// Converts an App Check Core error (`@"com.google.app_check_core"`) to a public error
/// (`FIRAppCheckErrorDomain`).
+ (NSError *)publicDomainErrorWithGACError:(NSError *)appCheckCoreError {
  FIRAppCheckErrorCode errorCode;
  switch ((GACAppCheckErrorCode)appCheckCoreError.code) {
    case GACAppCheckErrorCodeUnknown:
      errorCode = FIRAppCheckErrorCodeUnknown;
      break;
    case GACAppCheckErrorCodeServerUnreachable:
      errorCode = FIRAppCheckErrorCodeServerUnreachable;
      break;
    case GACAppCheckErrorCodeInvalidConfiguration:
      errorCode = FIRAppCheckErrorCodeInvalidConfiguration;
      break;
    case GACAppCheckErrorCodeKeychain:
      errorCode = FIRAppCheckErrorCodeKeychain;
      break;
    case GACAppCheckErrorCodeUnsupported:
      errorCode = FIRAppCheckErrorCodeUnsupported;
      break;
    default:
      return [self unknownErrorWithError:appCheckCoreError];
  }

  return [NSError errorWithDomain:FIRAppCheckErrorDomain
                             code:errorCode
                         userInfo:appCheckCoreError.userInfo];
}

#pragma mark - Helpers

+ (NSError *)unknownErrorWithError:(NSError *)error {
  NSString *failureReason = error.userInfo[NSLocalizedFailureReasonErrorKey];
  return [self appCheckErrorWithCode:FIRAppCheckErrorCodeUnknown
                       failureReason:failureReason
                     underlyingError:error];
}

+ (NSError *)appCheckErrorWithCode:(FIRAppCheckErrorCode)code
                     failureReason:(nullable NSString *)failureReason
                   underlyingError:(nullable NSError *)underlyingError {
  NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
  userInfo[NSUnderlyingErrorKey] = underlyingError;
  userInfo[NSLocalizedFailureReasonErrorKey] = failureReason;

  return [NSError errorWithDomain:FIRAppCheckErrorDomain code:code userInfo:userInfo];
}

@end
