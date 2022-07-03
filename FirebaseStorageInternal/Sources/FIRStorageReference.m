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
#import "FirebaseStorageInternal/Sources/FIRStorageReference_Private.h"
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

@end
