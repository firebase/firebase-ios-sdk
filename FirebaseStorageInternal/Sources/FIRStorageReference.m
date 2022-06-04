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

#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorageReference.h"

#import "FirebaseStorageInternal/Sources/FIRStorageConstants_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageDeleteTask.h"
#import "FirebaseStorageInternal/Sources/FIRStorageGetDownloadURLTask.h"
#import "FirebaseStorageInternal/Sources/FIRStorageGetMetadataTask.h"
#import "FirebaseStorageInternal/Sources/FIRStorageListResult_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageListTask.h"
#import "FirebaseStorageInternal/Sources/FIRStorageMetadata_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageReference_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageTask_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageUpdateMetadataTask.h"
#import "FirebaseStorageInternal/Sources/FIRStorageUtils.h"
#import "FirebaseStorageInternal/Sources/FIRStorage_Private.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

#if SWIFT_PACKAGE
@import GTMSessionFetcherCore;
#else
#import <GTMSessionFetcher/GTMSessionFetcher.h>
#import <GTMSessionFetcher/GTMSessionFetcherService.h>
#endif

@implementation FIRIMPLStorageReference

- (instancetype)initWithStorage:(FIRIMPLStorage *)storage path:(FIRStoragePath *)path {
  self = [super init];
  if (self) {
    _storage = storage;
    _path = path;
  }
  return self;
}

#pragma mark - NSObject overrides

- (instancetype)copyWithZone:(NSZone *)zone {
  FIRIMPLStorageReference *copiedReference =
      [[[self class] allocWithZone:zone] initWithStorage:_storage path:_path];
  return copiedReference;
}

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }

  if (![object isKindOfClass:[FIRIMPLStorageReference class]]) {
    return NO;
  }

  BOOL isObjectEqual = [self isEqualToFIRIMPLStorageReference:(FIRIMPLStorageReference *)object];
  return isObjectEqual;
}

- (BOOL)isEqualToFIRIMPLStorageReference:(FIRIMPLStorageReference *)reference {
  BOOL isEqual = [_storage isEqual:reference.storage] && [_path isEqual:reference.path];
  return isEqual;
}

- (NSUInteger)hash {
  NSUInteger hash = [_storage hash] ^ [_path hash];
  return hash;
}

- (NSString *)description {
  return [self stringValue];
}

- (NSString *)stringValue {
  NSString *value = [NSString stringWithFormat:@"gs://%@/%@", _path.bucket, _path.object ?: @""];
  return value;
}

#pragma mark - Property Getters

- (NSString *)bucket {
  NSString *bucket = _path.bucket;
  return bucket;
}

- (NSString *)fullPath {
  NSString *path = _path.object;
  if (!path) {
    path = @"";
  }
  return path;
}

- (NSString *)name {
  NSString *name = [_path.object lastPathComponent];
  if (!name) {
    name = @"";
  }
  return name;
}

#pragma mark - Path Operations

- (FIRIMPLStorageReference *)root {
  FIRStoragePath *rootPath = [_path root];
  FIRIMPLStorageReference *rootReference =
      [[FIRIMPLStorageReference alloc] initWithStorage:_storage path:rootPath];
  return rootReference;
}

- (nullable FIRIMPLStorageReference *)parent {
  FIRStoragePath *parentPath = [_path parent];
  if (!parentPath) {
    return nil;
  }

  FIRIMPLStorageReference *parentReference =
      [[FIRIMPLStorageReference alloc] initWithStorage:_storage path:parentPath];
  return parentReference;
}

- (FIRIMPLStorageReference *)child:(NSString *)path {
  FIRStoragePath *childPath = [_path child:path];
  FIRIMPLStorageReference *childReference =
      [[FIRIMPLStorageReference alloc] initWithStorage:_storage path:childPath];
  return childReference;
}

- (void)downloadURLWithCompletion:(FIRStorageVoidURLError)completion {
  FIRStorageGetDownloadURLTask *task =
      [[FIRStorageGetDownloadURLTask alloc] initWithReference:self
                                               fetcherService:_storage.fetcherServiceForApp
                                                dispatchQueue:_storage.dispatchQueue
                                                   completion:completion];
  [task enqueue];
}

#pragma mark - List

