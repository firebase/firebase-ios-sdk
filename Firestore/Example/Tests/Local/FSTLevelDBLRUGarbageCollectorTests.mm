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

#include <string>

#import "Firestore/Example/Tests/Local/FSTLRUGarbageCollectorTests.h"

#include "Firestore/core/src/firebase/firestore/local/leveldb_key.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/lru_garbage_collector.h"
#include "Firestore/core/src/firebase/firestore/local/persistence.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/test/firebase/firestore/local/persistence_testing.h"

using firebase::firestore::local::LevelDbDocumentTargetKey;
using firebase::firestore::local::LevelDbPersistence;
using firebase::firestore::local::LevelDbPersistenceForTesting;
using firebase::firestore::local::Persistence;
using firebase::firestore::model::DocumentKey;

using firebase::firestore::local::LruParams;

NS_ASSUME_NONNULL_BEGIN

@interface FSTLevelDBLRUGarbageCollectorTests : FSTLRUGarbageCollectorTests
@end

@implementation FSTLevelDBLRUGarbageCollectorTests

- (std::unique_ptr<Persistence>)newPersistenceWithLruParams:(LruParams)lruParams {
  return LevelDbPersistenceForTesting(lruParams);
}

- (BOOL)sentinelExists:(const DocumentKey &)key {
  auto db = static_cast<local::LevelDbPersistence *>(self.persistence);
  std::string sentinelKey = LevelDbDocumentTargetKey::SentinelKey(key);
  std::string unusedValue;
  return !db->current_transaction()->Get(sentinelKey, &unusedValue).IsNotFound();
}

@end

NS_ASSUME_NONNULL_END
