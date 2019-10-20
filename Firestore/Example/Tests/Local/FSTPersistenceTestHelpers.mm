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

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"

#include <utility>

#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/lru_garbage_collector.h"
#include "Firestore/core/src/firebase/firestore/local/memory_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/proto_sizer.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/filesystem.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::local::LevelDbPersistence;
using firebase::firestore::local::LruParams;
using firebase::firestore::local::LocalSerializer;
using firebase::firestore::local::MemoryPersistence;
using firebase::firestore::local::ProtoSizer;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::remote::Serializer;
using firebase::firestore::util::Path;
using firebase::firestore::util::Status;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTPersistenceTestHelpers

+ (LocalSerializer)localSerializer {
  Serializer remoteSerializer{DatabaseId("p", "d")};
  return LocalSerializer{std::move(remoteSerializer)};
}

+ (Path)levelDBDir {
  Path dir = util::TempDir().AppendUtf8("FSTPersistenceTestHelpers");

  // Delete the directory first to ensure isolation between runs.
  util::Status status = util::RecursivelyDelete(dir);
  if (!status.ok()) {
    [NSException
         raise:NSInternalInconsistencyException
        format:@"Failed to clean up leveldb path %s: %s", dir.c_str(), status.ToString().c_str()];
  }

  return dir;
}

+ (std::unique_ptr<LevelDbPersistence>)levelDBPersistenceWithDir:(Path)dir {
  return [self levelDBPersistenceWithDir:dir lruParams:LruParams::Default()];
}

+ (std::unique_ptr<LevelDbPersistence>)levelDBPersistenceWithDir:(Path)dir
                                                       lruParams:(LruParams)params {
  auto created = LevelDbPersistence::Create(std::move(dir), self.localSerializer, params);
  if (!created.ok()) {
    [NSException raise:NSInternalInconsistencyException
                format:@"Failed to open DB: %s", created.status().ToString().c_str()];
  }
  return std::move(created).ValueOrDie();
}

+ (std::unique_ptr<local::LevelDbPersistence>)levelDBPersistenceWithLruParams:(LruParams)lruParams {
  return [self levelDBPersistenceWithDir:[self levelDBDir] lruParams:lruParams];
}

+ (std::unique_ptr<local::LevelDbPersistence>)levelDBPersistence {
  return [self levelDBPersistenceWithDir:[self levelDBDir]];
}

+ (std::unique_ptr<local::MemoryPersistence>)eagerGCMemoryPersistence {
  return MemoryPersistence::WithEagerGarbageCollector();
}

+ (std::unique_ptr<local::MemoryPersistence>)lruMemoryPersistence {
  return [self lruMemoryPersistenceWithLruParams:LruParams::Default()];
}

+ (std::unique_ptr<local::MemoryPersistence>)lruMemoryPersistenceWithLruParams:
    (LruParams)lruParams {
  auto sizer = absl::make_unique<ProtoSizer>(self.localSerializer);
  return MemoryPersistence::WithLruGarbageCollector(lruParams, std::move(sizer));
}

@end

NS_ASSUME_NONNULL_END
