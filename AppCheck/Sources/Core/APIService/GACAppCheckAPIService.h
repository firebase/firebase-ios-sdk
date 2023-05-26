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

#import "AppCheck/Sources/Public/AppCheck/GACAppAttestProvider.h"

@class FBLPromise<Result>;
@class GULURLSessionDataResponse;
@class GACAppCheckToken;

NS_ASSUME_NONNULL_BEGIN

@protocol GACAppCheckAPIServiceProtocol <NSObject>

@property(nonatomic, readonly) NSString *baseURL;

- (FBLPromise<GULURLSessionDataResponse *> *)
    sendRequestWithURL:(NSURL *)requestURL
            HTTPMethod:(NSString *)HTTPMethod
                  body:(nullable NSData *)body
     additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders;

- (FBLPromise<GACAppCheckToken *> *)appCheckTokenWithAPIResponse:
    (GULURLSessionDataResponse *)response;

@end

@interface GACAppCheckAPIService : NSObject <GACAppCheckAPIServiceProtocol>

/**
 * The default initializer.
 * @param session The URL session used to make network requests.
 * @param APIKey The Google Cloud Platform API key, if needed, or nil.
 * @param requestHooks Hooks that will be invoked on requests through this service.
 */
- (instancetype)initWithURLSession:(NSURLSession *)session
                            APIKey:(nullable NSString *)APIKey
                      requestHooks:(nullable NSArray<GACAppCheckAPIRequestHook> *)requestHooks;

@end

NS_ASSUME_NONNULL_END
