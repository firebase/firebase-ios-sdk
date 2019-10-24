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

#import "Firestore/Example/Tests/Local/FSTLocalStoreTests.h"

#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"
#include "Firestore/core/test/firebase/firestore/local/persistence_testing.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::local::LevelDbPersistenceForTesting;
using firebase::firestore::local::Persistence;

/**
 * The tests for FSTLevelDBLocalStore are performed on the FSTLocalStore protocol in
 * FSTLocalStoreTests. This class is merely responsible for creating a new Persistence
 * implementation on demand.
 */
@interface FSTLevelDBLocalStoreTests : FSTLocalStoreTests
@end

@implementation FSTLevelDBLocalStoreTests

- (std::unique_ptr<Persistence>)persistence {
  return LevelDbPersistenceForTesting();
}

- (BOOL)gcIsEager {
  return NO;
}

@end

NS_ASSUME_NONNULL_END
