/*
 * Copyright 2018 Google
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

#import "Firestore/Example/Tests/Local/FSTLRUGarbageCollectorTests.h"

#include "Firestore/core/src/firebase/firestore/local/memory_lru_reference_delegate.h"
#include "Firestore/core/src/firebase/firestore/local/memory_persistence.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/test/firebase/firestore/local/persistence_testing.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::local::LruParams;
using firebase::firestore::local::MemoryLruReferenceDelegate;
using firebase::firestore::local::MemoryPersistenceWithLruGcForTesting;
using firebase::firestore::local::Persistence;

NS_ASSUME_NONNULL_BEGIN

@interface FSTMemoryLRUGarbageCollectionTests : FSTLRUGarbageCollectorTests
@end

@implementation FSTMemoryLRUGarbageCollectionTests

- (std::unique_ptr<Persistence>)newPersistenceWithLruParams:(LruParams)lruParams {
  return MemoryPersistenceWithLruGcForTesting(lruParams);
}

- (BOOL)sentinelExists:(const DocumentKey &)key {
  auto delegate = static_cast<MemoryLruReferenceDelegate *>(self.persistence->reference_delegate());
  return delegate->IsPinnedAtSequenceNumber(0, key);
}

@end

NS_ASSUME_NONNULL_END
