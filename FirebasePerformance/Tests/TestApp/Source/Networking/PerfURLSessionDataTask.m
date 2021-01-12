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

// Non-google3 relative import to support building with Xcode.
#import "PerfURLSessionDataTask.h"
#import "PerfNetworkConnection+Protected.h"

@interface PerfURLSessionDataTask ()

@property(nonatomic, copy) NSString *urlString;

@end

@implementation PerfURLSessionDataTask

#pragma mark - NetworkConnection

- (void)makeNetworkRequestWithSuccessCallback:(SuccessNetworkCallback)success
                              failureCallback:(FailureNetworkCallback)fail {
  [self logOperationStart];
  NSURLSession *session = [NSURLSession sharedSession];

  NSURLSessionDataTask *dataTask =
      [session dataTaskWithURL:[NSURL URLWithString:self.urlString]
             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
               if (error) {
                 [self logOperationFail];
                 fail(error);
               } else {
                 [self logOperationSuccess];
                 success();
               }
             }];
  [dataTask resume];
}

@end
