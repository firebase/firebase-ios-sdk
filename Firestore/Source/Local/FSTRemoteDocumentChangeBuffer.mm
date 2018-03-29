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

#import "Firestore/Source/Local/FSTRemoteDocumentChangeBuffer.h"

#include <map>
#include <memory>

#import "Firestore/Source/Local/FSTRemoteDocumentCache.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Util/FSTAssert.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "absl/memory/memory.h"

using firebase::firestore::model::DocumentKey;

NS_ASSUME_NONNULL_BEGIN

@interface FSTRemoteDocumentChangeBuffer ()

- (instancetype)initWithCache:(id<FSTRemoteDocumentCache>)cache;

/** The underlying cache we're buffering changes for. */
@property(nonatomic, strong, nonnull) id<FSTRemoteDocumentCache> remoteDocumentCache;

@end

@implementation FSTRemoteDocumentChangeBuffer {
  /** The buffered changes, stored as a dictionary for easy lookups. */
  std::unique_ptr<std::map<DocumentKey, FSTMaybeDocument *>> _changes;
}

+ (instancetype)changeBufferWithCache:(id<FSTRemoteDocumentCache>)cache {
  return [[FSTRemoteDocumentChangeBuffer alloc] initWithCache:cache];
}

- (instancetype)initWithCache:(id<FSTRemoteDocumentCache>)cache {
  if (self = [super init]) {
    _remoteDocumentCache = cache;
    _changes = absl::make_unique<std::map<DocumentKey, FSTMaybeDocument *>>();
  }
  return self;
}

- (void)addEntry:(FSTMaybeDocument *)maybeDocument {
  [self assertValid];

  (*_changes)[maybeDocument.key] = maybeDocument;
}

- (nullable FSTMaybeDocument *)entryForKey:(const DocumentKey &)documentKey {
  [self assertValid];

  const auto iter = _changes->find(documentKey);
  if (iter == _changes->end()) {
    return [self.remoteDocumentCache entryForKey:documentKey];
  } else {
    return iter->second;
  }
}

- (void)applyToWriteGroup:(FSTWriteGroup *)group {
  [self assertValid];

  for (const auto &kv : *_changes) {
    [self.remoteDocumentCache addEntry:kv.second];
  }

  // We should not be used to buffer any more changes.
  _changes.reset();
}

- (void)assertValid {
  FSTAssert(_changes, @"Changes have already been applied.");
}

@end

NS_ASSUME_NONNULL_END
