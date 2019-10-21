/*
 * Copyright 2019 Google
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

#include <initializer_list>
#include <memory>
#include <string>

#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/local/remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/util/ordered_code.h"
#include "Firestore/core/test/firebase/firestore/local/persistence_testing.h"
#include "Firestore/core/test/firebase/firestore/local/remote_document_cache_test.h"
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
                   std::initializer_list<std::string> segments) {
  // TODO(wilhuff): Find some way to share local::(anonymous)::Writer
  // These constants correspond to ComponentLabel in leveldb_key.mm.
  int64_t label = 5;  // TableName
  std::string key;
  for (const auto& segment : segments) {
    OrderedCode::WriteSignedNumIncreasing(&key, label);
    OrderedCode::WriteString(&key, segment);

    label = 62;  // PathSegment
  }

  OrderedCode::WriteSignedNumIncreasing(&key, 0);  // Terminator

  db->ptr()->Put(WriteOptions(), key, kDummy);
}

std::unique_ptr<Persistence> PersistenceFactory() {
  auto persistence = LevelDbPersistenceForTesting();

  WriteDummyRow(persistence.get(), {"remote_documentr", "foo", "bar"});
  WriteDummyRow(persistence.get(), {"remote_documentsa", "foo", "bar"});

  return std::move(persistence);
}

}  // namespace

INSTANTIATE_TEST_CASE_P(LevelDbRemoteDocumentCacheTest,
                        RemoteDocumentCacheTest,
                        testing::Values(PersistenceFactory));

}  // namespace local
}  // namespace firestore
}  // namespace firebase
