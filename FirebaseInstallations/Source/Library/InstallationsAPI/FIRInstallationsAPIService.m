/*
 * Copyright 2019 Google
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

#import "FIRInstallationsAPIService.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FIRInstallationsErrorUtil.h"
#import "FIRInstallationsItem+RegisterInstallationAPI.h"

NSString *const kFIRInstallationsAPIBaseURL = @"https://firebaseinstallations.googleapis.com";
NSString *const kFIRInstallationsAPIKey = @"x-goog-api-key";

NS_ASSUME_NONNULL_BEGIN

@interface FIRInstallationsAPIService ()
@property(nonatomic, readonly) NSURLSession *urlSession;
@property(nonatomic, readonly) NSString *APIKey;
@property(nonatomic, readonly) NSString *projectID;
@end

NS_ASSUME_NONNULL_END

@implementation FIRInstallationsAPIService

- (instancetype)initWithAPIKey:(NSString *)APIKey projectID:(NSString *)projectID {
  NSURLSession *urlSession = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
  return [self initWithURLSession:urlSession APIKey:APIKey projectID:projectID];
}

/// The initializer for tests.
- (instancetype)initWithURLSession:(NSURLSession *)urlSession
                            APIKey:(NSString *)APIKey
                         projectID:(NSString *)projectID {
  self = [super init];
  if (self) {
    _urlSession = urlSession;
    _APIKey = [APIKey copy];
    _projectID = projectID;
  }
  return self;
}

#pragma mark - Public

- (FBLPromise<FIRInstallationsItem *> *)registerInstallation:(FIRInstallationsItem *)installation {
  // TODO: Implement.
  NSURLRequest *request = [self registerRequestWithInstallation:installation];
  return [self sendURLRequest:request].then(^id _Nullable(NSArray *_Nullable value) {
    return [self registerredInstalationWithInstallation:installation
                                         serverResponse:value.lastObject
                                           responseData:value.firstObject];
  });
}

#pragma mark - Register Installation

/*
 export function getInstallationsEndpoint({ projectId }: AppConfig): string {
 return `${INSTALLATIONS_API_URL}/projects/${projectId}/installations`;
 }

 */
- (NSURLRequest *)registerRequestWithInstallation:(FIRInstallationsItem *)installation {
  NSString *urlString = [NSString stringWithFormat:@"%@//projects/%@/installations",
                                                   kFIRInstallationsAPIBaseURL, self.projectID];
  NSURL *url = [NSURL URLWithString:urlString];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

  request.HTTPMethod = @"POST";
  [request addValue:self.APIKey forHTTPHeaderField:kFIRInstallationsAPIKey];

  NSDictionary *bodyDict = @{
    @"fid" : installation.firebaseInstallationID,
    @"authVersion" : @"FIS_v2",
    @"appId" : installation.appID,
    @"sdkVersion" : @"a1.0"
  };
  [self setJSONHTTPBody:bodyDict forRequest:request];

  return [request copy];
}

- (FBLPromise<FIRInstallationsItem *> *)
    registerredInstalationWithInstallation:(FIRInstallationsItem *)installation
                            serverResponse:(NSHTTPURLResponse *)response
                              responseData:(NSData *)data {
  return [FBLPromise do:^id _Nullable {
           if (response.statusCode < 200 || response.statusCode >= 300) {
             return [FIRInstallationsErrorUtil apiErrorWithHTTPCode:response.statusCode];
           }

           return nil;
         }]
      .then(^id(id result){
        NSError *error;
        FIRInstallationsItem *registeredInstallation = [installation registeredInstallationWithJSONData:data
                                                                                                   date:[NSDate date] error:&error];
        if (registeredInstallation == nil) {
          return error;
        }

        return registeredInstallation;
      });
}

#pragma mark - URL Request

/**
 * @return FBLPromise<[NSData, NSURLResponse]>
 */
- (FBLPromise<NSArray *> *)sendURLRequest:(NSURLRequest *)request {
  // TODO: Consider supporting cancellation.
  return [FBLPromise wrap2ObjectsOrErrorCompletion:^(FBLPromise2ObjectsOrErrorCompletion handler) {
    [[self.urlSession dataTaskWithRequest:request completionHandler:handler] resume];
  }];
}

#pragma mark - JSON

- (void)setJSONHTTPBody:(NSDictionary<NSString *, id> *)body
             forRequest:(NSMutableURLRequest *)request {
  [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

  NSError *error;
  NSData *JSONData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
  if (JSONData == nil) {
    // TODO: Log or return an error.
  }
  request.HTTPBody = JSONData;
}

@end
