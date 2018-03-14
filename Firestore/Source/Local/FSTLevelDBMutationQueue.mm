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

#include <leveldb/db.h>
#include <leveldb/write_batch.h>
#include <set>
#include <string>

#import "Firestore/Protos/objc/firestore/local/Mutation.pbobjc.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLevelDBKey.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#import "Firestore/Source/Local/FSTWriteGroup.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"
#import "Firestore/Source/Util/FSTAssert.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/src/firebase/firestore/util/string_util.h"

NS_ASSUME_NONNULL_BEGIN

namespace util = firebase::firestore::util;
using Firestore::StringView;
using firebase::firestore::auth::User;
using firebase::firestore::model::ResourcePath;
using leveldb::DB;
using leveldb::Iterator;
using leveldb::ReadOptions;
using leveldb::Slice;
using leveldb::Status;
using leveldb::WriteBatch;
using leveldb::WriteOptions;

@interface FSTLevelDBMutationQueue ()

- (instancetype)initWithUserID:(NSString *)userID
                            db:(std::shared_ptr<DB>)db
                    serializer:(FSTLocalSerializer *)serializer NS_DESIGNATED_INITIALIZER;

/** The normalized userID (e.g. nil UID => @"" userID) used in our LevelDB keys. */
@property(nonatomic, strong, readonly) NSString *userID;

/**
 * Next value to use when assigning sequential IDs to each mutation batch.
 *
 * NOTE: There can only be one FSTLevelDBMutationQueue for a given db at a time, hence it is safe
 * to track nextBatchID as an instance-level property. Should we ever relax this constraint we'll
 * need to revisit this.
 */
@property(nonatomic, assign) FSTBatchID nextBatchID;

/** A write-through cache copy of the metadata describing the current queue. */
@property(nonatomic, strong, nullable) FSTPBMutationQueue *metadata;

@property(nonatomic, strong, readonly) FSTLocalSerializer *serializer;

@end

/**
 * Returns a standard set of read options.
 *
 * For now this is paranoid, but perhaps disable that in production builds.
 */
static ReadOptions StandardReadOptions() {
  ReadOptions options;
  options.verify_checksums = true;
  return options;
}

@implementation FSTLevelDBMutationQueue {
  // The DB pointer is shared with all cooperating LevelDB-related objects.
  std::shared_ptr<DB> _db;
}

+ (instancetype)mutationQueueWithUser:(const User &)user
                                   db:(std::shared_ptr<DB>)db
                           serializer:(FSTLocalSerializer *)serializer {
  NSString *userID = user.is_authenticated() ? util::WrapNSString(user.uid()) : @"";

  return [[FSTLevelDBMutationQueue alloc] initWithUserID:userID db:db serializer:serializer];
}

- (instancetype)initWithUserID:(NSString *)userID
                            db:(std::shared_ptr<DB>)db
                    serializer:(FSTLocalSerializer *)serializer {
  if (self = [super init]) {
    _userID = [userID copy];
    _db = db;
    _serializer = serializer;
  }
  return self;
}

- (void)startWithGroup:(FSTWriteGroup *)group {
  FSTBatchID nextBatchID = [FSTLevelDBMutationQueue loadNextBatchIDFromDB:_db];

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
    FSTBatchID lastAcked = metadata.lastAcknowledgedBatchId;
    if (lastAcked >= nextBatchID) {
      FSTAssert([self isEmpty], @"Reset nextBatchID is only possible when the queue is empty");
      lastAcked = kFSTBatchIDUnknown;

      metadata.lastAcknowledgedBatchId = lastAcked;
      [group setMessage:metadata forKey:[self keyForCurrentMutationQueue]];
    }
  }

  self.nextBatchID = nextBatchID;
  self.metadata = metadata;
}

- (void)shutdown {
  _db.reset();
}

