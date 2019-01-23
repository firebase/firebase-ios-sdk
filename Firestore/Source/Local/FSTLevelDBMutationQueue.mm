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

#import "Firestore/Source/Local/FSTLevelDBMutationQueue.h"

#include <memory>
#include <set>
#include <string>
#include <utility>
#include <vector>

#import "Firestore/Protos/objc/firestore/local/Mutation.pbobjc.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_key.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_mutation_queue.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_util.h"
#include "Firestore/core/src/firebase/firestore/model/mutation_batch.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/src/firebase/firestore/util/string_util.h"
#include "absl/memory/memory.h"
#include "absl/strings/match.h"
#include "leveldb/db.h"
#include "leveldb/write_batch.h"

NS_ASSUME_NONNULL_BEGIN

namespace util = firebase::firestore::util;
using firebase::firestore::auth::User;
using firebase::firestore::local::DescribeKey;
using firebase::firestore::local::LevelDbDocumentMutationKey;
using firebase::firestore::local::LevelDbMutationKey;
using firebase::firestore::local::LevelDbMutationQueue;
using firebase::firestore::local::LevelDbMutationQueueKey;
using firebase::firestore::local::LevelDbTransaction;
using firebase::firestore::local::LoadNextBatchIdFromDb;
using firebase::firestore::local::MakeStringView;
using firebase::firestore::model::BatchId;
using firebase::firestore::model::kBatchIdUnknown;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::ResourcePath;
using leveldb::DB;
using leveldb::Iterator;
using leveldb::ReadOptions;
using leveldb::Slice;
using leveldb::Status;
using leveldb::WriteBatch;
using leveldb::WriteOptions;

static NSArray<FSTMutationBatch *> *toNSArray(const std::vector<FSTMutationBatch *> &vec) {
  NSMutableArray<FSTMutationBatch *> *copy = [NSMutableArray array];
  for (auto &batch : vec) {
    [copy addObject:batch];
  }
  return copy;
}

@interface FSTLevelDBMutationQueue ()

- (instancetype)initWithUserID:(std::string)userID
                            db:(FSTLevelDB *)db
                    serializer:(FSTLocalSerializer *)serializer
                      delegate:(std::unique_ptr<LevelDbMutationQueue>)delegate
    NS_DESIGNATED_INITIALIZER;

@end

@implementation FSTLevelDBMutationQueue {
  // This instance is owned by FSTLevelDB; avoid a retain cycle.
  //__weak FSTLevelDB *_db;

  /** The normalized userID (e.g. nil UID => @"" userID) used in our LevelDB keys. */
  // std::string _userID;

  std::unique_ptr<LevelDbMutationQueue> _delegate;
}

+ (instancetype)mutationQueueWithUser:(const User &)user
                                   db:(FSTLevelDB *)db
                           serializer:(FSTLocalSerializer *)serializer {
  std::string userID = user.is_authenticated() ? user.uid() : "";

  return [[FSTLevelDBMutationQueue alloc]
      initWithUserID:std::move(userID)
                  db:db
          serializer:serializer
            delegate:absl::make_unique<LevelDbMutationQueue>(user, db, serializer)];
}

- (instancetype)initWithUserID:(std::string)userID
                            db:(FSTLevelDB *)db
                    serializer:(FSTLocalSerializer *)serializer
                      delegate:(std::unique_ptr<LevelDbMutationQueue>)delegate {
  if (self = [super init]) {
    _delegate = std::move(delegate);
  }
  return self;
}

- (void)start {
  _delegate->Start();
}

- (BOOL)isEmpty {
  return _delegate->IsEmpty();
}

- (void)acknowledgeBatch:(FSTMutationBatch *)batch streamToken:(nullable NSData *)streamToken {
  _delegate->AcknowledgeBatch(batch, streamToken);
}

- (nullable NSData *)lastStreamToken {
  return _delegate->GetLastStreamToken();
}

- (void)setLastStreamToken:(nullable NSData *)streamToken {
  _delegate->SetLastStreamToken(streamToken);
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

- (NSArray<FSTMutationBatch *> *)allMutationBatches {
  return toNSArray(_delegate->AllMutationBatches());
}

- (void)removeMutationBatch:(FSTMutationBatch *)batch {
  _delegate->RemoveMutationBatch(batch);
}

- (void)performConsistencyCheck {
  _delegate->PerformConsistencyCheck();
}

@end

NS_ASSUME_NONNULL_END
