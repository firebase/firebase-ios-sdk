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

#include <algorithm>
#include <utility>

#import "FIRTimestamp.h"

#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTMutation.h"

#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"
#include "Firestore/core/src/firebase/firestore/util/objc_compatibility.h"

namespace objc = firebase::firestore::util::objc;
using firebase::firestore::model::BatchId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeyHash;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentVersionMap;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::util::Hash;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTMutationBatch {
  std::vector<FSTMutation *> _baseMutations;
  std::vector<FSTMutation *> _mutations;
}

- (instancetype)initWithBatchID:(BatchId)batchID
                 localWriteTime:(FIRTimestamp *)localWriteTime
                  baseMutations:(std::vector<FSTMutation *> &&)baseMutations
                      mutations:(std::vector<FSTMutation *> &&)mutations {
  HARD_ASSERT(!mutations.empty(), "Cannot create an empty mutation batch");
  self = [super init];
  if (self) {
    _batchID = batchID;
    _localWriteTime = localWriteTime;
    _baseMutations = std::move(baseMutations);
    _mutations = std::move(mutations);
  }
  return self;
}

- (const std::vector<FSTMutation *> &)baseMutations {
  return _baseMutations;
}

- (const std::vector<FSTMutation *> &)mutations {
  return _mutations;
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
         objc::Equals(_baseMutations, otherBatch.baseMutations) &&
         objc::Equals(_mutations, otherBatch.mutations);
}

- (NSUInteger)hash {
  NSUInteger result = (NSUInteger)self.batchID;
  result = result * 31 + self.localWriteTime.hash;
  for (FSTMutation *mutation : _baseMutations) {
    result = result * 31 + [mutation hash];
  }
  for (FSTMutation *mutation : _mutations) {
    result = result * 31 + [mutation hash];
  }
  return result;
}

- (NSString *)description {
  return
      [NSString stringWithFormat:@"<FSTMutationBatch: id=%d, localWriteTime=%@, mutations=%@>",
                                 self.batchID, self.localWriteTime, objc::Description(_mutations)];
}

- (FSTMaybeDocument *_Nullable)applyToRemoteDocument:(FSTMaybeDocument *_Nullable)maybeDoc
                                         documentKey:(const DocumentKey &)documentKey
                                 mutationBatchResult:
                                     (FSTMutationBatchResult *_Nullable)mutationBatchResult {
  HARD_ASSERT(!maybeDoc || maybeDoc.key == documentKey,
              "applyTo: key %s doesn't match maybeDoc key %s", documentKey.ToString(),
              maybeDoc.key.ToString());

  HARD_ASSERT(mutationBatchResult.mutationResults.size() == _mutations.size(),
              "Mismatch between mutations length (%s) and results length (%s)", _mutations.size(),
              mutationBatchResult.mutationResults.size());

  for (size_t i = 0; i < _mutations.size(); i++) {
    FSTMutation *mutation = _mutations[i];
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

  // First, apply the base state. This allows us to apply non-idempotent transform against a
  // consistent set of values.
  for (FSTMutation *mutation : _baseMutations) {
    if (mutation.key == documentKey) {
      maybeDoc = [mutation applyToLocalDocument:maybeDoc
                                   baseDocument:maybeDoc
                                 localWriteTime:self.localWriteTime];
    }
  }

  FSTMaybeDocument *baseDoc = maybeDoc;

  // Second, apply all user-provided mutations.
  for (FSTMutation *mutation : _mutations) {
    if (mutation.key == documentKey) {
      maybeDoc = [mutation applyToLocalDocument:maybeDoc
                                   baseDocument:baseDoc
                                 localWriteTime:self.localWriteTime];
    }
  }
  return maybeDoc;
}

- (MaybeDocumentMap)applyToLocalDocumentSet:(const MaybeDocumentMap &)documentSet {
  // TODO(mrschmidt): This implementation is O(n^2). If we iterate through the mutations first (as
  // done in `applyToLocalDocument:documentKey:`), we can reduce the complexity to O(n).

  MaybeDocumentMap mutatedDocuments = documentSet;
  for (FSTMutation *mutation : _mutations) {
    const DocumentKey &key = mutation.key;
    auto maybeDocument = mutatedDocuments.find(key);
    FSTMaybeDocument *mutatedDocument = [self
        applyToLocalDocument:(maybeDocument != mutatedDocuments.end() ? maybeDocument->second : nil)
                 documentKey:key];
    if (mutatedDocument) {
      mutatedDocuments = mutatedDocuments.insert(key, mutatedDocument);
    }
  }
  return mutatedDocuments;
}

- (DocumentKeySet)keys {
  DocumentKeySet set;
  for (FSTMutation *mutation : _mutations) {
    set = set.insert(mutation.key);
  }
  return set;
}

@end

#pragma mark - FSTMutationBatchResult

@interface FSTMutationBatchResult ()
- (instancetype)initWithBatch:(FSTMutationBatch *)batch
                commitVersion:(SnapshotVersion)commitVersion
              mutationResults:(std::vector<FSTMutationResult *>)mutationResults
                  streamToken:(nullable NSData *)streamToken
                  docVersions:(DocumentVersionMap)docVersions NS_DESIGNATED_INITIALIZER;
@end

@implementation FSTMutationBatchResult {
  SnapshotVersion _commitVersion;
  std::vector<FSTMutationResult *> _mutationResults;
  DocumentVersionMap _docVersions;
}

- (instancetype)initWithBatch:(FSTMutationBatch *)batch
                commitVersion:(SnapshotVersion)commitVersion
              mutationResults:(std::vector<FSTMutationResult *>)mutationResults
                  streamToken:(nullable NSData *)streamToken
                  docVersions:(DocumentVersionMap)docVersions {
  if (self = [super init]) {
    _batch = batch;
    _commitVersion = std::move(commitVersion);
    _mutationResults = std::move(mutationResults);
    _streamToken = streamToken;
    _docVersions = std::move(docVersions);
  }
  return self;
}

- (const SnapshotVersion &)commitVersion {
  return _commitVersion;
}

- (const std::vector<FSTMutationResult *> &)mutationResults {
  return _mutationResults;
}

- (const DocumentVersionMap &)docVersions {
  return _docVersions;
}

+ (instancetype)resultWithBatch:(FSTMutationBatch *)batch
                  commitVersion:(SnapshotVersion)commitVersion
                mutationResults:(std::vector<FSTMutationResult *>)mutationResults
                    streamToken:(nullable NSData *)streamToken {
  HARD_ASSERT(batch.mutations.size() == mutationResults.size(),
              "Mutations sent %s must equal results received %s", batch.mutations.size(),
              mutationResults.size());

  DocumentVersionMap docVersions;
  std::vector<FSTMutation *> mutations = batch.mutations;
  for (size_t i = 0; i < mutations.size(); i++) {
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
                                       mutationResults:std::move(mutationResults)
                                           streamToken:streamToken
                                           docVersions:std::move(docVersions)];
}

@end
NS_ASSUME_NONNULL_END
