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

#import "Firestore/Source/Local/FSTRemoteDocumentCache.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Util/FSTAssert.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTRemoteDocumentChangeBuffer ()

- (instancetype)initWithCache:(id<FSTRemoteDocumentCache>)cache;

/** The underlying cache we're buffering changes for. */
@property(nonatomic, strong, nonnull) id<FSTRemoteDocumentCache> remoteDocumentCache;

/** The buffered changes, stored as a dictionary for easy lookups. */
@property(nonatomic, strong, nullable)
    NSMutableDictionary<FSTDocumentKey *, FSTMaybeDocument *> *changes;

@end

@implementation FSTRemoteDocumentChangeBuffer

+ (instancetype)changeBufferWithCache:(id<FSTRemoteDocumentCache>)cache {
  return [[FSTRemoteDocumentChangeBuffer alloc] initWithCache:cache];
}

- (instancetype)initWithCache:(id<FSTRemoteDocumentCache>)cache {
  if (self = [super init]) {
    _remoteDocumentCache = cache;
    _changes = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)addEntry:(FSTMaybeDocument *)maybeDocument {
  [self assertValid];

  self.changes[(FSTDocumentKey *)maybeDocument.key] = maybeDocument;
}

- (nullable FSTMaybeDocument *)entryForKey:(FSTDocumentKey *)documentKey {
  [self assertValid];

  FSTMaybeDocument *bufferedEntry = self.changes[documentKey];
  if (bufferedEntry) {
    return bufferedEntry;
  } else {
    return [self.remoteDocumentCache entryForKey:documentKey];
  }
}

- (void)applyToWriteGroup:(FSTWriteGroup *)group {
  [self assertValid];

  [self.changes enumerateKeysAndObjectsUsingBlock:^(FSTDocumentKey *key, FSTMaybeDocument *value,
                                                    BOOL *stop) {
    [self.remoteDocumentCache addEntry:value group:group];
  }];

  // We should not be used to buffer any more changes.
  self.changes = nil;
}

- (void)assertValid {
  FSTAssert(self.changes, @"Changes have already been applied.");
}

@end

NS_ASSUME_NONNULL_END
