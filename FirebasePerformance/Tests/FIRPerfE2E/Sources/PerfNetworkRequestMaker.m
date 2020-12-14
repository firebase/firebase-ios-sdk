// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "PerfNetworkRequestMaker.h"

@interface PerfNetworkRequestMaker () <NSURLSessionDelegate, NSURLSessionDataDelegate>

@end

@implementation PerfNetworkRequestMaker

+ (void)performNetworkRequest:(NSURLRequest *)URLRequest delegate:(id<PerfTraceDelegate>)delegate {
  static dispatch_once_t onceToken;
  static NSURLSession *session = nil;
  dispatch_once(&onceToken, ^{
    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.HTTPMaximumConnectionsPerHost = 50;
    session = [NSURLSession sessionWithConfiguration:configuration];
  });
  NSURLSessionDataTask *dataTask =
      [session dataTaskWithRequest:URLRequest
                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                   NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                   NSLog(@"Received response code - %ld for URL - %@.", httpResponse.statusCode,
                         response.URL.absoluteString);
                   if (httpResponse.statusCode == 404) {
                     NSLog(@"ERROR: Something went wrong, received status code 404.");
                   }
                   [delegate traceCompleted];
                 }];
  [delegate traceStarted];
  [dataTask resume];
}

@end
