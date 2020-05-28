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

@property(nonatomic, readonly) NSURLSession *URLSession;
@property(nonatomic, readonly) NSString *APIKey;
@property(nonatomic, readonly) NSString *projectID;
@property(nonatomic, readonly) NSString *appID;

@end

@implementation FIRDeviceCheckAPIService

- (instancetype)initWithURLSession:(NSURLSession *)session
                            APIKey:(NSString *)APIKey
                         projectID:(NSString *)projectID
                             appID:(NSString *)appID {
  self = [super init];
  if (self) {
    _URLSession = session;
    _APIKey = APIKey;
    _projectID = projectID;
    _appID = appID;
  }
  return self;
}

#pragma mark - Public API

- (FBLPromise<FIRAppCheckToken *> *)appCheckTokenWithDeviceToken:(NSData *)deviceToken {
  return [self createCheckTokenWithDeviceToken:deviceToken]
      .then(^id _Nullable(NSURLRequest *_Nullable request) {
        return [self URLRequestPromise:request];
      })
      .then(^id _Nullable(FIRDeviceCheckURLSessionResponse *_Nullable response) {
        return [self appCheckTokenWithAPIResponse:response];
      });
}

#pragma mark - URL request

- (FBLPromise<FIRDeviceCheckURLSessionResponse *> *)URLRequestPromise:(NSURLRequest *)request {
  return [[FBLPromise async:^(FBLPromiseFulfillBlock fulfill, FBLPromiseRejectBlock reject) {
    [[self.URLSession
        dataTaskWithRequest:request
          completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                              NSError *_Nullable error) {
            if (error) {
              reject(error);
            } else {
              fulfill([[FIRDeviceCheckURLSessionResponse alloc]
                  initWithResponse:(NSHTTPURLResponse *)response
                              data:data]);
            }
          }] resume];
  }] then:^id _Nullable(FIRDeviceCheckURLSessionResponse *response) {
    return [self validateHTTPResponseStatusCode:response];
  }];
}

- (FBLPromise<FIRDeviceCheckURLSessionResponse *> *)validateHTTPResponseStatusCode:
    (FIRDeviceCheckURLSessionResponse *)response {
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

#pragma mark - Device Check request

- (FBLPromise<NSURLRequest *> *)createCheckTokenWithDeviceToken:(NSData *)deviceToken {
  return [FBLPromise
      onQueue:dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
           do:^id _Nullable {
             NSString *baseURL = @"https://firebaseappcheck.googleapis.com/v1alpha1";
             NSString *URLString =
                 [NSString stringWithFormat:@"%@/projects/%@/apps/%@:exchangeDeviceCheckToken",
                                            baseURL, self.projectID, self.appID];
             NSURL *URL = [NSURL URLWithString:URLString];

             NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
             request.HTTPBody = deviceToken;

             [request setValue:self.APIKey forHTTPHeaderField:kAPIKeyHeaderKey];
             // User agent header.
             [request setValue:[FIRApp firebaseUserAgent] forHTTPHeaderField:kUserAgentKey];
             // Heartbeat header.
             [request setValue:@([FIRHeartbeatInfo heartbeatCodeForTag:kHeartbeatStorageTag])
                                   .stringValue
                 forHTTPHeaderField:kHeartbeatKey];

             return [request copy];
           }];
}

- (FBLPromise<FIRAppCheckToken *> *)appCheckTokenWithAPIResponse:
    (FIRDeviceCheckURLSessionResponse *)response {
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
