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

#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#import "Firestore/Source/Local/FSTMemoryPersistence.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"

#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/filesystem.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::util::Path;
using firebase::firestore::util::Status;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTPersistenceTestHelpers

+ (FSTLocalSerializer *)localSerializer {
  // This owns the DatabaseIds since we do not have FirestoreClient instance to own them.
  static DatabaseId database_id{"p", "d"};

  FSTSerializerBeta *remoteSerializer = [[FSTSerializerBeta alloc] initWithDatabaseID:&database_id];
  return [[FSTLocalSerializer alloc] initWithRemoteSerializer:remoteSerializer];
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

+ (FSTLevelDB *)levelDBPersistenceWithDir:(Path)dir {
  FSTLocalSerializer *serializer = [self localSerializer];
  FSTLevelDB *db = [[FSTLevelDB alloc] initWithDirectory:std::move(dir) serializer:serializer];
  Status status = [db start];
  if (!status.ok()) {
    [NSException raise:NSInternalInconsistencyException
                format:@"Failed to start leveldb persistence: %s", status.ToString().c_str()];
  }

  return db;
}

+ (FSTLevelDB *)levelDBPersistence {
  return [self levelDBPersistenceWithDir:[self levelDBDir]];
}

+ (FSTMemoryPersistence *)eagerGCMemoryPersistence {
  FSTMemoryPersistence *persistence = [FSTMemoryPersistence persistenceWithEagerGC];
  Status status = [persistence start];
  if (!status.ok()) {
    [NSException raise:NSInternalInconsistencyException
                format:@"Failed to start memory persistence: %s", status.ToString().c_str()];
  }

  return persistence;
}

+ (FSTMemoryPersistence *)lruMemoryPersistence {
  FSTLocalSerializer *serializer = [self localSerializer];
  FSTMemoryPersistence *persistence =
      [FSTMemoryPersistence persistenceWithLRUGCAndSerializer:serializer];
  Status status = [persistence start];
  if (!status.ok()) {
    [NSException raise:NSInternalInconsistencyException
                format:@"Failed to start memory persistence: %s", status.ToString().c_str()];
  }

  return persistence;
}

@end

NS_ASSUME_NONNULL_END
