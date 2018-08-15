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
#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_util.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/src/firebase/firestore/util/string_util.h"
#include "absl/strings/match.h"
#include "leveldb/db.h"
#include "leveldb/write_batch.h"

NS_ASSUME_NONNULL_BEGIN

namespace util = firebase::firestore::util;
using firebase::firestore::auth::User;
using firebase::firestore::local::DescribeKey;
using firebase::firestore::local::LevelDbDocumentMutationKey;
using firebase::firestore::local::LevelDbMutationKey;
using firebase::firestore::local::LevelDbMutationQueueKey;
using firebase::firestore::local::LevelDbTransaction;
using firebase::firestore::local::MakeStringView;
using firebase::firestore::model::BatchId;
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

@interface FSTLevelDBMutationQueue ()

- (instancetype)initWithUserID:(std::string)userID
                            db:(FSTLevelDB *)db
                    serializer:(FSTLocalSerializer *)serializer NS_DESIGNATED_INITIALIZER;

/**
 * Next value to use when assigning sequential IDs to each mutation batch.
 *
 * NOTE: There can only be one FSTLevelDBMutationQueue for a given db at a time, hence it is safe
 * to track nextBatchID as an instance-level property. Should we ever relax this constraint we'll
 * need to revisit this.
 */
@property(nonatomic, assign) BatchId nextBatchID;

/** A write-through cache copy of the metadata describing the current queue. */
@property(nonatomic, strong, nullable) FSTPBMutationQueue *metadata;

@property(nonatomic, strong, readonly) FSTLocalSerializer *serializer;

@end

@implementation FSTLevelDBMutationQueue {
  FSTLevelDB *_db;

  /** The normalized userID (e.g. nil UID => @"" userID) used in our LevelDB keys. */
  std::string _userID;
}

+ (instancetype)mutationQueueWithUser:(const User &)user
                                   db:(FSTLevelDB *)db
                           serializer:(FSTLocalSerializer *)serializer {
  std::string userID = user.is_authenticated() ? user.uid() : "";

  return [[FSTLevelDBMutationQueue alloc] initWithUserID:std::move(userID)
                                                      db:db
                                              serializer:serializer];
}

- (instancetype)initWithUserID:(std::string)userID
                            db:(FSTLevelDB *)db
                    serializer:(FSTLocalSerializer *)serializer {
  if (self = [super init]) {
    _userID = std::move(userID);
    _db = db;
    _serializer = serializer;
  }
  return self;
}

- (void)start {
  BatchId nextBatchID = [FSTLevelDBMutationQueue loadNextBatchIDFromDB:_db.ptr];

  // On restart, nextBatchId may end up lower than lastAcknowledgedBatchId since it's computed from
  // the queue contents, and there may be no mutations in the queue. In this case, we need to reset
  // lastAcknowledgedBatchId (which is safe since the queue must be empty).
  std::string key = [self keyForCurrentMutationQueue];
  FSTPBMutationQueue *metadata = [self metadataForKey:key];
  if (!metadata) {
    metadata = [FSTPBMutationQueue message];

    // proto3's default value for lastAcknowledgedBatchId is zero, but that would consider the first
    // entry in the queue to be acknowledged without that acknowledgement actually happening.
    metadata.lastAcknowledgedBatchId = kFSTBatchIDUnknown;
  } else {
    BatchId lastAcked = metadata.lastAcknowledgedBatchId;
    if (lastAcked >= nextBatchID) {
      HARD_ASSERT([self isEmpty], "Reset nextBatchID is only possible when the queue is empty");
      lastAcked = kFSTBatchIDUnknown;

      metadata.lastAcknowledgedBatchId = lastAcked;
      _db.currentTransaction->Put([self keyForCurrentMutationQueue], metadata);
    }
  }

  self.nextBatchID = nextBatchID;
  self.metadata = metadata;
}

