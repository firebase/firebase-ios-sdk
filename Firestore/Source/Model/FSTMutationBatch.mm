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

#import "FIRTimestamp.h"

#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Util/FSTAssert.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

using firebase::firestore::model::DocumentKey;

NS_ASSUME_NONNULL_BEGIN

const FSTBatchID kFSTBatchIDUnknown = -1;

@implementation FSTMutationBatch

- (instancetype)initWithBatchID:(FSTBatchID)batchID
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

- (FSTMaybeDocument *_Nullable)applyTo:(FSTMaybeDocument *_Nullable)maybeDoc
                           documentKey:(const DocumentKey &)documentKey
                   mutationBatchResult:(FSTMutationBatchResult *_Nullable)mutationBatchResult {
  FSTAssert(!maybeDoc || [maybeDoc.key isEqualToKey:documentKey],
            @"applyTo: key %s doesn't match maybeDoc key %s", documentKey.ToString().c_str(),
            maybeDoc.key.ToString().c_str());
  FSTMaybeDocument *baseDoc = maybeDoc;
  if (mutationBatchResult) {
    FSTAssert(mutationBatchResult.mutationResults.count == self.mutations.count,
              @"Mismatch between mutations length (%lu) and results length (%lu)",
              (unsigned long)self.mutations.count,
              (unsigned long)mutationBatchResult.mutationResults.count);
  }

  for (NSUInteger i = 0; i < self.mutations.count; i++) {
    FSTMutation *mutation = self.mutations[i];
    FSTMutationResult *_Nullable mutationResult = mutationBatchResult.mutationResults[i];
    if ([mutation.key isEqualToKey:documentKey]) {
      maybeDoc = [mutation applyTo:maybeDoc
                      baseDocument:baseDoc
                    localWriteTime:self.localWriteTime
                    mutationResult:mutationResult];
    }
  }
  return maybeDoc;
}

- (FSTMaybeDocument *_Nullable)applyTo:(FSTMaybeDocument *_Nullable)maybeDoc
                           documentKey:(const DocumentKey &)documentKey {
  return [self applyTo:maybeDoc documentKey:documentKey mutationBatchResult:nil];
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
- (FSTDocumentKeySet *)keys {
  FSTDocumentKeySet *set = [FSTDocumentKeySet keySet];
  for (FSTMutation *mutation in self.mutations) {
    set = [set setByAddingObject:mutation.key];
  }
  return set;
}

@end

#pragma mark - FSTMutationBatchResult

@interface FSTMutationBatchResult ()
- (instancetype)initWithBatch:(FSTMutationBatch *)batch
                commitVersion:(FSTSnapshotVersion *)commitVersion
              mutationResults:(NSArray<FSTMutationResult *> *)mutationResults
                  streamToken:(nullable NSData *)streamToken
                  docVersions:(FSTDocumentVersionDictionary *)docVersions NS_DESIGNATED_INITIALIZER;
@end

@implementation FSTMutationBatchResult

- (instancetype)initWithBatch:(FSTMutationBatch *)batch
                commitVersion:(FSTSnapshotVersion *)commitVersion
              mutationResults:(NSArray<FSTMutationResult *> *)mutationResults
                  streamToken:(nullable NSData *)streamToken
                  docVersions:(FSTDocumentVersionDictionary *)docVersions {
  if (self = [super init]) {
    _batch = batch;
    _commitVersion = commitVersion;
    _mutationResults = mutationResults;
    _streamToken = streamToken;
    _docVersions = docVersions;
  }
  return self;
}

+ (instancetype)resultWithBatch:(FSTMutationBatch *)batch
                  commitVersion:(FSTSnapshotVersion *)commitVersion
                mutationResults:(NSArray<FSTMutationResult *> *)mutationResults
                    streamToken:(nullable NSData *)streamToken {
  FSTAssert(batch.mutations.count == mutationResults.count,
            @"Mutations sent %lu must equal results received %lu",
            (unsigned long)batch.mutations.count, (unsigned long)mutationResults.count);

  FSTDocumentVersionDictionary *docVersions =
      [FSTDocumentVersionDictionary documentVersionDictionary];
  NSArray<FSTMutation *> *mutations = batch.mutations;
  for (NSUInteger i = 0; i < mutations.count; i++) {
    FSTSnapshotVersion *_Nullable version = mutationResults[i].version;
    if (!version) {
      // deletes don't have a version, so we substitute the commitVersion
      // of the entire batch.
      version = commitVersion;
    }

    docVersions = [docVersions dictionaryBySettingObject:version forKey:mutations[i].key];
  }

  return [[FSTMutationBatchResult alloc] initWithBatch:batch
                                         commitVersion:commitVersion
                                       mutationResults:mutationResults
                                           streamToken:streamToken
                                           docVersions:docVersions];
}

@end
NS_ASSUME_NONNULL_END
