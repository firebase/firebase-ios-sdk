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

#import <GoogleUtilities/GULURLSessionDataResponse.h>
#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"

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

- (nonnull FBLPromise<FIRAppCheckToken *> *)
    appCheckTokenWithAttestation:(nonnull NSData *)attestation
                           keyID:(nonnull NSString *)keyID
                       challenge:(nonnull NSData *)challenge {
  // TODO: Implement.
  return [FBLPromise resolvedWith:nil];
}

- (nonnull FBLPromise<NSData *> *)getRandomChallenge {
  NSString *URLString =
      [NSString stringWithFormat:@"%@/projects/%@/apps/%@:generateAppAttestChallenge",
                                 self.APIService.baseURL, self.projectID, self.appID];
  NSURL *URL = [NSURL URLWithString:URLString];

  return [FBLPromise onQueue:[self defaultQueue]
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

- (FBLPromise<NSData *> *)randomChallengeWithAPIResponse:(GULURLSessionDataResponse *)response {
  NSData *randomChallenge = response.HTTPBody;
  return [FBLPromise resolvedWith:randomChallenge];
}

- (dispatch_queue_t)defaultQueue {
  return dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
}

@end
