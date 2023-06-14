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

#import "Firestore/Example/Tests/SpecTests/FSTSpecTests.h"

#import "Firestore/Example/Tests/SpecTests/FSTSyncEngineTestDriver.h"

#include "Firestore/core/src/local/memory_persistence.h"
#include "Firestore/core/src/local/reference_delegate.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::local::MemoryPersistenceWithEagerGcForTesting;
using firebase::firestore::local::MemoryPersistenceWithLruGcForTesting;
using firebase::firestore::local::Persistence;

/**
 * An implementation of FSTSpecTests that uses the memory-only implementation of local storage.
 *
 * @see the FSTSpecTests class comments for more information about how this works.
 */
@interface FSTMemorySpecTests : FSTSpecTests
@end

@implementation FSTMemorySpecTests

/** Overrides -[FSTSpecTests persistence] */
- (std::unique_ptr<Persistence>)persistenceWithEagerGCForMemory:(BOOL)eagerGC {
  if (eagerGC) {
    return MemoryPersistenceWithEagerGcForTesting();
  } else {
    return MemoryPersistenceWithLruGcForTesting();
  }
}

- (BOOL)shouldRunWithTags:(NSArray<NSString *> *)tags {
  if ([tags containsObject:kDurablePersistence]) {
    return NO;
  }

  return [super shouldRunWithTags:tags];
}

@end

NS_ASSUME_NONNULL_END