+ (BatchId)loadNextBatchIDFromDB:(DB *)db {
  // TODO(gsoltis): implement Prev() and SeekToLast() on LevelDbTransaction::Iterator, then port
  // this to a transaction.
  std::unique_ptr<Iterator> it(db->NewIterator(LevelDbTransaction::DefaultReadOptions()));

  auto tableKey = LevelDbMutationKey::KeyPrefix();

  LevelDbMutationKey rowKey;
  BatchId maxBatchID = kFSTBatchIDUnknown;

  BOOL moreUserIDs = NO;
  std::string nextUserID;

  it->Seek(tableKey);
  if (it->Valid() && rowKey.Decode(MakeStringView(it->key()))) {
    moreUserIDs = YES;
    nextUserID = rowKey.user_id();
  }

  // This loop assumes that nextUserId contains the next username at the start of the iteration.
  while (moreUserIDs) {
    // Compute the first key after the last mutation for nextUserID.
    auto userEnd = LevelDbMutationKey::KeyPrefix(nextUserID);
    userEnd = util::PrefixSuccessor(userEnd);

    // Seek to that key with the intent of finding the boundary between nextUserID's mutations
    // and the one after that (if any).
    it->Seek(userEnd);

    // At this point there are three possible cases to handle differently. Each case must prepare
    // the next iteration (by assigning to nextUserID or setting moreUserIDs = NO) and seek the
    // iterator to the last row in the current user's mutation sequence.
    if (!it->Valid()) {
      // The iterator is past the last row altogether (there are no additional userIDs and now
      // rows in any table after mutations). The last row will have the highest batchID.
      moreUserIDs = NO;
      it->SeekToLast();

    } else if (rowKey.Decode(MakeStringView(it->key()))) {
      // The iterator is valid and the key decoded successfully so the next user was just decoded.
      nextUserID = rowKey.user_id();
      it->Prev();

    } else {
      // The iterator is past the end of the mutations table but there are other rows.
      moreUserIDs = NO;
      it->Prev();
    }

    // In all the cases above there was at least one row for the current user and each case has
    // set things up such that iterator points to it.
    if (!rowKey.Decode(MakeStringView(it->key()))) {
      HARD_FAIL("There should have been a key previous to %s", userEnd);
    }

    if (rowKey.batch_id() > maxBatchID) {
      maxBatchID = rowKey.batch_id();
    }
  }

  return maxBatchID + 1;
}

- (BOOL)isEmpty {
  std::string userKey = LevelDbMutationKey::KeyPrefix(_userID);

  auto it = _db.currentTransaction->NewIterator();
  it->Seek(userKey);

  BOOL empty = YES;
  if (it->Valid() && absl::StartsWith(it->key(), userKey)) {
    empty = NO;
  }

  return empty;
}

- (BatchId)highestAcknowledgedBatchID {
  return self.metadata.lastAcknowledgedBatchId;
}

- (void)acknowledgeBatch:(FSTMutationBatch *)batch streamToken:(nullable NSData *)streamToken {
  BatchId batchID = batch.batchID;
  HARD_ASSERT(batchID > self.highestAcknowledgedBatchID,
              "Mutation batchIDs must be acknowledged in order");

  FSTPBMutationQueue *metadata = self.metadata;
  metadata.lastAcknowledgedBatchId = batchID;
  metadata.lastStreamToken = streamToken;

  _db.currentTransaction->Put([self keyForCurrentMutationQueue], metadata);
}

- (nullable NSData *)lastStreamToken {
  return self.metadata.lastStreamToken;
}

- (void)setLastStreamToken:(nullable NSData *)streamToken {
  FSTPBMutationQueue *metadata = self.metadata;
  metadata.lastStreamToken = streamToken;

  _db.currentTransaction->Put([self keyForCurrentMutationQueue], metadata);
}

- (std::string)keyForCurrentMutationQueue {
  return LevelDbMutationQueueKey::Key(_userID);
}

- (nullable FSTPBMutationQueue *)metadataForKey:(const std::string &)key {
  std::string value;
  Status status = _db.currentTransaction->Get(key, &value);
  if (status.ok()) {
    return [self parsedMetadata:value];
  } else if (status.IsNotFound()) {
    return nil;
  } else {
    HARD_FAIL("metadataForKey: failed loading key %s with status: %s", key, status.ToString());
  }
}

- (FSTMutationBatch *)addMutationBatchWithWriteTime:(FIRTimestamp *)localWriteTime
                                          mutations:(NSArray<FSTMutation *> *)mutations {
  BatchId batchID = self.nextBatchID;
  self.nextBatchID += 1;

  FSTMutationBatch *batch = [[FSTMutationBatch alloc] initWithBatchID:batchID
                                                       localWriteTime:localWriteTime
                                                            mutations:mutations];
  std::string key = [self mutationKeyForBatch:batch];
  _db.currentTransaction->Put(key, [self.serializer encodedMutationBatch:batch]);

  // Store an empty value in the index which is equivalent to serializing a GPBEmpty message. In the
  // future if we wanted to store some other kind of value here, we can parse these empty values as
  // with some other protocol buffer (and the parser will see all default values).
  std::string emptyBuffer;

  for (FSTMutation *mutation in mutations) {
    key = LevelDbDocumentMutationKey::Key(_userID, mutation.key, batchID);
    _db.currentTransaction->Put(key, emptyBuffer);
  }

  return batch;
}