+ (FSTBatchID)loadNextBatchIDFromDB:(std::shared_ptr<DB>)db {
  std::unique_ptr<Iterator> it(db->NewIterator(StandardReadOptions()));

  auto tableKey = [FSTLevelDBMutationKey keyPrefix];

  FSTLevelDBMutationKey *rowKey = [[FSTLevelDBMutationKey alloc] init];
  FSTBatchID maxBatchID = kFSTBatchIDUnknown;

  BOOL moreUserIDs = NO;
  std::string nextUserID;

  it->Seek(tableKey);
  if (it->Valid() && [rowKey decodeKey:it->key()]) {
    moreUserIDs = YES;
    nextUserID = rowKey.userID;
  }

  // This loop assumes that nextUserId contains the next username at the start of the iteration.
  while (moreUserIDs) {
    // Compute the first key after the last mutation for nextUserID.
    auto userEnd = [FSTLevelDBMutationKey keyPrefixWithUserID:nextUserID];
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

    } else if ([rowKey decodeKey:it->key()]) {
      // The iterator is valid and the key decoded successfully so the next user was just decoded.
      nextUserID = rowKey.userID;
      it->Prev();

    } else {
      // The iterator is past the end of the mutations table but there are other rows.
      moreUserIDs = NO;
      it->Prev();
    }

    // In all the cases above there was at least one row for the current user and each case has
    // set things up such that iterator points to it.
    if (![rowKey decodeKey:it->key()]) {
      FSTFail(@"There should have been a key previous to %s", userEnd.c_str());
    }

    if (rowKey.batchID > maxBatchID) {
      maxBatchID = rowKey.batchID;
    }
  }

  return maxBatchID + 1;
}

- (BOOL)isEmpty {
  std::string userKey = [FSTLevelDBMutationKey keyPrefixWithUserID:self.userID];

  std::unique_ptr<Iterator> it(_db->NewIterator(StandardReadOptions()));
  it->Seek(userKey);

  BOOL empty = YES;
  if (it->Valid() && it->key().starts_with(userKey)) {
    empty = NO;
  }

  Status status = it->status();
  if (!status.ok()) {
    FSTFail(@"isEmpty failed with status: %s", status.ToString().c_str());
  }

  return empty;
}

- (FSTBatchID)highestAcknowledgedBatchID {
  return self.metadata.lastAcknowledgedBatchId;
}

- (void)acknowledgeBatch:(FSTMutationBatch *)batch
             streamToken:(nullable NSData *)streamToken
                   group:(FSTWriteGroup *)group {
  FSTBatchID batchID = batch.batchID;
  FSTAssert(batchID > self.highestAcknowledgedBatchID,
            @"Mutation batchIDs must be acknowledged in order");

  FSTPBMutationQueue *metadata = self.metadata;
  metadata.lastAcknowledgedBatchId = batchID;
  metadata.lastStreamToken = streamToken;

  [group setMessage:metadata forKey:[self keyForCurrentMutationQueue]];
}

- (nullable NSData *)lastStreamToken {
  return self.metadata.lastStreamToken;
}

- (void)setLastStreamToken:(nullable NSData *)streamToken group:(FSTWriteGroup *)group {
  FSTPBMutationQueue *metadata = self.metadata;
  metadata.lastStreamToken = streamToken;

  [group setMessage:metadata forKey:[self keyForCurrentMutationQueue]];
}

- (std::string)keyForCurrentMutationQueue {
  return [FSTLevelDBMutationQueueKey keyWithUserID:self.userID];
}

- (nullable FSTPBMutationQueue *)metadataForKey:(const std::string &)key {
  std::string value;
  Status status = _db->Get(StandardReadOptions(), key, &value);
  if (status.ok()) {
    return [self parsedMetadata:value];
  } else if (status.IsNotFound()) {
    return nil;
  } else {
    FSTFail(@"metadataForKey: failed loading key %s with status: %s", key.c_str(),
            status.ToString().c_str());
  }
}

