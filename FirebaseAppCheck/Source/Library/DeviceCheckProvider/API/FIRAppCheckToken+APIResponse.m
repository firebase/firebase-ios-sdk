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

#import "FIRAppCheckToken+APIResponse.h"

#import "FIRAppCheckErrorUtil.h"

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

  NSString *token = responseDict[@"attestation_token"];
  if (![token isKindOfClass:[NSString class]]) {
    *outError =
        [FIRAppCheckErrorUtil appCheckTokenResponseErrorWithMissingField:@"attestation_token"];
    return nil;
  }

  NSDictionary<NSString *, NSNumber *> *timeToLiveDict = responseDict[@"time_to_live"];
  if (timeToLiveDict == nil) {
    *outError = [FIRAppCheckErrorUtil appCheckTokenResponseErrorWithMissingField:@"time_to_live"];
    return nil;
  }

  NSNumber *secondsToLive = timeToLiveDict[@"seconds"];
  if (![secondsToLive isKindOfClass:[NSNumber class]]) {
    *outError =
        [FIRAppCheckErrorUtil appCheckTokenResponseErrorWithMissingField:@"time_to_live.seconds"];
    return nil;
  }

  NSDate *expirationDate = [requestDate dateByAddingTimeInterval:secondsToLive.doubleValue];

  return [self initWithToken:token expirationDate:expirationDate];
}

@end
