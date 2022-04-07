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

#import <Foundation/Foundation.h>

@class FBLPromise<Result>;
@class GULURLSessionDataResponse;
@class FIRAppCheckToken;

@protocol FIRHeartbeatLoggerProtocol;

NS_ASSUME_NONNULL_BEGIN

@protocol FIRAppCheckAPIServiceProtocol <NSObject>

@property(nonatomic, readonly) NSString *baseURL;

- (FBLPromise<GULURLSessionDataResponse *> *)
    sendRequestWithURL:(NSURL *)requestURL
            HTTPMethod:(NSString *)HTTPMethod
                  body:(nullable NSData *)body
     additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders;

- (FBLPromise<FIRAppCheckToken *> *)appCheckTokenWithAPIResponse:
    (GULURLSessionDataResponse *)response;

@end

@interface FIRAppCheckAPIService : NSObject <FIRAppCheckAPIServiceProtocol>

/**
 * The default initializer.
 * @param session The URL session used to make network requests.
 * @param APIKey The Firebase project API key (see `FIROptions.APIKey`).
 * @param appID The Firebase app ID (see `FIROptions.googleAppID`).
 * @param heartbeatLogger The heartbeat logger used to populate heartbeat data in request headers.
 */
- (instancetype)initWithURLSession:(NSURLSession *)session
                            APIKey:(NSString *)APIKey
                             appID:(NSString *)appID
                   heartbeatLogger:(id<FIRHeartbeatLoggerProtocol>)heartbeatLogger;

@end

NS_ASSUME_NONNULL_END
