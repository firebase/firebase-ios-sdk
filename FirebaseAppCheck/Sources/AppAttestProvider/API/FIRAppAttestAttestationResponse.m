/*
 * Copyright 2021 Google LLC
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

#import "FirebaseAppCheck/Sources/AppAttestProvider/API/FIRAppAttestAttestationResponse.h"

#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckToken+APIResponse.h"
#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"

@implementation FIRAppAttestAttestationResponse

- (instancetype)initWithArtifact:(NSData *)artifact token:(FIRAppCheckToken *)token {
  self = [super init];
  if (self) {
    _artifact = artifact;
    _token = token;
  }
  return self;
}

- (nullable instancetype)initWithResponseData:(NSData *)response
                                  requestDate:(NSDate *)requestDate
                                        error:(NSError **)outError {
  if (response.length <= 0) {
    FIRAppCheckSetErrorToPointer(
        [FIRAppCheckErrorUtil
            errorWithFailureReason:
                @"Failed to parse the initial handshake response. Empty server response body."],
        outError);
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

  NSString *artifactBase64String = responseDict[@"artifact"];
  if (![artifactBase64String isKindOfClass:[NSString class]]) {
    FIRAppCheckSetErrorToPointer(
        [FIRAppCheckErrorUtil appAttestAttestationResponseErrorWithMissingField:@"artifact"],
        outError);
    return nil;
  }
  NSData *artifactData = [[NSData alloc] initWithBase64EncodedString:artifactBase64String
                                                             options:0];
  if (artifactData == nil) {
    FIRAppCheckSetErrorToPointer(
        [FIRAppCheckErrorUtil appAttestAttestationResponseErrorWithMissingField:@"artifact"],
        outError);
    return nil;
  }

  NSDictionary *attestationTokenDict = responseDict[@"attestationToken"];
  if (![attestationTokenDict isKindOfClass:[NSDictionary class]]) {
    FIRAppCheckSetErrorToPointer(
        [FIRAppCheckErrorUtil
            appAttestAttestationResponseErrorWithMissingField:@"attestationToken"],
        outError);
    return nil;
  }

  FIRAppCheckToken *appCheckToken =
      [[FIRAppCheckToken alloc] initWithResponseDict:attestationTokenDict
                                         requestDate:requestDate
                                               error:outError];

  if (appCheckToken == nil) {
    return nil;
  }

  return [self initWithArtifact:artifactData token:appCheckToken];
}

@end
