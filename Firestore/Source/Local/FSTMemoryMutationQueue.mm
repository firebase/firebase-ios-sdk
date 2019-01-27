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

#import "Firestore/Source/Local/FSTMemoryMutationQueue.h"

#import <Protobuf/GPBProtocolBuffers.h>

#include <memory>
#include <vector>

#import "Firestore/Protos/objc/firestore/local/Mutation.pbobjc.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTMemoryPersistence.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"

#include "Firestore/core/src/firebase/firestore/immutable/sorted_set.h"
#include "Firestore/core/src/firebase/firestore/local/document_reference.h"
#include "Firestore/core/src/firebase/firestore/local/memory_mutation_queue.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/memory/memory.h"

using firebase::firestore::immutable::SortedSet;
using firebase::firestore::local::DocumentReference;
using firebase::firestore::local::MemoryMutationQueue;
using firebase::firestore::model::BatchId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::ResourcePath;

NS_ASSUME_NONNULL_BEGIN

static NSArray<FSTMutationBatch *> *toNSArray(const std::vector<FSTMutationBatch *> &vec) {
  NSMutableArray<FSTMutationBatch *> *copy = [NSMutableArray array];
  for (auto &batch : vec) {
    [copy addObject:batch];
  }
  return copy;
}

@implementation FSTMemoryMutationQueue {
  std::unique_ptr<MemoryMutationQueue> _delegate;
}

- (instancetype)initWithPersistence:(FSTMemoryPersistence *)persistence {
  if (self = [super init]) {
    _delegate = absl::make_unique<MemoryMutationQueue>(persistence);
  }
  return self;
}

- (void)setLastStreamToken:(NSData *_Nullable)streamToken {
  _delegate->SetLastStreamToken(streamToken);
}

- (NSData *_Nullable)lastStreamToken {
  return _delegate->GetLastStreamToken();
}

#pragma mark - FSTMutationQueue implementation

- (void)start {
  _delegate->Start();
}

- (BOOL)isEmpty {
  return _delegate->IsEmpty();
}

- (void)acknowledgeBatch:(FSTMutationBatch *)batch streamToken:(nullable NSData *)streamToken {
  _delegate->AcknowledgeBatch(batch, streamToken);
}

- (FSTMutationBatch *)addMutationBatchWithWriteTime:(FIRTimestamp *)localWriteTime
                                          mutations:(NSArray<FSTMutation *> *)mutations {
  return _delegate->AddMutationBatch(localWriteTime, mutations);
}

- (nullable FSTMutationBatch *)lookupMutationBatch:(BatchId)batchID {
  return _delegate->LookupMutationBatch(batchID);
}

- (nullable FSTMutationBatch *)nextMutationBatchAfterBatchID:(BatchId)batchID {
  return _delegate->NextMutationBatchAfterBatchId(batchID);
}

- (NSArray<FSTMutationBatch *> *)allMutationBatches {
  return toNSArray(_delegate->AllMutationBatches());
}

- (NSArray<FSTMutationBatch *> *)allMutationBatchesAffectingDocumentKey:
    (const DocumentKey &)documentKey {
  return toNSArray(_delegate->AllMutationBatchesAffectingDocumentKey(documentKey));
}

- (NSArray<FSTMutationBatch *> *)allMutationBatchesAffectingDocumentKeys:
    (const DocumentKeySet &)documentKeys {
  return toNSArray(_delegate->AllMutationBatchesAffectingDocumentKeys(documentKeys));
}

- (NSArray<FSTMutationBatch *> *)allMutationBatchesAffectingQuery:(FSTQuery *)query {
  return toNSArray(_delegate->AllMutationBatchesAffectingQuery(query));
}

- (void)removeMutationBatch:(FSTMutationBatch *)batch {
  _delegate->RemoveMutationBatch(batch);
}

- (void)performConsistencyCheck {
  _delegate->PerformConsistencyCheck();
}

#pragma mark - FSTGarbageSource implementation

- (BOOL)containsKey:(const DocumentKey &)key {
  return _delegate->ContainsKey(key);
}

#pragma mark - Helpers

- (size_t)byteSizeWithSerializer:(FSTLocalSerializer *)serializer {
  return _delegate->CalculateByteSize(serializer);
}

@end

NS_ASSUME_NONNULL_END
