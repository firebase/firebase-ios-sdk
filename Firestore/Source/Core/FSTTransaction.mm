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

#import "Firestore/Source/Core/FSTTransaction.h"

#import <GRPCClient/GRPCCall.h>

#include <map>
#include <vector>

#import "FIRFirestoreErrors.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKeySet.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Remote/FSTDatastore.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::Precondition;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTTransaction

@interface FSTTransaction ()
@property(nonatomic, strong, readonly) FSTDatastore *datastore;
@property(nonatomic, strong, readonly) NSMutableArray *mutations;
@property(nonatomic, assign) BOOL commitCalled;
/**
 * An error that may have occurred as a consequence of a write. If set, needs to be raised in the
 * completion handler instead of trying to commit.
 */
@property(nonatomic, strong, nullable) NSError *lastWriteError;
@end

@implementation FSTTransaction {
  std::map<DocumentKey, FSTSnapshotVersion *> _readVersions;
}

+ (instancetype)transactionWithDatastore:(FSTDatastore *)datastore {
  return [[FSTTransaction alloc] initWithDatastore:datastore];
}

- (instancetype)initWithDatastore:(FSTDatastore *)datastore {
  self = [super init];
  if (self) {
    _datastore = datastore;
    _mutations = [NSMutableArray array];
    _commitCalled = NO;
  }
  return self;
}

/**
 * Every time a document is read, this should be called to record its version. If we read two
 * different versions of the same document, this will return an error through its out parameter.
 * When the transaction is committed, the versions recorded will be set as preconditions on the
 * writes sent to the backend.
 */
- (BOOL)recordVersionForDocument:(FSTMaybeDocument *)doc error:(NSError **)error {
  FSTAssert(error != nil, @"nil error parameter");
  *error = nil;
  FSTSnapshotVersion *docVersion = doc.version;
  if ([doc isKindOfClass:[FSTDeletedDocument class]]) {
    // For deleted docs, we must record an explicit no version to build the right precondition
    // when writing.
    docVersion = [FSTSnapshotVersion noVersion];
  }
  if (_readVersions.find(doc.key) == _readVersions.end()) {
    _readVersions[doc.key] = docVersion;
    return YES;
  } else {
    if (error) {
      *error =
          [NSError errorWithDomain:FIRFirestoreErrorDomain
                              code:FIRFirestoreErrorCodeFailedPrecondition
                          userInfo:@{
                            NSLocalizedDescriptionKey :
                                @"A document cannot be read twice within a single transaction."
                          }];
    }
    return NO;
  }
}

- (void)lookupDocumentsForKeys:(const std::vector<DocumentKey> &)keys
                    completion:(FSTVoidMaybeDocumentArrayErrorBlock)completion {
  [self ensureCommitNotCalled];
  if (self.mutations.count) {
    FSTThrowInvalidUsage(@"FIRIllegalStateException",
                         @"All reads in a transaction must be done before any writes.");
  }
  [self.datastore lookupDocuments:keys
                       completion:^(NSArray<FSTMaybeDocument *> *_Nullable documents,
                                    NSError *_Nullable error) {
                         if (error) {
                           completion(nil, error);
                           return;
                         }
                         for (FSTMaybeDocument *doc in documents) {
                           NSError *recordError = nil;
                           if (![self recordVersionForDocument:doc error:&recordError]) {
                             completion(nil, recordError);
                             return;
                           }
                         }
                         completion(documents, nil);
                       }];
}

/** Stores mutations to be written when commitWithCompletion is called. */
- (void)writeMutations:(NSArray<FSTMutation *> *)mutations {
  [self ensureCommitNotCalled];
  [self.mutations addObjectsFromArray:mutations];
}

/**
 * Returns version of this doc when it was read in this transaction as a precondition, or no
 * precondition if it was not read.
 */
- (Precondition)preconditionForDocumentKey:(const DocumentKey &)key {
  const auto iter = _readVersions.find(key);
  if (iter == _readVersions.end()) {
    return Precondition::None();
  } else {
    return Precondition::UpdateTime(iter->second);
  }
}