- (nullable FSTMutationBatch *)lookupMutationBatch:(BatchId)batchID {
  std::string key = [self mutationKeyForBatchID:batchID];

  std::string value;
  Status status = _db.currentTransaction->Get(key, &value);
  if (!status.ok()) {
    if (status.IsNotFound()) {
      return nil;
    }
    HARD_FAIL("Lookup mutation batch (%s, %s) failed with status: %s", _userID, batchID,
              status.ToString());
  }

  return [self decodedMutationBatch:value];
}

- (nullable FSTMutationBatch *)nextMutationBatchAfterBatchID:(BatchId)batchID {
  // All batches with batchID <= self.metadata.lastAcknowledgedBatchId have been acknowledged so
  // the first unacknowledged batch after batchID will have a batchID larger than both of these
  // values.
  BatchId nextBatchID = MAX(batchID, self.metadata.lastAcknowledgedBatchId) + 1;

  std::string key = [self mutationKeyForBatchID:nextBatchID];
  auto it = _db.currentTransaction->NewIterator();
  it->Seek(key);

  LevelDbMutationKey rowKey;
  if (!it->Valid() || !rowKey.Decode(it->key())) {
    // Past the last row in the DB or out of the mutations table
    return nil;
  }

  if (rowKey.user_id() != _userID) {
    // Jumped past the last mutation for this user
    return nil;
  }

  HARD_ASSERT(rowKey.batch_id() >= nextBatchID, "Should have found mutation after %s", nextBatchID);
  return [self decodedMutationBatch:it->value()];
}

- (NSArray<FSTMutationBatch *> *)allMutationBatchesThroughBatchID:(BatchId)batchID {
  std::string userKey = LevelDbMutationKey::KeyPrefix(_userID);

  auto it = _db.currentTransaction->NewIterator();
  it->Seek(userKey);

  NSMutableArray *result = [NSMutableArray array];
  LevelDbMutationKey rowKey;
  for (; it->Valid() && rowKey.Decode(it->key()); it->Next()) {
    if (rowKey.user_id() != _userID) {
      // End of this user's mutations
      break;
    } else if (rowKey.batch_id() > batchID) {
      // This mutation is past what we're looking for
      break;
    }

    [result addObject:[self decodedMutationBatch:it->value()]];
  }

  return result;
}

- (NSArray<FSTMutationBatch *> *)allMutationBatchesAffectingDocumentKey:
    (const DocumentKey &)documentKey {
  // Scan the document-mutation index starting with a prefix starting with the given documentKey.
  std::string indexPrefix = LevelDbDocumentMutationKey::KeyPrefix(_userID, documentKey.path());
  auto indexIterator = _db.currentTransaction->NewIterator();
  indexIterator->Seek(indexPrefix);

  // Simultaneously scan the mutation queue. This works because each (key, batchID) pair is unique
  // and ordered, so when scanning a table prefixed by exactly key, all the batchIDs encountered
  // will be unique and in order.
  std::string mutationsPrefix = LevelDbMutationKey::KeyPrefix(_userID);
  auto mutationIterator = _db.currentTransaction->NewIterator();

  NSMutableArray *result = [NSMutableArray array];
  LevelDbDocumentMutationKey rowKey;
  for (; indexIterator->Valid(); indexIterator->Next()) {
    // Only consider rows matching exactly the specific key of interest. Index rows have this
    // form (with markers in brackets):
    //
    // <User>user <Path>collection <Path>doc <BatchId>2 <Terminator>
    // <User>user <Path>collection <Path>doc <BatchId>3 <Terminator>
    // <User>user <Path>collection <Path>doc <Path>sub <Path>doc <BatchId>3 <Terminator>
    //
    // Note that Path markers sort after BatchId markers so this means that when searching for
    // collection/doc, all the entries for it will be contiguous in the table, allowing a break
    // after any mismatch.
    if (!absl::StartsWith(indexIterator->key(), indexPrefix) ||
        !rowKey.Decode(indexIterator->key()) || rowKey.document_key() != documentKey) {
      break;
    }

    // Each row is a unique combination of key and batchID, so this foreign key reference can
    // only occur once.
    std::string mutationKey = LevelDbMutationKey::Key(_userID, rowKey.batch_id());
    mutationIterator->Seek(mutationKey);
    if (!mutationIterator->Valid() || mutationIterator->key() != mutationKey) {
      HARD_FAIL(
          "Dangling document-mutation reference found: "
          "%s points to %s; seeking there found %s",
          DescribeKey(indexIterator), DescribeKey(mutationKey), DescribeKey(mutationIterator));
    }

    [result addObject:[self decodedMutationBatch:mutationIterator->value()]];
  }
  return result;
}

