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

#import "FIRStorageGetMetadataTask.h"

#import "FIRStorageConstants.h"
#import "FIRStorageMetadata_Private.h"
#import "FIRStorageTask_Private.h"
#import "FIRStorageUtils.h"

#import "FirebaseStorage.h"

@implementation FIRStorageGetMetadataTask {
 @private
  FIRStorageVoidMetadataError _completion;
}

@synthesize fetcher = _fetcher;
@synthesize fetcherCompletion = _fetcherCompletion;

- (instancetype)initWithReference:(FIRStorageReference *)reference
                   fetcherService:(GTMSessionFetcherService *)service
                       completion:(FIRStorageVoidMetadataError)completion {
  self = [super initWithReference:reference fetcherService:service];
  if (self) {
    _completion = [completion copy];
  }
  return self;
}

- (void)dealloc {
  [_fetcher stopFetching];
}

- (void)enqueue {
  NSMutableURLRequest *request = [self.baseRequest mutableCopy];
  request.HTTPMethod = @"GET";
  request.timeoutInterval = self.reference.storage.maxOperationRetryTime;

  FIRStorageVoidMetadataError callback = _completion;
  _completion = nil;

  GTMSessionFetcher *fetcher = [self.fetcherService fetcherWithRequest:request];
  _fetcher = fetcher;
  fetcher.comment = @"GetMetadataTask";

  __weak FIRStorageGetMetadataTask *weakSelf = self;
  _fetcherCompletion = ^(NSData *data, NSError *error) {
    __strong FIRStorageGetMetadataTask *strongSelf = weakSelf;
    if (strongSelf) {
      FIRStorageMetadata *metadata = nil;
      if (error) {
        if (!strongSelf.error) {
          strongSelf.error =
              [FIRStorageErrors errorWithServerError:error reference:strongSelf.reference];
        }
      } else {
        NSDictionary *responseDictionary = [NSDictionary frs_dictionaryFromJSONData:data];
        if (responseDictionary != nil) {
          metadata = [[FIRStorageMetadata alloc] initWithDictionary:responseDictionary];
          [metadata setType:FIRStorageMetadataTypeFile];
        } else {
          strongSelf.error = [FIRStorageErrors errorWithInvalidRequest:data];
        }
      }

      if (callback) {
        callback(metadata, strongSelf.error);
      }
      strongSelf->_fetcherCompletion = nil;
    }
  };

  [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
    weakSelf.fetcherCompletion(data, error);
  }];
}

@end
