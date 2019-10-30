/*
 * Copyright 2017 Google
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

#import "Firestore/Example/Tests/Local/FSTQueryCacheTests.h"

#include "Firestore/core/src/firebase/firestore/local/memory_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/memory_query_cache.h"
#include "Firestore/core/src/firebase/firestore/local/reference_delegate.h"
#include "Firestore/core/src/firebase/firestore/local/reference_set.h"
#include "Firestore/core/test/firebase/firestore/local/persistence_testing.h"

using firebase::firestore::local::MemoryPersistence;
using firebase::firestore::local::MemoryPersistenceWithEagerGcForTesting;
using firebase::firestore::local::ReferenceSet;

NS_ASSUME_NONNULL_BEGIN

@interface FSTMemoryQueryCacheTests : FSTQueryCacheTests
@end

/**
 * The tests for FSTMemoryQueryCache are performed on the FSTQueryCache protocol in
 * FSTQueryCacheTests. This class is merely responsible for setting up and tearing down the
 * @a queryCache.
 */
@implementation FSTMemoryQueryCacheTests {
  std::unique_ptr<MemoryPersistence> _db;
  ReferenceSet _additionalReferences;
}

- (void)setUp {
  [super setUp];

  _db = MemoryPersistenceWithEagerGcForTesting();
  self.persistence = _db.get();
  self.queryCache = self.persistence->query_cache();
  self.persistence->reference_delegate()->AddInMemoryPins(&_additionalReferences);
}

- (void)tearDown {
  self.persistence = nil;
  self.queryCache = nil;

  [super tearDown];
}

@end

NS_ASSUME_NONNULL_END