- (NSArray<FSTMutationBatch *> *)allMutationBatchesAffectingDocumentKeys:
    (const DocumentKeySet &)documentKeys {
  // Take a pass through the document keys and collect the set of unique mutation batchIDs that
  // affect them all. Some batches can affect more than one key.
  std::set<BatchId> batchIDs;

  auto indexIterator = _db.currentTransaction->NewIterator();
  LevelDbDocumentMutationKey rowKey;
  for (const DocumentKey &documentKey : documentKeys) {
    std::string indexPrefix = LevelDbDocumentMutationKey::KeyPrefix(_userID, documentKey.path());
    for (indexIterator->Seek(indexPrefix); indexIterator->Valid(); indexIterator->Next()) {
      // Only consider rows matching exactly the specific key of interest. Index rows have this
      // form (with markers in brackets):
      //
      // <User>user <Path>collection <Path>doc <BatchId>2 <Terminator>
      // <User>user <Path>collection <Path>doc <BatchId>3 <Terminator>
      // <User>user <Path>collection <Path>doc <Path>sub <Path>doc <BatchId>3 <Terminator>
      //
      // Note that Path markers sort after BatchId markers so this means that when searching for
      // collection/doc, all the entries for it will be contiguous in the table, allowing a break
      // after any mismatch.
      if (!absl::StartsWith(indexIterator->key(), indexPrefix) ||
          !rowKey.Decode(indexIterator->key()) || rowKey.document_key() != documentKey) {
        break;
      }

      batchIDs.insert(rowKey.batch_id());
    }
  }

  return [self allMutationBatchesWithBatchIDs:batchIDs];
}

- (NSArray<FSTMutationBatch *> *)allMutationBatchesAffectingQuery:(FSTQuery *)query {
  HARD_ASSERT(![query isDocumentQuery], "Document queries shouldn't go down this path");

  const ResourcePath &queryPath = query.path;
  size_t immediateChildrenPathLength = queryPath.size() + 1;

  // TODO(mcg): Actually implement a single-collection query
  //
  // This is actually executing an ancestor query, traversing the whole subtree below the
  // collection which can be horrifically inefficient for some structures. The right way to
  // solve this is to implement the full value index, but that's not in the cards in the near
  // future so this is the best we can do for the moment.
  //
  // Since we don't yet index the actual properties in the mutations, our current approach is to
  // just return all mutation batches that affect documents in the collection being queried.
  //
  // Unlike allMutationBatchesAffectingDocumentKey, this iteration will scan the document-mutation
  // index for more than a single document so the associated batchIDs will be neither necessarily
  // unique nor in order. This means an efficient simultaneous scan isn't possible.
  std::string indexPrefix = LevelDbDocumentMutationKey::KeyPrefix(_userID, queryPath);
  auto indexIterator = _db.currentTransaction->NewIterator();
  indexIterator->Seek(indexPrefix);

  LevelDbDocumentMutationKey rowKey;

  // Collect up unique batchIDs encountered during a scan of the index. Use a set<BatchId> to
  // accumulate batch IDs so they can be traversed in order in a scan of the main table.
  //
  // This method is faster than performing lookups of the keys with _db->Get and keeping a hash of
  // batchIDs that have already been looked up. The performance difference is minor for small
  // numbers of keys but > 30% faster for larger numbers of keys.
  std::set<BatchId> uniqueBatchIDs;
  for (; indexIterator->Valid(); indexIterator->Next()) {
    if (!absl::StartsWith(indexIterator->key(), indexPrefix) ||
        !rowKey.Decode(indexIterator->key())) {
      break;
    }

    // Rows with document keys more than one segment longer than the query path can't be matches.
    // For example, a query on 'rooms' can't match the document /rooms/abc/messages/xyx.
    // TODO(mcg): we'll need a different scanner when we implement ancestor queries.
    if (rowKey.document_key().path().size() != immediateChildrenPathLength) {
      continue;
    }

    uniqueBatchIDs.insert(rowKey.batch_id());
  }

  return [self allMutationBatchesWithBatchIDs:uniqueBatchIDs];
}

/**
 * Constructs an array of matching batches, sorted by batchID to ensure that multiple mutations
 * affecting the same document key are applied in order.
 */
