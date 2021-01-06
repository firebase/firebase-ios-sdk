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
#import "PerfURLSessionDataTaskWithDelegate.h"
#import "PerfNetworkConnection+Protected.h"

@interface PerfURLSessionDataTaskWithDelegate () <NSURLSessionDataDelegate>

@property(nonatomic, copy) NSString *urlString;

@property(nonatomic, copy) SuccessNetworkCallback successCallback;
@property(nonatomic, copy) FailureNetworkCallback failureCallback;

@end

@implementation PerfURLSessionDataTaskWithDelegate

#pragma mark - NetworkConnection

- (void)makeNetworkRequestWithSuccessCallback:(SuccessNetworkCallback)success
                              failureCallback:(FailureNetworkCallback)fail {
  [self logOperationStart];
  self.successCallback = success;
  self.failureCallback = fail;
  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                        delegate:self
                                                   delegateQueue:[NSOperationQueue mainQueue]];
  NSURLSessionDataTask *dataTask = [session dataTaskWithURL:[NSURL URLWithString:self.urlString]];
  [dataTask resume];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
  if (error) {
    [self logOperationFail];
    self.failureCallback(error);
  } else {
    [self logOperationSuccess];
    self.successCallback();
  }
  self.failureCallback = nil;
  self.successCallback = nil;
  [session finishTasksAndInvalidate];
}

@end