- (FSTMutationBatch *)addMutationBatchWithWriteTime:(FIRTimestamp *)localWriteTime
                                          mutations:(NSArray<FSTMutation *> *)mutations
                                              group:(FSTWriteGroup *)group {
  FSTBatchID batchID = self.nextBatchID;
  self.nextBatchID += 1;

  FSTMutationBatch *batch = [[FSTMutationBatch alloc] initWithBatchID:batchID
                                                       localWriteTime:localWriteTime
                                                            mutations:mutations];
  std::string key = [self mutationKeyForBatch:batch];
  [group setMessage:[self.serializer encodedMutationBatch:batch] forKey:key];

  NSString *userID = self.userID;

  // Store an empty value in the index which is equivalent to serializing a GPBEmpty message. In the
  // future if we wanted to store some other kind of value here, we can parse these empty values as
  // with some other protocol buffer (and the parser will see all default values).
  std::string emptyBuffer;

  for (FSTMutation *mutation in mutations) {
    key = [FSTLevelDBDocumentMutationKey keyWithUserID:userID
                                           documentKey:mutation.key
                                               batchID:batchID];
    [group setData:emptyBuffer forKey:key];
  }

  return batch;
}

- (nullable FSTMutationBatch *)lookupMutationBatch:(FSTBatchID)batchID {
  std::string key = [self mutationKeyForBatchID:batchID];

  std::string value;
  Status status = _db->Get(StandardReadOptions(), key, &value);
  if (!status.ok()) {
    if (status.IsNotFound()) {
      return nil;
    }
    FSTFail(@"Lookup mutation batch (%@, %d) failed with status: %s", self.userID, batchID,
            status.ToString().c_str());
  }

  return [self decodedMutationBatch:value];
}

- (nullable FSTMutationBatch *)nextMutationBatchAfterBatchID:(FSTBatchID)batchID {
  // All batches with batchID <= self.metadata.lastAcknowledgedBatchId have been acknowledged so
  // the first unacknowledged batch after batchID will have a batchID larger than both of these
  // values.
  FSTBatchID nextBatchID = MAX(batchID, self.metadata.lastAcknowledgedBatchId) + 1;

  std::string key = [self mutationKeyForBatchID:nextBatchID];
  std::unique_ptr<Iterator> it(_db->NewIterator(StandardReadOptions()));
  it->Seek(key);

  Status status = it->status();
  if (!status.ok()) {
    FSTFail(@"Seek to mutation batch (%@, %d) failed with status: %s", self.userID, batchID,
            status.ToString().c_str());
  }

  FSTLevelDBMutationKey *rowKey = [[FSTLevelDBMutationKey alloc] init];
  if (!it->Valid() || ![rowKey decodeKey:it->key()]) {
    // Past the last row in the DB or out of the mutations table
    return nil;
  }

  if (rowKey.userID != [self.userID UTF8String]) {
    // Jumped past the last mutation for this user
    return nil;
  }

  FSTAssert(rowKey.batchID >= nextBatchID, @"Should have found mutation after %d", nextBatchID);
  return [self decodedMutationBatch:it->value()];
}

- (NSArray<FSTMutationBatch *> *)allMutationBatchesThroughBatchID:(FSTBatchID)batchID {
  std::string userKey = [FSTLevelDBMutationKey keyPrefixWithUserID:self.userID];
  const char *userID = [self.userID UTF8String];

  std::unique_ptr<Iterator> it(_db->NewIterator(StandardReadOptions()));
  it->Seek(userKey);

  NSMutableArray *result = [NSMutableArray array];
  FSTLevelDBMutationKey *rowKey = [[FSTLevelDBMutationKey alloc] init];
  for (; it->Valid() && [rowKey decodeKey:it->key()]; it->Next()) {
    if (rowKey.userID != userID) {
      // End of this user's mutations
      break;
    } else if (rowKey.batchID > batchID) {
      // This mutation is past what we're looking for
      break;
    }

    [result addObject:[self decodedMutationBatch:it->value()]];
  }

  Status status = it->status();
  if (!status.ok()) {
    FSTFail(@"Find all mutations through mutation batch (%@, %d) failed with status: %s",
            self.userID, batchID, status.ToString().c_str());
  }

  return result;
}