- (NSArray<FSTMutationBatch *> *)allMutationBatchesWithBatchIDs:
    (const std::set<BatchId> &)batchIDs {
  NSMutableArray *result = [NSMutableArray array];

  // Given an ordered set of unique batchIDs perform a skipping scan over the main table to find
  // the mutation batches.
  auto mutationIterator = _db.currentTransaction->NewIterator();
  for (BatchId batchID : batchIDs) {
    std::string mutationKey = LevelDbMutationKey::Key(_userID, batchID);
    mutationIterator->Seek(mutationKey);
    if (!mutationIterator->Valid() || mutationIterator->key() != mutationKey) {
      HARD_FAIL(
          "Dangling document-mutation reference found: "
          "Missing batch %s; seeking there found %s",
          DescribeKey(mutationKey), DescribeKey(mutationIterator));
    }

    [result addObject:[self decodedMutationBatch:mutationIterator->value()]];
  }
  return result;
}

- (NSArray<FSTMutationBatch *> *)allMutationBatches {
  std::string userKey = LevelDbMutationKey::KeyPrefix(_userID);

  auto it = _db.currentTransaction->NewIterator();
  it->Seek(userKey);

  NSMutableArray *result = [NSMutableArray array];
  for (; it->Valid() && absl::StartsWith(it->key(), userKey); it->Next()) {
    [result addObject:[self decodedMutationBatch:it->value()]];
  }

  return result;
}

- (void)removeMutationBatches:(NSArray<FSTMutationBatch *> *)batches {
  auto checkIterator = _db.currentTransaction->NewIterator();

  for (FSTMutationBatch *batch in batches) {
    BatchId batchID = batch.batchID;
    std::string key = LevelDbMutationKey::Key(_userID, batchID);

    // As a sanity check, verify that the mutation batch exists before deleting it.
    checkIterator->Seek(key);
    HARD_ASSERT(checkIterator->Valid(), "Mutation batch %s did not exist", DescribeKey(key));

    HARD_ASSERT(key == checkIterator->key(), "Mutation batch %s not found; found %s",
                DescribeKey(key), DescribeKey(checkIterator));

    _db.currentTransaction->Delete(key);

    for (FSTMutation *mutation in batch.mutations) {
      key = LevelDbDocumentMutationKey::Key(_userID, mutation.key, batchID);
      _db.currentTransaction->Delete(key);
      [_db.referenceDelegate removeMutationReference:mutation.key];
    }
  }
}

- (void)performConsistencyCheck {
  if (![self isEmpty]) {
    return;
  }

  // Verify that there are no entries in the document-mutation index if the queue is empty.
  std::string indexPrefix = LevelDbDocumentMutationKey::KeyPrefix(_userID);
  auto indexIterator = _db.currentTransaction->NewIterator();
  indexIterator->Seek(indexPrefix);

  std::vector<std::string> danglingMutationReferences;

  for (; indexIterator->Valid(); indexIterator->Next()) {
    // Only consider rows matching this index prefix for the current user.
    if (!absl::StartsWith(indexIterator->key(), indexPrefix)) {
      break;
    }

    danglingMutationReferences.push_back(DescribeKey(indexIterator));
  }

  HARD_ASSERT(danglingMutationReferences.empty(),
              "Document leak -- detected dangling mutation references when queue "
              "is empty. Dangling keys: %s",
              util::ToString(danglingMutationReferences));
}

- (std::string)mutationKeyForBatch:(FSTMutationBatch *)batch {
  return LevelDbMutationKey::Key(_userID, batch.batchID);
}

- (std::string)mutationKeyForBatchID:(BatchId)batchID {
  return LevelDbMutationKey::Key(_userID, batchID);
}

/** Parses the MutationQueue metadata from the given LevelDB row contents. */
- (FSTPBMutationQueue *)parsedMetadata:(Slice)slice {
  NSData *data =
      [[NSData alloc] initWithBytesNoCopy:(void *)slice.data() length:slice.size() freeWhenDone:NO];

  NSError *error;
  FSTPBMutationQueue *proto = [FSTPBMutationQueue parseFromData:data error:&error];
  if (!proto) {
    HARD_FAIL("FSTPBMutationQueue failed to parse: %s", error);
  }

  return proto;
}

- (FSTMutationBatch *)decodedMutationBatch:(absl::string_view)encoded {
  NSData *data = [[NSData alloc] initWithBytesNoCopy:(void *)encoded.data()
                                              length:encoded.size()
                                        freeWhenDone:NO];

  NSError *error;
  FSTPBWriteBatch *proto = [FSTPBWriteBatch parseFromData:data error:&error];
  if (!proto) {
    HARD_FAIL("FSTPBMutationBatch failed to parse: %s", error);
  }

  return [self.serializer decodedMutationBatch:proto];
}

@end

NS_ASSUME_NONNULL_END
