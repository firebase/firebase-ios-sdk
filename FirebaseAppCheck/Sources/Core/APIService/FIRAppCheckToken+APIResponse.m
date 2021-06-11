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

#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckToken+APIResponse.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"

#import <GoogleUtilities/GULURLSessionDataResponse.h>

@implementation FIRAppCheckToken (APIResponse)

- (nullable instancetype)initWithTokenExchangeResponse:(NSData *)response
                                           requestDate:(NSDate *)requestDate
                                                 error:(NSError **)outError {
  if (response.length <= 0) {
    FIRAppCheckSetErrorToPointer(
        [FIRAppCheckErrorUtil errorWithFailureReason:@"Empty server response body."], outError);
    return nil;
  }

  NSError *JSONError;
  NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:response
                                                               options:0
                                                                 error:&JSONError];

  if (![responseDict isKindOfClass:[NSDictionary class]]) {
    FIRAppCheckSetErrorToPointer([FIRAppCheckErrorUtil JSONSerializationError:JSONError], outError);
    return nil;
  }

  return [self initWithResponseDict:responseDict requestDate:requestDate error:outError];
}

- (nullable instancetype)initWithResponseDict:(NSDictionary<NSString *, id> *)responseDict
                                  requestDate:(NSDate *)requestDate
                                        error:(NSError **)outError {
  NSString *token = responseDict[@"attestationToken"];
  if (![token isKindOfClass:[NSString class]]) {
    FIRAppCheckSetErrorToPointer(
        [FIRAppCheckErrorUtil appCheckTokenResponseErrorWithMissingField:@"attestationToken"],
        outError);
    return nil;
  }

  NSString *timeToLiveString = responseDict[@"ttl"];
  if (![token isKindOfClass:[NSString class]] || token.length <= 0) {
    FIRAppCheckSetErrorToPointer(
        [FIRAppCheckErrorUtil appCheckTokenResponseErrorWithMissingField:@"ttl"], outError);
    return nil;
  }

  // Expect a string like "3600s" representing a time interval in seconds.
  NSString *timeToLiveValueString = [timeToLiveString stringByReplacingOccurrencesOfString:@"s"
                                                                                withString:@""];
  NSTimeInterval secondsToLive = timeToLiveValueString.doubleValue;

  if (secondsToLive == 0) {
    FIRAppCheckSetErrorToPointer(
        [FIRAppCheckErrorUtil appCheckTokenResponseErrorWithMissingField:@"ttl"], outError);
    return nil;
  }

  NSDate *expirationDate = [requestDate dateByAddingTimeInterval:secondsToLive];

  return [self initWithToken:token expirationDate:expirationDate receivedAtDate:requestDate];
}

@end
