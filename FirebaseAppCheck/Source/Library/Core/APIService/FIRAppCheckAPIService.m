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
#import "FIRAppCheckAPIService.h"

#import <FBLPromises/FBLPromises.h>

#import "FIRAppCheckErrorUtil.h"
#import "FIRAppCheckLogger.h"

// TODO: Update to repo relative imports
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRHeartbeatInfo.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const kAPIKeyHeaderKey = @"X-Goog-Api-Key";
static NSString *const kHeartbeatKey = @"X-firebase-client-log-type";
static NSString *const kHeartbeatStorageTag = @"fire-app-check";
static NSString *const kUserAgentKey = @"X-firebase-client";

@interface FIRAppCheckAPIService ()

@property(nonatomic, readonly) NSURLSession *URLSession;
@property(nonatomic, readonly) NSString *APIKey;
@property(nonatomic, readonly) NSString *projectID;
@property(nonatomic, readonly) NSString *appID;

@end

@implementation FIRAppCheckAPIService

// Synthesize properties declared in a protocol.
@synthesize baseURL = _baseURL;

- (instancetype)initWithURLSession:(NSURLSession *)session
                            APIKey:(NSString *)APIKey
                         projectID:(NSString *)projectID
                             appID:(NSString *)appID {
  NSString *defaultBaseURL = @"https://staging-firebaseappcheck-pa.sandbox.googleapis.com/v1alpha";
  return [self initWithURLSession:session
                           APIKey:APIKey
                        projectID:projectID
                            appID:appID
                          baseURL:defaultBaseURL];
}

- (instancetype)initWithURLSession:(NSURLSession *)session
                            APIKey:(NSString *)APIKey
                         projectID:(NSString *)projectID
                             appID:(NSString *)appID
                           baseURL:(NSString *)baseURL {
  self = [super init];
  if (self) {
    _URLSession = session;
    _APIKey = APIKey;
    _projectID = projectID;
    _appID = appID;
    _baseURL = baseURL;
  }
  return self;
}

- (FBLPromise<FIRAppCheckHTTPResponse *> *)
    sendRequestWithURL:(NSURL *)requestURL
            HTTPMethod:(NSString *)HTTPMethod
                  body:(NSData *)body
     additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)additionalHeaders {
  return [self requestWithURL:requestURL
                    HTTPMethod:HTTPMethod
                          body:body
             additionalHeaders:additionalHeaders]
      .then(^id _Nullable(NSURLRequest *_Nullable request) {
        return [self sendURLRequest:request];
      })
      .then(^id _Nullable(FIRAppCheckHTTPResponse *_Nullable response) {
        return [self validateHTTPResponseStatusCode:response];
      });
}

- (FBLPromise<NSURLRequest *> *)requestWithURL:(NSURL *)requestURL
                                    HTTPMethod:(NSString *)HTTPMethod
                                          body:(NSData *)body
                             additionalHeaders:(nullable NSDictionary<NSString *, NSString *> *)
                                                   additionalHeaders {
  return [FBLPromise
      onQueue:dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)
           do:^id _Nullable {
             __block NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
             request.HTTPMethod = HTTPMethod;
             request.HTTPBody = body;

             [request setValue:self.APIKey forHTTPHeaderField:kAPIKeyHeaderKey];
             // User agent header.
             [request setValue:[FIRApp firebaseUserAgent] forHTTPHeaderField:kUserAgentKey];
             // Heartbeat header.
             [request setValue:@([FIRHeartbeatInfo heartbeatCodeForTag:kHeartbeatStorageTag])
                                   .stringValue
                 forHTTPHeaderField:kHeartbeatKey];

             [additionalHeaders
                 enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull key, NSString *_Nonnull obj,
                                                     BOOL *_Nonnull stop) {
                   [request setValue:obj forHTTPHeaderField:key];
                 }];

             return [request copy];
           }];
}

- (FBLPromise<FIRAppCheckHTTPResponse *> *)sendURLRequest:(NSURLRequest *)request {
  return [FBLPromise async:^(FBLPromiseFulfillBlock fulfill, FBLPromiseRejectBlock reject) {
           NSURLSessionDataTask *dataTask = [self.URLSession
               dataTaskWithRequest:request
                 completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                                     NSError *_Nullable error) {
                   if (error) {
                     reject(error);
                   } else {
                     fulfill([[FIRAppCheckHTTPResponse alloc]
                         initWithResponse:(NSHTTPURLResponse *)response
                                     data:data]);
                   }
                 }];
           [dataTask resume];
         }]
      .recover(^id(NSError *networkError) {
        // Wrap raw network error into App Check domain error.
        return [FIRAppCheckErrorUtil APIErrorWithNetworkError:networkError];
      })
      .then(^id _Nullable(FIRAppCheckHTTPResponse *response) {
        return [self validateHTTPResponseStatusCode:response];
      });
}

- (FBLPromise<FIRAppCheckHTTPResponse *> *)validateHTTPResponseStatusCode:
    (FIRAppCheckHTTPResponse *)response {
  NSInteger statusCode = response.HTTPResponse.statusCode;
  return [FBLPromise do:^id _Nullable {
    if (statusCode < 200 || statusCode >= 300) {
      FIRLogDebug(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageCodeUnknown,
                  @"Unexpected API response: %@, body: %@.", response.HTTPResponse,
                  [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding]);
      return [FIRAppCheckErrorUtil APIErrorWithHTTPResponse:response.HTTPResponse
                                                       data:response.data];
    }
    return response;
  }];
}

@end

NS_ASSUME_NONNULL_END
