/*
 * Copyright 2024 Google LLC
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

#include "Firestore/core/src/local/leveldb_globals_cache.h"
#include "Firestore/core/src/local/leveldb_key.h"
#include "Firestore/core/src/local/leveldb_persistence.h"

namespace firebase {
namespace firestore {
namespace local {

namespace {

const char* kSessionToken = "session_token";

}

LevelDbGlobalsCache::LevelDbGlobalsCache(LevelDbPersistence* db)
    : db_(NOT_NULL(db)) {
}

ByteString LevelDbGlobalsCache::GetSessionToken() const {
  auto key = LevelDbGlobalKey::Key(kSessionToken);

  std::string encoded;
  auto done = db_->current_transaction()->Get(key, &encoded);

  if (!done.ok()) {
    return ByteString();
  }

  return ByteString(encoded);
}

void LevelDbGlobalsCache::SetSessionToken(const ByteString& session_token) {
  auto key = LevelDbGlobalKey::Key(kSessionToken);
  db_->current_transaction()->Put(key, session_token.ToString());
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