- (NSArray<FSTMutationBatch *> *)allMutationBatchesAffectingDocumentKey:
    (FSTDocumentKey *)documentKey {
  NSString *userID = self.userID;

  // Scan the document-mutation index starting with a prefix starting with the given documentKey.
  std::string indexPrefix =
      [FSTLevelDBDocumentMutationKey keyPrefixWithUserID:self.userID resourcePath:documentKey.path];
  std::unique_ptr<Iterator> indexIterator(_db->NewIterator(StandardReadOptions()));
  indexIterator->Seek(indexPrefix);

  // Simultaneously scan the mutation queue. This works because each (key, batchID) pair is unique
  // and ordered, so when scanning a table prefixed by exactly key, all the batchIDs encountered
  // will be unique and in order.
  std::string mutationsPrefix = [FSTLevelDBMutationKey keyPrefixWithUserID:userID];
  std::unique_ptr<Iterator> mutationIterator(_db->NewIterator(StandardReadOptions()));

  NSMutableArray *result = [NSMutableArray array];
  FSTLevelDBDocumentMutationKey *rowKey = [[FSTLevelDBDocumentMutationKey alloc] init];
  for (; indexIterator->Valid(); indexIterator->Next()) {
    Slice indexKey = indexIterator->key();

    // Only consider rows matching exactly the specific key of interest. Note that because we order
    // by path first, and we order terminators before path separators, we'll encounter all the
    // index rows for documentKey contiguously. In particular, all the rows for documentKey will
    // occur before any rows for documents nested in a subcollection beneath documentKey so we can
    // stop as soon as we hit any such row.
    if (!indexKey.starts_with(indexPrefix) || ![rowKey decodeKey:indexKey] ||
        ![rowKey.documentKey isEqualToKey:documentKey]) {
      break;
    }

    // Each row is a unique combination of key and batchID, so this foreign key reference can
    // only occur once.
    std::string mutationKey = [FSTLevelDBMutationKey keyWithUserID:userID batchID:rowKey.batchID];
    mutationIterator->Seek(mutationKey);
    if (!mutationIterator->Valid() || mutationIterator->key() != mutationKey) {
      NSString *foundKeyDescription = @"the end of the table";
      if (mutationIterator->Valid()) {
        foundKeyDescription = [FSTLevelDBKey descriptionForKey:mutationIterator->key()];
      }
      FSTFail(
          @"Dangling document-mutation reference found: "
          @"%@ points to %@; seeking there found %@",
          [FSTLevelDBKey descriptionForKey:indexKey], [FSTLevelDBKey descriptionForKey:mutationKey],
          foundKeyDescription);
    }

    [result addObject:[self decodedMutationBatch:mutationIterator->value()]];
  }
  return result;
}

