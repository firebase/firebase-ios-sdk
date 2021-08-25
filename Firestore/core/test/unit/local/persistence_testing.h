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

#ifndef FIRESTORE_CORE_TEST_UNIT_LOCAL_PERSISTENCE_TESTING_H_
#define FIRESTORE_CORE_TEST_UNIT_LOCAL_PERSISTENCE_TESTING_H_

#include <memory>

#include "Firestore/core/src/local/local_serializer.h"

namespace firebase {
namespace firestore {
namespace util {

class Path;

}  // namespace util

namespace local {

class LevelDbPersistence;
struct LruParams;
class MemoryPersistence;

/**
 * Returns a new instance of local serializer using the default testing
 * database.
 */
local::LocalSerializer MakeLocalSerializer();

/**
 * Returns the directory where a LevelDB instance can store data files during
 * testing. Any files that existed there will be deleted first.
 */
util::Path LevelDbDir();

/**
 * Creates and starts a new LevelDbPersistence instance for testing, destroying
 * any previous contents if they existed.
 *
 * Note that in order to avoid generating a bunch of garbage on the filesystem,
 * the path of the database is reused. This prevents concurrent running of tests
 * using this database. We may need to revisit this if we want to parallelize
 * the tests.
 */
std::unique_ptr<LevelDbPersistence> LevelDbPersistenceForTesting();

/**
 * Creates and starts a new LevelDbPersistence instance for testing. Does not
 * delete any data present in the given directory. As a consequence, the
 * resulting database is not guaranteed to be empty.
 */
std::unique_ptr<LevelDbPersistence> LevelDbPersistenceForTesting(
    util::Path dir);

/**
 * Creates and starts a new LevelDbPersistence instance for testing, destroying
 * any previous contents if they existed.
 *
 * Sets up the LRU garbage collection to use the provided params.
 */
std::unique_ptr<LevelDbPersistence> LevelDbPersistenceForTesting(
    LruParams lru_params);

/** Creates and starts a new MemoryPersistence instance for testing. */
std::unique_ptr<MemoryPersistence> MemoryPersistenceWithEagerGcForTesting();

std::unique_ptr<MemoryPersistence> MemoryPersistenceWithLruGcForTesting();

std::unique_ptr<MemoryPersistence> MemoryPersistenceWithLruGcForTesting(
    LruParams lru_params);

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_LOCAL_PERSISTENCE_TESTING_H_