- (void)listWithMaxResults:(int64_t)maxResults completion:(FIRStorageVoidListError)completion {
  if (maxResults <= 0 || maxResults > 1000) {
    completion(
        nil, [FIRStorageUtils storageErrorWithDescription:
                                  @"Argument 'maxResults' must be between 1 and 1000 inclusive."
                                                     code:FIRIMPLStorageErrorCodeInvalidArgument]);
  } else {
    FIRStorageListTask *task =
        [[FIRStorageListTask alloc] initWithReference:self
                                       fetcherService:_storage.fetcherServiceForApp
                                        dispatchQueue:_storage.dispatchQueue
                                             pageSize:@(maxResults)
                                    previousPageToken:nil
                                           completion:completion];
    [task enqueue];
  }
}

- (void)listWithMaxResults:(int64_t)maxResults
                 pageToken:(NSString *)pageToken
                completion:(FIRStorageVoidListError)completion {
  if (maxResults <= 0 || maxResults > 1000) {
    completion(
        nil, [FIRStorageUtils storageErrorWithDescription:
                                  @"Argument 'maxResults' must be between 1 and 1000 inclusive."
                                                     code:FIRIMPLStorageErrorCodeInvalidArgument]);
  } else {
    FIRStorageListTask *task =
        [[FIRStorageListTask alloc] initWithReference:self
                                       fetcherService:_storage.fetcherServiceForApp
                                        dispatchQueue:_storage.dispatchQueue
                                             pageSize:@(maxResults)
                                    previousPageToken:pageToken
                                           completion:completion];
    [task enqueue];
  }
}

- (void)listAllWithCompletion:(FIRStorageVoidListError)completion {
  NSMutableArray *prefixes = [NSMutableArray new];
  NSMutableArray *items = [NSMutableArray new];

  __weak FIRIMPLStorageReference *weakSelf = self;

  __block FIRStorageVoidListError paginatedCompletion = ^(FIRIMPLStorageListResult *listResult,
                                                          NSError *error) {
    if (error) {
      completion(nil, error);
      return;
    }

    FIRIMPLStorageReference *strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }

    [prefixes addObjectsFromArray:listResult.prefixes];
    [items addObjectsFromArray:listResult.items];

    if (listResult.pageToken) {
      FIRStorageListTask *nextPage =
          [[FIRStorageListTask alloc] initWithReference:self
                                         fetcherService:strongSelf->_storage.fetcherServiceForApp
                                          dispatchQueue:strongSelf->_storage.dispatchQueue
                                               pageSize:nil
                                      previousPageToken:listResult.pageToken
                                             completion:paginatedCompletion];
      [nextPage enqueue];
    } else {
      FIRIMPLStorageListResult *result = [[FIRIMPLStorageListResult alloc] initWithPrefixes:prefixes
                                                                                      items:items
                                                                                  pageToken:nil];
      // Break the retain cycle we set up indirectly by passing the callback to `nextPage`.
      paginatedCompletion = nil;
      completion(result, nil);
    }
  };

  FIRStorageListTask *task =
      [[FIRStorageListTask alloc] initWithReference:self
                                     fetcherService:_storage.fetcherServiceForApp
                                      dispatchQueue:_storage.dispatchQueue
                                           pageSize:nil
                                  previousPageToken:nil
                                         completion:paginatedCompletion];

  [task enqueue];
}

#pragma mark - Metadata Operations

- (void)metadataWithCompletion:(FIRStorageVoidMetadataError)completion {
  FIRStorageGetMetadataTask *task =
      [[FIRStorageGetMetadataTask alloc] initWithReference:self
                                            fetcherService:_storage.fetcherServiceForApp
                                             dispatchQueue:_storage.dispatchQueue
                                                completion:completion];
  [task enqueue];
}

- (void)updateMetadata:(FIRIMPLStorageMetadata *)metadata
            completion:(nullable FIRStorageVoidMetadataError)completion {
  FIRStorageUpdateMetadataTask *task =
      [[FIRStorageUpdateMetadataTask alloc] initWithReference:self
                                               fetcherService:_storage.fetcherServiceForApp
                                                dispatchQueue:_storage.dispatchQueue
                                                     metadata:metadata
                                                   completion:completion];
  [task enqueue];
}

#pragma mark - Delete

- (void)deleteWithCompletion:(nullable FIRStorageVoidError)completion {
  FIRStorageDeleteTask *task =
      [[FIRStorageDeleteTask alloc] initWithReference:self
                                       fetcherService:_storage.fetcherServiceForApp
                                        dispatchQueue:_storage.dispatchQueue
                                           completion:completion];
  [task enqueue];
}

@end