- (NSArray<FSTMutationBatch *> *)allMutationBatchesAffectingQuery:(FSTQuery *)query {
  FSTAssert(![query isDocumentQuery], @"Document queries shouldn't go down this path");
  NSString *userID = self.userID;

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
  std::string indexPrefix =
      [FSTLevelDBDocumentMutationKey keyPrefixWithUserID:self.userID resourcePath:queryPath];
  std::unique_ptr<Iterator> indexIterator(_db->NewIterator(StandardReadOptions()));
  indexIterator->Seek(indexPrefix);

  NSMutableArray *result = [NSMutableArray array];
  FSTLevelDBDocumentMutationKey *rowKey = [[FSTLevelDBDocumentMutationKey alloc] init];

  // Collect up unique batchIDs encountered during a scan of the index. Use a set<FSTBatchID> to
  // accumulate batch IDs so they can be traversed in order in a scan of the main table.
  //
  // This method is faster than performing lookups of the keys with _db->Get and keeping a hash of
  // batchIDs that have already been looked up. The performance difference is minor for small
  // numbers of keys but > 30% faster for larger numbers of keys.
  std::set<FSTBatchID> uniqueBatchIds;
  for (; indexIterator->Valid(); indexIterator->Next()) {
    Slice indexKey = indexIterator->key();

    if (!indexKey.starts_with(indexPrefix) || ![rowKey decodeKey:indexKey]) {
      break;
    }

    // Rows with document keys more than one segment longer than the query path can't be matches.
    // For example, a query on 'rooms' can't match the document /rooms/abc/messages/xyx.
    // TODO(mcg): we'll need a different scanner when we implement ancestor queries.
    if (rowKey.documentKey.path.size() != immediateChildrenPathLength) {
      continue;
    }

    uniqueBatchIds.insert(rowKey.batchID);
  }

  // Given an ordered set of unique batchIDs perform a skipping scan over the main table to find
  // the mutation batches.
  std::unique_ptr<Iterator> mutationIterator(_db->NewIterator(StandardReadOptions()));

  for (FSTBatchID batchID : uniqueBatchIds) {
    std::string mutationKey = [FSTLevelDBMutationKey keyWithUserID:userID batchID:batchID];
    mutationIterator->Seek(mutationKey);
    if (!mutationIterator->Valid() || mutationIterator->key() != mutationKey) {
      NSString *foundKeyDescription = @"the end of the table";
      if (mutationIterator->Valid()) {
        foundKeyDescription = [FSTLevelDBKey descriptionForKey:mutationIterator->key()];
      }
      FSTFail(
          @"Dangling document-mutation reference found: "
          @"Missing batch %@; seeking there found %@",
          [FSTLevelDBKey descriptionForKey:mutationKey], foundKeyDescription);
    }

    [result addObject:[self decodedMutationBatch:mutationIterator->value()]];
  }
  return result;
}

- (NSArray<FSTMutationBatch *> *)allMutationBatches {
  std::string userKey = [FSTLevelDBMutationKey keyPrefixWithUserID:self.userID];

  std::unique_ptr<Iterator> it(_db->NewIterator(StandardReadOptions()));
  it->Seek(userKey);

  NSMutableArray *result = [NSMutableArray array];
  for (; it->Valid() && it->key().starts_with(userKey); it->Next()) {
    [result addObject:[self decodedMutationBatch:it->value()]];
  }

  Status status = it->status();
  if (!status.ok()) {
    FSTFail(@"Find all mutation batches failed with status: %s", status.ToString().c_str());
  }

  return result;
}

- (void)removeMutationBatches:(NSArray<FSTMutationBatch *> *)batches group:(FSTWriteGroup *)group {
  NSString *userID = self.userID;
  id<FSTGarbageCollector> garbageCollector = self.garbageCollector;

  std::unique_ptr<Iterator> checkIterator(_db->NewIterator(StandardReadOptions()));

  for (FSTMutationBatch *batch in batches) {
    FSTBatchID batchID = batch.batchID;
    std::string key = [FSTLevelDBMutationKey keyWithUserID:userID batchID:batchID];

    // As a sanity check, verify that the mutation batch exists before deleting it.
    checkIterator->Seek(key);
    FSTAssert(checkIterator->Valid(), @"Mutation batch %@ did not exist",
              [FSTLevelDBKey descriptionForKey:key]);

    FSTAssert(key == checkIterator->key(), @"Mutation batch %@ not found; found %@",
              [FSTLevelDBKey descriptionForKey:key],
              [FSTLevelDBKey descriptionForKey:checkIterator->key()]);

    [group removeMessageForKey:key];

    for (FSTMutation *mutation in batch.mutations) {
      key = [FSTLevelDBDocumentMutationKey keyWithUserID:userID
                                             documentKey:mutation.key
                                                 batchID:batchID];
      [group removeMessageForKey:key];
      [garbageCollector addPotentialGarbageKey:mutation.key];
    }
  }
}

