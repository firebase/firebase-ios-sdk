/*
 * Copyright 2018 Google
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

#import "Firestore/Example/Tests/Local/FSTLRUGarbageCollectorTests.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"
#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"
#import "Firestore/Source/Local/FSTMemoryPersistence.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"

using firebase::firestore::model::DocumentKey;

using firebase::firestore::local::LruParams;

NS_ASSUME_NONNULL_BEGIN

@interface FSTMemoryLRUGarbageCollectionTests : FSTLRUGarbageCollectorTests
@end

@implementation FSTMemoryLRUGarbageCollectionTests

- (id<FSTPersistence>)newPersistenceWithLruParams:(LruParams)lruParams {
  return [FSTPersistenceTestHelpers lruMemoryPersistenceWithLruParams:lruParams];
}

- (BOOL)sentinelExists:(const DocumentKey &)key {
  FSTMemoryLRUReferenceDelegate *delegate =
      (FSTMemoryLRUReferenceDelegate *)self.persistence.referenceDelegate;
  return [delegate isPinnedAtSequenceNumber:0 document:key];
}

@end

NS_ASSUME_NONNULL_END