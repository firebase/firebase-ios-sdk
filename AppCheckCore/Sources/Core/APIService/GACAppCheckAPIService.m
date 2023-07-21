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
#import "AppCheckCore/Sources/Core/APIService/GACAppCheckAPIService.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "AppCheckCore/Sources/Core/APIService/GACAppCheckToken+APIResponse.h"
#import "AppCheckCore/Sources/Core/Errors/GACAppCheckErrorUtil.h"
#import "AppCheckCore/Sources/Core/GACAppCheckLogger+Internal.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckErrors.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckLogger.h"

#import <GoogleUtilities/GULURLSessionDataResponse.h>
#import <GoogleUtilities/NSURLSession+GULPromises.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const kAPIKeyHeaderKey = @"X-Goog-Api-Key";
static NSString *const kBundleIdKey = @"X-Ios-Bundle-Identifier";

static NSString *const kDefaultBaseURL = @"https://firebaseappcheck.googleapis.com/v1";

@interface GACAppCheckAPIService ()

@property(nonatomic, readonly) NSURLSession *URLSession;
@property(nonatomic, readonly, nullable) NSString *APIKey;
@property(nonatomic, readonly) NSArray<GACAppCheckAPIRequestHook> *requestHooks;

@end

@implementation GACAppCheckAPIService

// Synthesize properties declared in a protocol.
@synthesize baseURL = _baseURL;

- (instancetype)initWithURLSession:(NSURLSession *)session
                           baseURL:(nullable NSString *)baseURL
                            APIKey:(nullable NSString *)APIKey
                      requestHooks:(nullable NSArray<GACAppCheckAPIRequestHook> *)requestHooks {
  self = [super init];
  if (self) {
    _URLSession = session;
    _APIKey = APIKey;
    _requestHooks = requestHooks ? [requestHooks copy] : @[];
    _baseURL = baseURL ?: kDefaultBaseURL;
  }
  return self;
}

- (FBLPromise<GULURLSessionDataResponse *> *)
    sendRequestWithURL:(NSURL *)requestURL
            HTTPMethod:(NSString *)HTTPMethod
                  body:(nullable NSData *)body
     additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders {
  return [self requestWithURL:requestURL
                    HTTPMethod:HTTPMethod
                          body:body
             additionalHeaders:additionalHeaders]
      .then(^id _Nullable(NSURLRequest *_Nullable request) {
        return [self sendURLRequest:request];
      })
      .then(^id _Nullable(GULURLSessionDataResponse *_Nullable response) {
        return [self validateHTTPResponseStatusCode:response];
      });
}

- (FBLPromise<NSURLRequest *> *)requestWithURL:(NSURL *)requestURL
                                    HTTPMethod:(NSString *)HTTPMethod
                                          body:(NSData *)body
                             additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)
                                                   additionalHeaders {
  return [FBLPromise
      onQueue:[self defaultQueue]
           do:^id _Nullable {
             __block NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
             request.HTTPMethod = HTTPMethod;
             request.HTTPBody = body;

             if (self.APIKey) {
               [request setValue:self.APIKey forHTTPHeaderField:kAPIKeyHeaderKey];
             }

             [request setValue:[[NSBundle mainBundle] bundleIdentifier]
                 forHTTPHeaderField:kBundleIdKey];

             [additionalHeaders
                 enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSString *_Nonnull obj,
                                                     BOOL *_Nonnull stop) {
                   [request setValue:obj forHTTPHeaderField:key];
                 }];

             for (GACAppCheckAPIRequestHook requestHook in self.requestHooks) {
               requestHook(request);
             }

             return [request copy];
           }];
}

- (FBLPromise<GULURLSessionDataResponse *> *)sendURLRequest:(NSURLRequest *)request {
  return [self.URLSession gul_dataTaskPromiseWithRequest:request]
      .recover(^id(NSError *networkError) {
        // Wrap raw network error into App Check domain error.
        return [GACAppCheckErrorUtil APIErrorWithNetworkError:networkError];
      })
      .then(^id _Nullable(GULURLSessionDataResponse *response) {
        return [self validateHTTPResponseStatusCode:response];
      });
}

- (FBLPromise<GULURLSessionDataResponse *> *)validateHTTPResponseStatusCode:
    (GULURLSessionDataResponse *)response {
  NSInteger statusCode = response.HTTPResponse.statusCode;
  return [FBLPromise do:^id _Nullable {
    if (statusCode < 200 || statusCode >= 300) {
      NSString *logMessage = [NSString
          stringWithFormat:@"Unexpected API response: %@, body: %@.", response.HTTPResponse,
                           [[NSString alloc] initWithData:response.HTTPBody
                                                 encoding:NSUTF8StringEncoding]];
      GACAppCheckLogDebug(GACLoggerAppCheckMessageCodeUnexpectedHTTPCode, logMessage);
      return [GACAppCheckErrorUtil APIErrorWithHTTPResponse:response.HTTPResponse
                                                       data:response.HTTPBody];
    }
    return response;
  }];
}

- (FBLPromise<GACAppCheckToken *> *)appCheckTokenWithAPIResponse:
    (GULURLSessionDataResponse *)response {
  return [FBLPromise onQueue:[self defaultQueue]
                          do:^id _Nullable {
                            NSError *error;

                            GACAppCheckToken *token = [[GACAppCheckToken alloc]
                                initWithTokenExchangeResponse:response.HTTPBody
                                                  requestDate:[NSDate date]
                                                        error:&error];
                            return token ?: error;
                          }];
}

- (dispatch_queue_t)defaultQueue {
  return dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
}

@end

NS_ASSUME_NONNULL_END
