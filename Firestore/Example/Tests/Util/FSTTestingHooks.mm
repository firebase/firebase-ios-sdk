/*
 * Copyright 2023 Google LLC
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

#import "Firestore/Example/Tests/Util/FSTTestingHooks.h"

#import "FIRDocumentReference.h"

#include <memory>
#include <string>
#include <utility>

#include "Firestore/core/src/api/listener_registration.h"
#include "Firestore/core/src/remote/bloom_filter.h"
#include "Firestore/core/src/util/defer.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/src/util/string_format.h"
#include "Firestore/core/src/util/testing_hooks.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "absl/types/optional.h"

using firebase::firestore::api::ListenerRegistration;
using firebase::firestore::remote::BloomFilter;
using firebase::firestore::testutil::AsyncAccumulator;
using firebase::firestore::util::Defer;
using firebase::firestore::util::MakeStringView;
using firebase::firestore::util::StringFormat;
using firebase::firestore::util::TestingHooks;

#pragma mark - FSTTestingHooksBloomFilter extension

// Add private "init" methods to FSTTestingHooksBloomFilter.
@interface FSTTestingHooksBloomFilter ()

- (instancetype)initWithApplied:(BOOL)applied
                      hashCount:(int)hashCount
                   bitmapLength:(int)bitmapLength
                        padding:(int)padding
                      projectId:(std::string)projectId
                     databaseId:(std::string)databaseId
                    bloomFilter:(absl::optional<BloomFilter>)bloomFilter NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithBloomFilterInfo:(const TestingHooks::BloomFilterInfo&)bloomFilterInfo
                              projectId:(std::string)projectId
                             databaseId:(std::string)databaseId;

@end

#pragma mark - FSTTestingHooksBloomFilter implementation

@implementation FSTTestingHooksBloomFilter {
  std::string _projectId;
  std::string _databaseId;
  absl::optional<BloomFilter> _bloomFilter;
}

- (instancetype)initWithApplied:(BOOL)applied
                      hashCount:(int)hashCount
                   bitmapLength:(int)bitmapLength
                        padding:(int)padding
                      projectId:(std::string)projectId
                     databaseId:(std::string)databaseId
                    bloomFilter:(absl::optional<BloomFilter>)bloomFilter {
  if (self = [super init]) {
    _applied = applied;
    _hashCount = hashCount;
    _bitmapLength = bitmapLength;
    _padding = padding;
    _projectId = std::move(projectId);
    _databaseId = std::move(databaseId);
    _bloomFilter = std::move(bloomFilter);
  }
  return self;
}

- (instancetype)initWithBloomFilterInfo:(const TestingHooks::BloomFilterInfo&)bloomFilterInfo
                              projectId:(std::string)projectId
                             databaseId:(std::string)databaseId {
  return [self initWithApplied:bloomFilterInfo.applied
                     hashCount:bloomFilterInfo.hash_count
                  bitmapLength:bloomFilterInfo.bitmap_length
                       padding:bloomFilterInfo.padding
                     projectId:std::move(projectId)
                    databaseId:std::move(databaseId)
                   bloomFilter:bloomFilterInfo.bloom_filter];
}

- (BOOL)mightContain:(FIRDocumentReference*)documentRef {
  if (!_bloomFilter.has_value()) {
    return NO;
  }
  std::string document_path = StringFormat("projects/%s/databases/%s/documents/%s", _projectId,
                                           _databaseId, MakeStringView(documentRef.path));
  return _bloomFilter->MightContain(document_path);
}

@end

#pragma mark - FSTTestingHooksExistenceFilterMismatchInfo extension

// Add private "init" methods to FSTTestingHooksExistenceFilterMismatchInfo.
@interface FSTTestingHooksExistenceFilterMismatchInfo ()

- (instancetype)initWithLocalCacheCount:(int)localCacheCount
                   existenceFilterCount:(int)existenceFilterCount
                            bloomFilter:(nullable FSTTestingHooksBloomFilter*)bloomFilter
    NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithExistenceFilterMismatchInfo:
    (const TestingHooks::ExistenceFilterMismatchInfo&)existenceFilterMismatchInfo;

@end

#pragma mark - FSTTestingHooksExistenceFilterMismatchInfo implementation

@implementation FSTTestingHooksExistenceFilterMismatchInfo

- (instancetype)initWithLocalCacheCount:(int)localCacheCount
                   existenceFilterCount:(int)existenceFilterCount
                            bloomFilter:(nullable FSTTestingHooksBloomFilter*)bloomFilter {
  if (self = [super init]) {
    _localCacheCount = localCacheCount;
    _existenceFilterCount = existenceFilterCount;
    _bloomFilter = bloomFilter;
  }
  return self;
}

- (instancetype)initWithExistenceFilterMismatchInfo:
    (const TestingHooks::ExistenceFilterMismatchInfo&)existenceFilterMismatchInfo {
  FSTTestingHooksBloomFilter* bloomFilter;
  if (existenceFilterMismatchInfo.bloom_filter.has_value()) {
    bloomFilter = [[FSTTestingHooksBloomFilter alloc]
        initWithBloomFilterInfo:existenceFilterMismatchInfo.bloom_filter.value()
                      projectId:existenceFilterMismatchInfo.project_id
                     databaseId:existenceFilterMismatchInfo.database_id];
  } else {
    bloomFilter = nil;
  }

  return [self initWithLocalCacheCount:existenceFilterMismatchInfo.local_cache_count
                  existenceFilterCount:existenceFilterMismatchInfo.existence_filter_count
                           bloomFilter:bloomFilter];
}

@end

#pragma mark - FSTTestingHooks implementation

@implementation FSTTestingHooks

+ (NSArray<FSTTestingHooksExistenceFilterMismatchInfo*>*)
    captureExistenceFilterMismatchesDuringBlock:(void (^)())block {
  auto accumulator = AsyncAccumulator<TestingHooks::ExistenceFilterMismatchInfo>::NewInstance();

  TestingHooks& testing_hooks = TestingHooks::GetInstance();
  std::shared_ptr<ListenerRegistration> registration =
      testing_hooks.OnExistenceFilterMismatch(accumulator->AsCallback());
  Defer unregister_callback([registration]() { registration->Remove(); });

  block();

  NSMutableArray<FSTTestingHooksExistenceFilterMismatchInfo*>* mismatches =
      [[NSMutableArray alloc] init];
  while (!accumulator->IsEmpty()) {
    [mismatches addObject:[[FSTTestingHooksExistenceFilterMismatchInfo alloc]
                              initWithExistenceFilterMismatchInfo:accumulator->Shift()]];
  }

  return mismatches;
}

@end
