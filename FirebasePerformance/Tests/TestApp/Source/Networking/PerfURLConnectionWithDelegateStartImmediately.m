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
#import "PerfURLConnectionWithDelegateStartImmediately.h"
#import "PerfNetworkConnection+Protected.h"

@interface PerfURLConnectionWithDelegateStartImmediately () <NSURLConnectionDelegate>

@property(nonatomic, copy) NSString *urlString;

@property(nonatomic, copy) SuccessNetworkCallback successCallback;
@property(nonatomic, copy) FailureNetworkCallback failureCallback;

@property(nonatomic, strong) NSURLConnection *URLConnection;

@end

@implementation PerfURLConnectionWithDelegateStartImmediately

#pragma mark - NetworkConnection

- (void)makeNetworkRequestWithSuccessCallback:(SuccessNetworkCallback)success
                              failureCallback:(FailureNetworkCallback)fail {
  [self logOperationStart];
  self.successCallback = success;
  self.failureCallback = fail;

  NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:self.urlString]];

  self.URLConnection = [[NSURLConnection alloc] initWithRequest:request
                                                       delegate:self
                                               startImmediately:YES];
}

#pragma mark - NSURLConnectionDelegate methods

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  [self logOperationFail];
  self.failureCallback(error);
  [self clearCallbacks];
}

#pragma mark - NSURLConnectionDataDelegate methods

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  [self logOperationSuccess];
  self.successCallback();
  [self clearCallbacks];
}

#pragma mark - Private methods

- (void)clearCallbacks {
  self.failureCallback = nil;
  self.successCallback = nil;
}

@end
