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

#import <Foundation/Foundation.h>

#include <memory>

#include "Firestore/core/src/firebase/firestore/util/path.h"

namespace firebase {
namespace firestore {
namespace local {

class LevelDbPersistence;
class LruParams;
class MemoryPersistence;

}  // namespace local
}  // namespace firestore
}  // namespace firebase

namespace local = firebase::firestore::local;

NS_ASSUME_NONNULL_BEGIN

@interface FSTPersistenceTestHelpers : NSObject

/**
 * @return The directory where a leveldb instance can store data files. Any files that existed
 * there will be deleted first.
 */
+ (firebase::firestore::util::Path)levelDBDir;

/**
 * Creates and starts a new FSTLevelDB instance for testing, destroying any previous contents
 * if they existed.
 *
 * Note that in order to avoid generating a bunch of garbage on the filesystem, the path of the
 * database is reused. This prevents concurrent running of tests using this database. We may
 * need to revisit this if we want to parallelize the tests.
 */
+ (std::unique_ptr<local::LevelDbPersistence>)levelDBPersistence;

/**
 * Creates and starts a new FSTLevelDB instance for testing. Does not delete any data
 * present in the given directory. As a consequence, the resulting databse is not guaranteed
 * to be empty.
 */
+ (std::unique_ptr<local::LevelDbPersistence>)levelDBPersistenceWithDir:
    (firebase::firestore::util::Path)dir;

/**
 * Creates and starts a new FSTLevelDB instance for testing, destroying any previous contents
 * if they existed.
 *
 * Sets up the LRU garbage collection to use the provided params.
 */
+ (std::unique_ptr<local::LevelDbPersistence>)levelDBPersistenceWithLruParams:
    (firebase::firestore::local::LruParams)lruParams;

/** Creates and starts a new MemoryPersistence instance for testing. */
+ (std::unique_ptr<local::MemoryPersistence>)eagerGCMemoryPersistence;

+ (std::unique_ptr<local::MemoryPersistence>)lruMemoryPersistence;

+ (std::unique_ptr<local::MemoryPersistence>)lruMemoryPersistenceWithLruParams:
    (firebase::firestore::local::LruParams)lruParams;
@end

NS_ASSUME_NONNULL_END
