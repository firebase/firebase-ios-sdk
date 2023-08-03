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

NS_ASSUME_NONNULL_BEGIN

static NSString *const kResponseFieldAppCheckTokenDict = @"appCheckToken";
static NSString *const kResponseFieldArtifact = @"artifact";

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
                                        error:(NSError **_Nonnull)outError {
  NSParameterAssert(outError);
  if (response.length <= 0) {
    *outError = [FIRAppCheckErrorUtil
        errorWithFailureReason:
            @"Failed to parse the initial handshake response. Empty server response body."];
    return nil;
  }

  NSError *JSONError;
  NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:response
                                                               options:0
                                                                 error:&JSONError];

  if (![responseDict isKindOfClass:[NSDictionary class]]) {
    if (JSONError) {
      *outError = [FIRAppCheckErrorUtil JSONSerializationError:JSONError];
    } else {
      *outError = [FIRAppCheckErrorUtil
          errorWithFailureReason:
              @"Unexpected top-level JSON object in initial handshake response."];
    }
    return nil;
  }

  NSString *artifactBase64String = responseDict[kResponseFieldArtifact];
  if (![artifactBase64String isKindOfClass:[NSString class]]) {
    *outError = [FIRAppCheckErrorUtil
        appAttestAttestationResponseErrorWithMissingField:kResponseFieldArtifact];
    return nil;
  }
  NSData *artifactData = [[NSData alloc] initWithBase64EncodedString:artifactBase64String
                                                             options:0];
  if (artifactData == nil) {
    *outError = [FIRAppCheckErrorUtil
        appAttestAttestationResponseErrorWithMissingField:kResponseFieldArtifact];
    return nil;
  }

  NSDictionary *appCheckTokenDict = responseDict[kResponseFieldAppCheckTokenDict];
  if (![appCheckTokenDict isKindOfClass:[NSDictionary class]]) {
    *outError = [FIRAppCheckErrorUtil
        appAttestAttestationResponseErrorWithMissingField:kResponseFieldAppCheckTokenDict];
    return nil;
  }

  NSError *tokenError;
  FIRAppCheckToken *appCheckToken = [[FIRAppCheckToken alloc] initWithResponseDict:appCheckTokenDict
                                                                       requestDate:requestDate
                                                                             error:&tokenError];

  if (appCheckToken) {
    return [self initWithArtifact:artifactData token:appCheckToken];
  } else if (tokenError) {
    *outError = tokenError;
  } else {
    *outError =
        [FIRAppCheckErrorUtil errorWithFailureReason:@"Failed to parse App Check token response."];
  }

  return nil;
}

NS_ASSUME_NONNULL_END

@end
