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

#include <memory>

#import "Firestore/Source/Local/FSTMemoryPersistence.h"
#include "Firestore/core/src/firebase/firestore/local/memory_remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/local/remote_document_cache.h"
#include "absl/memory/memory.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"
#import "Firestore/Example/Tests/Local/FSTRemoteDocumentCacheTests.h"

using firebase::firestore::local::MemoryRemoteDocumentCache;
using firebase::firestore::local::RemoteDocumentCache;

@interface FSTMemoryRemoteDocumentCacheTests : FSTRemoteDocumentCacheTests
@end

/**
 * The tests for FSTMemoryRemoteDocumentCache are performed on the FSTRemoteDocumentCache
 * protocol in FSTRemoteDocumentCacheTests. This class is merely responsible for setting up and
 * tearing down the @a remoteDocumentCache.
 */
@implementation FSTMemoryRemoteDocumentCacheTests {
  std::unique_ptr<MemoryRemoteDocumentCache> _cache;
}

- (void)setUp {
  [super setUp];

  self.persistence = [FSTPersistenceTestHelpers eagerGCMemoryPersistence];
  HARD_ASSERT(!_cache, "Previous cache not torn down");
  _cache = absl::make_unique<MemoryRemoteDocumentCache>(self.persistence);
}

- (RemoteDocumentCache *)remoteDocumentCache {
  return _cache.get();
}

- (void)tearDown {
  _cache.reset();
  self.persistence = nil;

  [super tearDown];
}

@end
