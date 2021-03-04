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
#import "PerfNetworkConnection.h"
#import "../Models/PerfLogger.h"
#import "PerfNetworkConnection+Protected.h"

@interface PerfNetworkConnection () {
  NSString *_urlString;
}

@end

@implementation PerfNetworkConnection

#pragma mark - Initialization

- (instancetype)initWithURLString:(NSString *)urlString {
  self = [super init];
  if (self) {
    self.urlString = urlString;
  }
  return self;
}

#pragma mark - Properties

- (void)setUrlString:(NSString *)urlString {
  _urlString = [urlString copy];
  PerfLog(@"Set URL %@", urlString);
}

- (NSString *)urlString {
  return _urlString;
}

#pragma mark - NetworkConnection

- (void)makeNetworkRequestWithSuccessCallback:(SuccessNetworkCallback)success
                              failureCallback:(FailureNetworkCallback)fail {
  NSAssert(NO, @"Abstract class. The method must be overriden.");
}

@end
