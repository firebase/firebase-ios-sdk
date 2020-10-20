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

#import "FirebaseAppCheck/Source/Library/DeviceCheckProvider/API/FIRAppCheckToken+APIResponse.h"

#import "FirebaseAppCheck/Source/Library/Core/Errors/FIRAppCheckErrorUtil.h"

@implementation FIRAppCheckToken (APIResponse)

- (nullable instancetype)initWithDeviceCheckResponse:(NSData *)response
                                         requestDate:(NSDate *)requestDate
                                               error:(NSError **)outError {
  NSError *JSONError;
  NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:response
                                                               options:0
                                                                 error:&JSONError];

  if (![responseDict isKindOfClass:[NSDictionary class]]) {
    *outError = [FIRAppCheckErrorUtil JSONSerializationError:JSONError];
    return nil;
  }

  NSString *token = responseDict[@"attestationToken"];
  if (![token isKindOfClass:[NSString class]]) {
    *outError =
        [FIRAppCheckErrorUtil appCheckTokenResponseErrorWithMissingField:@"attestationToken"];
    return nil;
  }

  NSString *timeToLiveString = responseDict[@"timeToLive"];
  if (![token isKindOfClass:[NSString class]] || token.length <= 0) {
    *outError = [FIRAppCheckErrorUtil appCheckTokenResponseErrorWithMissingField:@"timeToLive"];
    return nil;
  }

  // Expect a string like "3600s" representing a time interval in seconds.
  NSString *timeToLiveValueString = [timeToLiveString stringByReplacingOccurrencesOfString:@"s"
                                                                                withString:@""];
  NSTimeInterval secondsToLive = timeToLiveValueString.doubleValue;

  if (secondsToLive == 0) {
    *outError = [FIRAppCheckErrorUtil appCheckTokenResponseErrorWithMissingField:@"timeToLive"];
    return nil;
  }

  NSDate *expirationDate = [requestDate dateByAddingTimeInterval:secondsToLive];

  return [self initWithToken:token expirationDate:expirationDate];
}

@end
