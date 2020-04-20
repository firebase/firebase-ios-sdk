/*
 * Copyright 2019 Google LLC
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

#include "Firestore/core/src/local/leveldb_remote_document_cache.h"

#include <initializer_list>
#include <memory>
#include <string>

#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/remote_document_cache.h"
#include "Firestore/core/src/util/ordered_code.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "Firestore/core/test/unit/local/remote_document_cache_test.h"
#include "absl/memory/memory.h"
#include "leveldb/db.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using leveldb::WriteOptions;
using util::OrderedCode;

// A dummy document value, useful for testing code that's known to examine only
// document keys.
const char* kDummy = "1";

/**
 * Writes a dummy row that looks like a remote document key but is different
 * enough that it shouldn't be picked up in scans of the table.
 */
void WriteDummyRow(LevelDbPersistence* db,
                   const std::string& table_name,
                   std::initializer_list<std::string> path_segments) {
  // TODO(wilhuff): Find some way to share local::(anonymous)::Writer
  // These constants correspond to ComponentLabel in leveldb_key.mm.
  // The structure matches LevelDbRemoteDocumentKey::Key().
  std::string key;
  OrderedCode::WriteSignedNumIncreasing(&key, 5);  // TableName
  OrderedCode::WriteString(&key, table_name);

  for (const auto& segment : path_segments) {
    OrderedCode::WriteSignedNumIncreasing(&key, 62);  // PathSegment
    OrderedCode::WriteString(&key, segment);
  }

  OrderedCode::WriteSignedNumIncreasing(&key, 0);  // Terminator

  db->ptr()->Put(WriteOptions(), key, kDummy);
}

std::unique_ptr<Persistence> PersistenceFactory() {
  auto persistence = LevelDbPersistenceForTesting();

  // Write rows that go before and after remote document cache keys to ensure
  // that LevelDbRemoteDocumentCache doesn't accidentally read rows outside the
  // logical boundary of the "remote_documents" table.

  // This row is just before any possible remote document key
  WriteDummyRow(persistence.get(), "remote_document", {"row", "before"});

  // This row is just after any possible remote document key
  WriteDummyRow(persistence.get(), "remote_documents_a", {"row", "after"});

  return persistence;
}

}  // namespace

INSTANTIATE_TEST_SUITE_P(LevelDbRemoteDocumentCacheTest,
                         RemoteDocumentCacheTest,
                         testing::Values(PersistenceFactory));

}  // namespace local
}  // namespace firestore
}  // namespace firebase
