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

#import "Firestore/Source/Model/FSTMutationBatch.h"

#include <utility>

#import "FIRTimestamp.h"

#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTMutation.h"

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

using firebase::firestore::model::BatchId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeyHash;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentVersionMap;
using firebase::firestore::model::SnapshotVersion;

NS_ASSUME_NONNULL_BEGIN

const BatchId kFSTBatchIDUnknown = -1;

@implementation FSTMutationBatch

- (instancetype)initWithBatchID:(BatchId)batchID
                 localWriteTime:(FIRTimestamp *)localWriteTime
                      mutations:(NSArray<FSTMutation *> *)mutations {
  self = [super init];
  if (self) {
    _batchID = batchID;
    _localWriteTime = localWriteTime;
    _mutations = mutations;
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (self == other) {
    return YES;
  } else if (![other isKindOfClass:[FSTMutationBatch class]]) {
    return NO;
  }

  FSTMutationBatch *otherBatch = (FSTMutationBatch *)other;
  return self.batchID == otherBatch.batchID &&
         [self.localWriteTime isEqual:otherBatch.localWriteTime] &&
         [self.mutations isEqual:otherBatch.mutations];
}

- (NSUInteger)hash {
  NSUInteger result = (NSUInteger)self.batchID;
  result = result * 31 + self.localWriteTime.hash;
  result = result * 31 + self.mutations.hash;
  return result;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTMutationBatch: id=%d, localWriteTime=%@, mutations=%@>",
                                    self.batchID, self.localWriteTime, self.mutations];
}

- (FSTMaybeDocument *_Nullable)applyToRemoteDocument:(FSTMaybeDocument *_Nullable)maybeDoc
                                         documentKey:(const DocumentKey &)documentKey
                                 mutationBatchResult:
                                     (FSTMutationBatchResult *_Nullable)mutationBatchResult {
  HARD_ASSERT(!maybeDoc || maybeDoc.key == documentKey,
              "applyTo: key %s doesn't match maybeDoc key %s", documentKey.ToString(),
              maybeDoc.key.ToString());

  HARD_ASSERT(mutationBatchResult.mutationResults.count == self.mutations.count,
              "Mismatch between mutations length (%s) and results length (%s)",
              self.mutations.count, mutationBatchResult.mutationResults.count);

  for (NSUInteger i = 0; i < self.mutations.count; i++) {
    FSTMutation *mutation = self.mutations[i];
    FSTMutationResult *mutationResult = mutationBatchResult.mutationResults[i];
    if (mutation.key == documentKey) {
      maybeDoc = [mutation applyToRemoteDocument:maybeDoc mutationResult:mutationResult];
    }
  }
  return maybeDoc;
}

- (FSTMaybeDocument *_Nullable)applyToLocalDocument:(FSTMaybeDocument *_Nullable)maybeDoc
                                        documentKey:(const DocumentKey &)documentKey {
  HARD_ASSERT(!maybeDoc || maybeDoc.key == documentKey,
              "applyTo: key %s doesn't match maybeDoc key %s", documentKey.ToString(),
              maybeDoc.key.ToString());
  FSTMaybeDocument *baseDoc = maybeDoc;

  for (NSUInteger i = 0; i < self.mutations.count; i++) {
    FSTMutation *mutation = self.mutations[i];
    if (mutation.key == documentKey) {
      maybeDoc = [mutation applyToLocalDocument:maybeDoc
                                   baseDocument:baseDoc
                                 localWriteTime:self.localWriteTime];
    }
  }
  return maybeDoc;
}

- (BOOL)isTombstone {
  return self.mutations.count == 0;
}

- (FSTMutationBatch *)toTombstone {
  return [[FSTMutationBatch alloc] initWithBatchID:self.batchID
                                    localWriteTime:self.localWriteTime
                                         mutations:@[]];
}

// TODO(klimt): This could use NSMutableDictionary instead.
- (DocumentKeySet)keys {
  DocumentKeySet set;
  for (FSTMutation *mutation in self.mutations) {
    set = set.insert(mutation.key);
  }
  return set;
}

@end

#pragma mark - FSTMutationBatchResult

@interface FSTMutationBatchResult ()
- (instancetype)initWithBatch:(FSTMutationBatch *)batch
                commitVersion:(SnapshotVersion)commitVersion
              mutationResults:(NSArray<FSTMutationResult *> *)mutationResults
                  streamToken:(nullable NSData *)streamToken
                  docVersions:(DocumentVersionMap)docVersions NS_DESIGNATED_INITIALIZER;
@end

@implementation FSTMutationBatchResult {
  SnapshotVersion _commitVersion;
  DocumentVersionMap _docVersions;
}

- (instancetype)initWithBatch:(FSTMutationBatch *)batch
                commitVersion:(SnapshotVersion)commitVersion
              mutationResults:(NSArray<FSTMutationResult *> *)mutationResults
                  streamToken:(nullable NSData *)streamToken
                  docVersions:(DocumentVersionMap)docVersions {
  if (self = [super init]) {
    _batch = batch;
    _commitVersion = std::move(commitVersion);
    _mutationResults = mutationResults;
    _streamToken = streamToken;
    _docVersions = std::move(docVersions);
  }
  return self;
}

- (const SnapshotVersion &)commitVersion {
  return _commitVersion;
}

- (const DocumentVersionMap &)docVersions {
  return _docVersions;
}

+ (instancetype)resultWithBatch:(FSTMutationBatch *)batch
                  commitVersion:(SnapshotVersion)commitVersion
                mutationResults:(NSArray<FSTMutationResult *> *)mutationResults
                    streamToken:(nullable NSData *)streamToken {
  HARD_ASSERT(batch.mutations.count == mutationResults.count,
              "Mutations sent %s must equal results received %s", batch.mutations.count,
              mutationResults.count);

  DocumentVersionMap docVersions;
  NSArray<FSTMutation *> *mutations = batch.mutations;
  for (NSUInteger i = 0; i < mutations.count; i++) {
    absl::optional<SnapshotVersion> version = mutationResults[i].version;
    if (!version) {
      // deletes don't have a version, so we substitute the commitVersion
      // of the entire batch.
      version = commitVersion;
    }

    docVersions[mutations[i].key] = version.value();
  }

  return [[FSTMutationBatchResult alloc] initWithBatch:batch
                                         commitVersion:std::move(commitVersion)
                                       mutationResults:mutationResults
                                           streamToken:streamToken
                                           docVersions:std::move(docVersions)];
}

@end
NS_ASSUME_NONNULL_END
