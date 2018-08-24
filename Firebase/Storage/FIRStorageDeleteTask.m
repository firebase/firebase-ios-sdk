// Copyright 2017 Google
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

#import "FIRStorageDeleteTask.h"

#import "FIRStorageTask_Private.h"

@implementation FIRStorageDeleteTask {
 @private
  FIRStorageVoidError _completion;
}

@synthesize fetcher = _fetcher;
@synthesize fetcherCompletion = _fetcherCompletion;

- (void)dealloc {
  [_fetcher stopFetching];
}

- (instancetype)initWithReference:(FIRStorageReference *)reference
                   fetcherService:(GTMSessionFetcherService *)service
                       completion:(FIRStorageVoidError)completion {
  self = [super initWithReference:reference fetcherService:service];
  if (self) {
    _completion = [completion copy];
  }
  return self;
}

- (void)enqueue {
  NSMutableURLRequest *request = [self.baseRequest mutableCopy];
  request.HTTPMethod = @"DELETE";
  request.timeoutInterval = self.reference.storage.maxOperationRetryTime;

  FIRStorageVoidError callback = _completion;
  _completion = nil;

  GTMSessionFetcher *fetcher = [self.fetcherService fetcherWithRequest:request];
  _fetcher = fetcher;

  fetcher.comment = @"DeleteTask";

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
  _fetcherCompletion = ^(NSData *_Nullable data, NSError *_Nullable error) {
    if (!self.error) {
      self.error = [FIRStorageErrors errorWithServerError:error reference:self.reference];
    }
    if (callback) {
      callback(self.error);
    }
    self->_fetcherCompletion = nil;
  };
#pragma clang diangostic pop

  __weak FIRStorageDeleteTask *weakSelf = self;
  [fetcher beginFetchWithCompletionHandler:^(NSData *_Nullable data, NSError *_Nullable error) {
    weakSelf.fetcherCompletion(data, error);
  }];
}

@end
