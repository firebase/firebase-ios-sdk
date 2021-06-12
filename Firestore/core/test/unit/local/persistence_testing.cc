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

#include "Firestore/core/test/unit/local/persistence_testing.h"

#include <utility>

#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/local_serializer.h"
#include "Firestore/core/src/local/lru_garbage_collector.h"
#include "Firestore/core/src/local/memory_persistence.h"
#include "Firestore/core/src/local/proto_sizer.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/exception.h"
#include "Firestore/core/src/util/filesystem.h"
#include "Firestore/core/src/util/path.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/string_apple.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using model::DatabaseId;
using remote::Serializer;
using util::Filesystem;
using util::Path;
using util::Status;

}  // namespace

LocalSerializer MakeLocalSerializer() {
  Serializer remote_serializer{DatabaseId("p", "d")};
  return LocalSerializer(std::move(remote_serializer));
}

Path LevelDbDir() {
  auto* fs = Filesystem::Default();
  Path dir = fs->TempDir().AppendUtf8("PersistenceTesting");

  // Delete the directory first to ensure isolation between runs.
  Status status = fs->RecursivelyRemove(dir);
  if (!status.ok()) {
    util::ThrowIllegalState("Failed to clean up leveldb in dir %s: %s",
                            dir.ToUtf8String(), status.ToString());
  }

  return dir;
}

std::unique_ptr<LevelDbPersistence> LevelDbPersistenceForTesting(
    Path dir, LruParams lru_params) {
  auto created =
      LevelDbPersistence::Create(dir, MakeLocalSerializer(), lru_params);
  if (!created.ok()) {
    util::ThrowIllegalState("Failed to open leveldb in dir %s: %s",
                            dir.ToUtf8String(), created.status().ToString());
  }
  return std::move(created).ValueOrDie();
}

std::unique_ptr<LevelDbPersistence> LevelDbPersistenceForTesting(Path dir) {
  return LevelDbPersistenceForTesting(std::move(dir), LruParams::Default());
}

std::unique_ptr<LevelDbPersistence> LevelDbPersistenceForTesting(
    LruParams lru_params) {
  return LevelDbPersistenceForTesting(LevelDbDir(), lru_params);
}

std::unique_ptr<LevelDbPersistence> LevelDbPersistenceForTesting() {
  return LevelDbPersistenceForTesting(LevelDbDir());
}

std::unique_ptr<MemoryPersistence> MemoryPersistenceWithEagerGcForTesting() {
  return MemoryPersistence::WithEagerGarbageCollector();
}

std::unique_ptr<MemoryPersistence> MemoryPersistenceWithLruGcForTesting() {
  return MemoryPersistenceWithLruGcForTesting(LruParams::Default());
}

std::unique_ptr<MemoryPersistence> MemoryPersistenceWithLruGcForTesting(
    LruParams lru_params) {
  auto sizer = absl::make_unique<ProtoSizer>(MakeLocalSerializer());
  return MemoryPersistence::WithLruGarbageCollector(lru_params,
                                                    std::move(sizer));
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