- (void)performConsistencyCheck {
  if (![self isEmpty]) {
    return;
  }

  // Verify that there are no entries in the document-mutation index if the queue is empty.
  std::string indexPrefix = [FSTLevelDBDocumentMutationKey keyPrefixWithUserID:self.userID];
  std::unique_ptr<Iterator> indexIterator(_db->NewIterator(StandardReadOptions()));
  indexIterator->Seek(indexPrefix);

  NSMutableArray<NSString *> *danglingMutationReferences = [NSMutableArray array];

  for (; indexIterator->Valid(); indexIterator->Next()) {
    Slice indexKey = indexIterator->key();

    // Only consider rows matching this index prefix for the current user.
    if (!indexKey.starts_with(indexPrefix)) {
      break;
    }

    [danglingMutationReferences addObject:[FSTLevelDBKey descriptionForKey:indexKey]];
  }

  FSTAssert(danglingMutationReferences.count == 0,
            @"Document leak -- detected dangling mutation references when queue "
            @"is empty. Dangling keys: %@",
            danglingMutationReferences);
}

- (std::string)mutationKeyForBatch:(FSTMutationBatch *)batch {
  return [FSTLevelDBMutationKey keyWithUserID:self.userID batchID:batch.batchID];
}

- (std::string)mutationKeyForBatchID:(FSTBatchID)batchID {
  return [FSTLevelDBMutationKey keyWithUserID:self.userID batchID:batchID];
}

/** Parses the MutationQueue metadata from the given LevelDB row contents. */
- (FSTPBMutationQueue *)parsedMetadata:(Slice)slice {
  NSData *data =
      [[NSData alloc] initWithBytesNoCopy:(void *)slice.data() length:slice.size() freeWhenDone:NO];

  NSError *error;
  FSTPBMutationQueue *proto = [FSTPBMutationQueue parseFromData:data error:&error];
  if (!proto) {
    FSTFail(@"FSTPBMutationQueue failed to parse: %@", error);
  }

  return proto;
}

- (FSTMutationBatch *)decodedMutationBatch:(Slice)slice {
  NSData *data =
      [[NSData alloc] initWithBytesNoCopy:(void *)slice.data() length:slice.size() freeWhenDone:NO];

  NSError *error;
  FSTPBWriteBatch *proto = [FSTPBWriteBatch parseFromData:data error:&error];
  if (!proto) {
    FSTFail(@"FSTPBMutationBatch failed to parse: %@", error);
  }

  return [self.serializer decodedMutationBatch:proto];
}

#pragma mark - FSTGarbageSource implementation

- (BOOL)containsKey:(FSTDocumentKey *)documentKey {
  std::string indexPrefix =
      [FSTLevelDBDocumentMutationKey keyPrefixWithUserID:self.userID resourcePath:documentKey.path];
  std::unique_ptr<Iterator> indexIterator(_db->NewIterator(StandardReadOptions()));
  indexIterator->Seek(indexPrefix);

  if (indexIterator->Valid()) {
    FSTLevelDBDocumentMutationKey *rowKey = [[FSTLevelDBDocumentMutationKey alloc] init];
    Slice iteratorKey = indexIterator->key();

    // Check both that the key prefix matches and that the decoded document key is exactly the key
    // we're looking for.
    if (iteratorKey.starts_with(indexPrefix) && [rowKey decodeKey:iteratorKey] &&
        [rowKey.documentKey isEqualToKey:documentKey]) {
      return YES;
    }
  }

  return NO;
}

@end

NS_ASSUME_NONNULL_END
