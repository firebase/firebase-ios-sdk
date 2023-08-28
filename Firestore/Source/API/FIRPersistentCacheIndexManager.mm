/*
 * Copyright 2023 Google LLC
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

#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRPersistentCacheIndexManager+Internal.h"

using firebase::firestore::api::Firestore;
using firebase::firestore::api::PersistentCacheIndexManager;

NS_ASSUME_NONNULL_BEGIN

@implementation FIRPersistentCacheIndexManager {
  /** The `Firestore` instance that created this index manager. */
  std::shared_ptr<const PersistentCacheIndexManager> _indexManager;
}

- (instancetype)initWithPersistentCacheIndexManager:
    (std::shared_ptr<const PersistentCacheIndexManager>)indexManager {
  if (self = [super init]) {
    _indexManager = indexManager;
  }
  return self;
}

- (void)enableIndexAutoCreation {
  _indexManager->EnableIndexAutoCreation();
}

- (void)disableIndexAutoCreation {
  _indexManager->DisableIndexAutoCreation();
}

- (void)deleteAllIndexes {
  _indexManager->DeleteAllFieldIndexes();
}

@end

NS_ASSUME_NONNULL_END
