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

#import "FirebaseAppCheck/Sources/DeviceCheckProvider/API/FIRDeviceCheckAPIService.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import <GoogleUtilities/GULURLSessionDataResponse.h>

#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"
#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckToken+APIResponse.h"

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"

#import "FirebaseCore/Internal/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kContentTypeKey = @"Content-Type";
static NSString *const kJSONContentType = @"application/json";
static NSString *const kDeviceTokenField = @"device_token";

@interface FIRDeviceCheckAPIService ()

@property(nonatomic, readonly) id<FIRAppCheckAPIServiceProtocol> APIService;

@property(nonatomic, readonly) NSString *projectID;
@property(nonatomic, readonly) NSString *appID;

@end

@implementation FIRDeviceCheckAPIService

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

- (FBLPromise<FIRAppCheckToken *> *)appCheckTokenWithDeviceToken:(NSData *)deviceToken {
  NSString *URLString =
      [NSString stringWithFormat:@"%@/projects/%@/apps/%@:exchangeDeviceCheckToken",
                                 self.APIService.baseURL, self.projectID, self.appID];
  NSURL *URL = [NSURL URLWithString:URLString];

  return [self HTTPBodyWithDeviceToken:deviceToken]
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

- (FBLPromise<NSData *> *)HTTPBodyWithDeviceToken:(NSData *)deviceToken {
  if (deviceToken.length <= 0) {
    FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
    [rejectedPromise reject:[FIRAppCheckErrorUtil
                                errorWithFailureReason:@"DeviceCheck token must not be empty."]];
    return rejectedPromise;
  }

  return [FBLPromise onQueue:[self backgroundQueue]
                          do:^id _Nullable {
                            NSString *base64EncodedToken =
                                [deviceToken base64EncodedStringWithOptions:0];

                            NSError *encodingError;
                            NSData *payloadJSON = [NSJSONSerialization
                                dataWithJSONObject:@{kDeviceTokenField : base64EncodedToken}
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
