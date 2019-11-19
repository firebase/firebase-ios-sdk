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

#include "Firestore/core/src/firebase/firestore/local/memory_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/reference_delegate.h"
#include "Firestore/core/test/firebase/firestore/local/persistence_testing.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::local::MemoryPersistenceWithEagerGcForTesting;
using firebase::firestore::local::Persistence;

/**
 * This tests the FSTLocalStore with an FSTMemoryPersistence persistence implementation. The tests
 * are in FSTLocalStoreTests and this class is merely responsible for creating a new Persistence
 * implementation on demand.
 */
@interface FSTMemoryLocalStoreTests : FSTLocalStoreTests
@end

@implementation FSTMemoryLocalStoreTests

- (std::unique_ptr<Persistence>)persistence {
  return MemoryPersistenceWithEagerGcForTesting();
}

- (BOOL)gcIsEager {
  return YES;
}

@end

NS_ASSUME_NONNULL_END
