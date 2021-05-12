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

#import "FirebaseAppCheck/Sources/AppAttestProvider/API/FIRAppAttestAPIService.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FirebaseAppCheck/Sources/AppAttestProvider/API/FIRAppAttestAttestationResponse.h"
#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"

#import <GoogleUtilities/GULURLSessionDataResponse.h>
#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kRequestFieldAttestation = @"attestation_statement";
static NSString *const kRequestFieldKeyID = @"key_id";
static NSString *const kRequestFieldChallenge = @"challenge";

static NSString *const kContentTypeKey = @"Content-Type";
static NSString *const kJSONContentType = @"application/json";

@interface FIRAppAttestAPIService ()

@property(nonatomic, readonly) id<FIRAppCheckAPIServiceProtocol> APIService;

@property(nonatomic, readonly) NSString *projectID;
@property(nonatomic, readonly) NSString *appID;

@end

@implementation FIRAppAttestAPIService

- (instancetype)initWithAPIService:(id<FIRAppCheckAPIServiceProtocol>)APIService
                         projectID:(NSString *)projectID
                             appID:(NSString *)appID {
  self = [super init];
  if (self) {
    _APIService = APIService;
    _projectID = projectID;
    _appID = appID;
  }
  return self;
}

- (dispatch_queue_t)backgroundQueue {
  return dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
}

- (FBLPromise<FIRAppCheckToken *> *)appCheckTokenWithArtifact:(NSData *)artifact
                                                    challenge:(NSData *)challenge
                                                    assertion:(NSData *)assertion {
  // TODO: Implement.
  return [FBLPromise resolvedWith:nil];
}

#pragma mark - Random Challenge

- (nonnull FBLPromise<NSData *> *)getRandomChallenge {
  NSString *URLString =
      [NSString stringWithFormat:@"%@/projects/%@/apps/%@:generateAppAttestChallenge",
                                 self.APIService.baseURL, self.projectID, self.appID];
  NSURL *URL = [NSURL URLWithString:URLString];

  return [FBLPromise onQueue:[self backgroundQueue]
                          do:^id _Nullable {
                            return [self.APIService sendRequestWithURL:URL
                                                            HTTPMethod:@"POST"
                                                                  body:nil
                                                     additionalHeaders:nil];
                          }]
      .then(^id _Nullable(GULURLSessionDataResponse *_Nullable response) {
        return [self randomChallengeWithAPIResponse:response];
      });
}

#pragma mark - Challenge response parsing

- (FBLPromise<NSData *> *)randomChallengeWithAPIResponse:(GULURLSessionDataResponse *)response {
  return [FBLPromise onQueue:[self backgroundQueue]
                          do:^id _Nullable {
                            NSError *error;

                            NSData *randomChallenge =
                                [self randomChallengeFromResponseBody:response.HTTPBody
                                                                error:&error];

                            return randomChallenge ?: error;
                          }];
}

- (nullable NSData *)randomChallengeFromResponseBody:(NSData *)response error:(NSError **)outError {
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

  NSString *challenge = responseDict[@"challenge"];
  if (![challenge isKindOfClass:[NSString class]]) {
    FIRAppCheckSetErrorToPointer(
        [FIRAppCheckErrorUtil appCheckTokenResponseErrorWithMissingField:@"challenge"], outError);
    return nil;
  }

  NSData *randomChallenge = [[NSData alloc] initWithBase64EncodedString:challenge options:0];
  return randomChallenge;
}

#pragma mark - Attestation request

- (FBLPromise<FIRAppAttestAttestationResponse *> *)attestKeyWithAttestation:(NSData *)attestation
                                                                      keyID:(NSString *)keyID
                                                                  challenge:(NSData *)challenge {
  NSString *URLString =
      [NSString stringWithFormat:@"%@/projects/%@/apps/%@:exchangeAppAttestAttestation",
                                 self.APIService.baseURL, self.projectID, self.appID];
  NSURL *URL = [NSURL URLWithString:URLString];

  return [self HTTPBodyWithAttestation:attestation keyID:keyID challenge:challenge]
      .then(^FBLPromise<GULURLSessionDataResponse *> *(NSData *HTTPBody) {
        return [self.APIService sendRequestWithURL:URL
                                        HTTPMethod:@"POST"
                                              body:HTTPBody
                                 additionalHeaders:@{kContentTypeKey : kJSONContentType}];
      })
      .then(^id _Nullable(GULURLSessionDataResponse *_Nullable URLResponse) {
        NSError *error;

        __auto_type response =
            [[FIRAppAttestAttestationResponse alloc] initWithResponseData:URLResponse.HTTPBody
                                                              requestDate:[NSDate date]
                                                                    error:&error];

        return response ?: error;
      });
}

- (FBLPromise<NSData *> *)HTTPBodyWithAttestation:(NSData *)attestation
                                            keyID:(NSString *)keyID
                                        challenge:(NSData *)challenge {
  if (attestation.length <= 0 || keyID.length <= 0 || challenge.length <= 0) {
    FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
    [rejectedPromise reject:[FIRAppCheckErrorUtil
                                errorWithFailureReason:@"Missing or empty request parameter."]];
    return rejectedPromise;
  }

  return [FBLPromise
      onQueue:[self backgroundQueue]
           do:^id _Nullable {
             NSError *encodingError;
             NSData *payloadJSON = [NSJSONSerialization dataWithJSONObject:@{
               kRequestFieldKeyID : keyID,
               kRequestFieldAttestation : [self base64StringWithData:attestation],
               kRequestFieldChallenge : [self base64StringWithData:challenge]
             }
                                                                   options:0
                                                                     error:&encodingError];

             if (payloadJSON != nil) {
               return payloadJSON;
             } else {
               return [FIRAppCheckErrorUtil JSONSerializationError:encodingError];
             }
           }];
}

- (NSString *)base64StringWithData:(NSData *)data {
  // TODO: Need to encode in base64URL?
  return [data base64EncodedStringWithOptions:0];
}

@end

NS_ASSUME_NONNULL_END