/**
 * Returns the precondition for a document if the operation is an update, based on the provided
 * UpdateOptions. Will return none precondition if an error occurred, in which case it sets the
 * error parameter.
 */
- (Precondition)preconditionForUpdateWithDocumentKey:(const DocumentKey &)key
                                               error:(NSError **)error {
  const auto iter = _readVersions.find(key);
  if (iter == _readVersions.end()) {
    // Document was not read, so we just use the preconditions for an update.
    return Precondition::Exists(true);
  }

  FSTSnapshotVersion *version = iter->second;
  if ([version isEqual:[FSTSnapshotVersion noVersion]]) {
    // The document was read, but doesn't exist.
    // Return an error because the precondition is impossible
    if (error) {
      *error = [NSError
          errorWithDomain:FIRFirestoreErrorDomain
                     code:FIRFirestoreErrorCodeAborted
                 userInfo:@{
                   NSLocalizedDescriptionKey : @"Can't update a document that doesn't exist."
                 }];
    }
    return Precondition::None();
  } else {
    // Document exists, just base precondition on document update time.
    return Precondition::UpdateTime(version);
  }
}

- (void)setData:(FSTParsedSetData *)data forDocument:(const DocumentKey &)key {
  [self writeMutations:[data mutationsWithKey:key
                                 precondition:[self preconditionForDocumentKey:key]]];
}

- (void)updateData:(FSTParsedUpdateData *)data forDocument:(const DocumentKey &)key {
  NSError *error = nil;
  const Precondition precondition = [self preconditionForUpdateWithDocumentKey:key error:&error];
  if (precondition.IsNone()) {
    FSTAssert(error, @"Got nil precondition, but error was not set");
    self.lastWriteError = error;
  } else {
    [self writeMutations:[data mutationsWithKey:key precondition:precondition]];
  }
}

- (void)deleteDocument:(const DocumentKey &)key {
  [self writeMutations:@[ [[FSTDeleteMutation alloc]
                            initWithKey:key
                           precondition:[self preconditionForDocumentKey:key]] ]];
  // Since the delete will be applied before all following writes, we need to ensure that the
  // precondition for the next write will be exists without timestamp.
  _readVersions[key] = [FSTSnapshotVersion noVersion];
}

- (void)commitWithCompletion:(FSTVoidErrorBlock)completion {
  [self ensureCommitNotCalled];
  // Once commitWithCompletion is called once, mark this object so it can't be used again.
  self.commitCalled = YES;

  // If there was an error writing, raise that error now
  if (self.lastWriteError) {
    completion(self.lastWriteError);
    return;
  }

  // Make a list of read documents that haven't been written.
  FSTDocumentKeySet *unwritten = [FSTDocumentKeySet keySet];
  for (const auto &kv : _readVersions) {
    unwritten = [unwritten setByAddingObject:kv.first];
  };
  // For each mutation, note that the doc was written.
  for (FSTMutation *mutation in self.mutations) {
    unwritten = [unwritten setByRemovingObject:mutation.key];
  }
  if (unwritten.count) {
    // TODO(klimt): This is a temporary restriction, until "verify" is supported on the backend.
    completion([NSError
        errorWithDomain:FIRFirestoreErrorDomain
                   code:FIRFirestoreErrorCodeFailedPrecondition
               userInfo:@{
                 NSLocalizedDescriptionKey : @"Every document read in a transaction must also be "
                                             @"written in that transaction."
               }]);
  } else {
    [self.datastore commitMutations:self.mutations
                         completion:^(NSError *_Nullable error) {
                           if (error) {
                             completion(error);
                           } else {
                             completion(nil);
                           }
                         }];
  }
}

- (void)ensureCommitNotCalled {
  if (self.commitCalled) {
    FSTThrowInvalidUsage(
        @"FIRIllegalStateException",
        @"A transaction object cannot be used after its update block has completed.");
  }
}

@end

NS_ASSUME_NONNULL_END
