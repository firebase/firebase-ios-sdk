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

#import "FirebaseAppCheck/Sources/DebugProvider/API/FIRAppCheckDebugProviderAPIService.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import <GoogleUtilities/GULURLSessionDataResponse.h>
#import <GoogleUtilities/NSURLSession+GULPromises.h>

#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"
#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckToken+APIResponse.h"

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kContentTypeKey = @"Content-Type";
static NSString *const kJSONContentType = @"application/json";
static NSString *const kDebugTokenField = @"debug_token";

@interface FIRAppCheckDebugProviderAPIService ()

@property(nonatomic, readonly) id<FIRAppCheckAPIServiceProtocol> APIService;

@property(nonatomic, readonly) NSString *projectID;
@property(nonatomic, readonly) NSString *appID;

@end

@implementation FIRAppCheckDebugProviderAPIService

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

#pragma mark - Public API

- (FBLPromise<FIRAppCheckToken *> *)appCheckTokenWithDebugToken:(NSString *)debugToken {
  NSString *URLString =
      [NSString stringWithFormat:@"%@/projects/%@/apps/%@:exchangeDebugToken",
                                 self.APIService.baseURL, self.projectID, self.appID];
  NSURL *URL = [NSURL URLWithString:URLString];

  return [self HTTPBodyWithDebugToken:debugToken]
      .then(^FBLPromise<GULURLSessionDataResponse *> *(NSData *HTTPBody) {
        return [self.APIService sendRequestWithURL:URL
                                        HTTPMethod:@"POST"
                                              body:HTTPBody
                                 additionalHeaders:@{kContentTypeKey : kJSONContentType}];
      })
      .then(^id _Nullable(GULURLSessionDataResponse *_Nullable response) {
        return [self.APIService appCheckTokenWithAPIResponse:response];
      });
}

#pragma mark - Helpers

- (FBLPromise<NSData *> *)HTTPBodyWithDebugToken:(NSString *)debugToken {
  if (debugToken.length <= 0) {
    FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
    [rejectedPromise
        reject:[FIRAppCheckErrorUtil errorWithFailureReason:@"Debug token must not be empty."]];
    return rejectedPromise;
  }

  return [FBLPromise onQueue:[self backgroundQueue]
                          do:^id _Nullable {
                            NSError *encodingError;
                            NSData *payloadJSON = [NSJSONSerialization
                                dataWithJSONObject:@{kDebugTokenField : debugToken}
                                           options:0
                                             error:&encodingError];

                            if (payloadJSON != nil) {
                              return payloadJSON;
                            } else {
                              return [FIRAppCheckErrorUtil JSONSerializationError:encodingError];
                            }
                          }];
}

- (dispatch_queue_t)backgroundQueue {
  return dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
}

@end

NS_ASSUME_NONNULL_END
