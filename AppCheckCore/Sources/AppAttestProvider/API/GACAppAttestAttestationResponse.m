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

#import "AppCheckCore/Sources/AppAttestProvider/API/GACAppAttestAttestationResponse.h"

#import "AppCheckCore/Sources/Core/APIService/GACAppCheckToken+APIResponse.h"
#import "AppCheckCore/Sources/Core/Errors/GACAppCheckErrorUtil.h"

static NSString *const kResponseFieldAppCheckTokenDict = @"appCheckToken";
static NSString *const kResponseFieldArtifact = @"artifact";

@implementation GACAppAttestAttestationResponse

- (instancetype)initWithArtifact:(NSData *)artifact token:(GACAppCheckToken *)token {
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
    GACAppCheckSetErrorToPointer(
        [GACAppCheckErrorUtil
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
    GACAppCheckSetErrorToPointer([GACAppCheckErrorUtil JSONSerializationError:JSONError], outError);
    return nil;
  }

  NSString *artifactBase64String = responseDict[kResponseFieldArtifact];
  if (![artifactBase64String isKindOfClass:[NSString class]]) {
    GACAppCheckSetErrorToPointer(
        [GACAppCheckErrorUtil
            appAttestAttestationResponseErrorWithMissingField:kResponseFieldArtifact],
        outError);
    return nil;
  }
  NSData *artifactData = [[NSData alloc] initWithBase64EncodedString:artifactBase64String
                                                             options:0];
  if (artifactData == nil) {
    GACAppCheckSetErrorToPointer(
        [GACAppCheckErrorUtil
            appAttestAttestationResponseErrorWithMissingField:kResponseFieldArtifact],
        outError);
    return nil;
  }

  NSDictionary *appCheckTokenDict = responseDict[kResponseFieldAppCheckTokenDict];
  if (![appCheckTokenDict isKindOfClass:[NSDictionary class]]) {
    GACAppCheckSetErrorToPointer(
        [GACAppCheckErrorUtil
            appAttestAttestationResponseErrorWithMissingField:kResponseFieldAppCheckTokenDict],
        outError);
    return nil;
  }

  GACAppCheckToken *appCheckToken = [[GACAppCheckToken alloc] initWithResponseDict:appCheckTokenDict
                                                                       requestDate:requestDate
                                                                             error:outError];

  if (appCheckToken == nil) {
    return nil;
  }

  return [self initWithArtifact:artifactData token:appCheckToken];
}

@end
