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

#import "FIRDeviceCheckAPIService.h"

#import <FBLPromises/FBLPromises.h>

#import "FIRAppCheckToken+APIResponse.h"

#import "FIRAppCheckErrorUtil.h"
#import "FIRAppCheckLogger.h"

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRHeartbeatInfo.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const kAPIKeyHeaderKey = @"X-Goog-Api-Key";
static NSString *const kHeartbeatKey = @"X-firebase-client-log-type";
static NSString *const kHeartbeatStorageTag = @"fire-app-check";
static NSString *const kUserAgentKey = @"X-firebase-client";

@interface FIRDeviceCheckURLSessionResponse : NSObject
@property(nonatomic) NSHTTPURLResponse *HTTPResponse;
@property(nonatomic) NSData *data;

- (instancetype)initWithResponse:(NSHTTPURLResponse *)response data:(nullable NSData *)data;
@end

@implementation FIRDeviceCheckURLSessionResponse

- (instancetype)initWithResponse:(NSHTTPURLResponse *)response data:(nullable NSData *)data {
  self = [super init];
  if (self) {
    _HTTPResponse = response;
    _data = data ?: [NSData data];
  }
  return self;
}

@end

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

  return [self.APIService sendRequestWithURL:URL
                                  HTTPMethod:@"POST"
                                        body:deviceToken
                           additionalHeaders:nil]
      .then(^id _Nullable(FIRAppCheckHTTPResponse *_Nullable response) {
        return [self appCheckTokenWithAPIResponse:response];
      });
}

- (FBLPromise<FIRAppCheckToken *> *)appCheckTokenWithAPIResponse:
    (FIRAppCheckHTTPResponse *)response {
  return [FBLPromise do:^id _Nullable {
    NSError *error;

    FIRAppCheckToken *token = [[FIRAppCheckToken alloc] initWithDeviceCheckResponse:response.data
                                                                        requestDate:[NSDate date]
                                                                              error:&error];
    return token ?: error;
  }];
}

@end

NS_ASSUME_NONNULL_END
