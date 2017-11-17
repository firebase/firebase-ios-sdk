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

#import "Firestore/Source/Local/FSTLevelDBQueryCache.h"

#include <leveldb/db.h>
#include <leveldb/write_batch.h>
#include <string>

#import "Firestore/Protos/objc/firestore/local/Target.pbobjc.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTLevelDBKey.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Local/FSTWriteGroup.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Util/FSTAssert.h"

#include "Firestore/Port/ordered_code.h"
#include "Firestore/Port/string_util.h"

NS_ASSUME_NONNULL_BEGIN

using Firestore::OrderedCode;
using Firestore::StringView;
using leveldb::DB;
using leveldb::Iterator;
using leveldb::ReadOptions;
using leveldb::Slice;
using leveldb::Status;
using leveldb::WriteOptions;

/**
 * Returns a standard set of read options.
 *
 * For now this is paranoid, but perhaps disable that in production builds.
 */
static ReadOptions GetStandardReadOptions() {
  ReadOptions options;
  options.verify_checksums = true;
  return options;
}

@interface FSTLevelDBQueryCache ()

/** A write-through cached copy of the metadata for the query cache. */
@property(nonatomic, strong, nullable) FSTPBTargetGlobal *metadata;

@property(nonatomic, strong, readonly) FSTLocalSerializer *serializer;

@end

@implementation FSTLevelDBQueryCache {
  // The DB pointer is shared with all cooperating LevelDB-related objects.
  std::shared_ptr<DB> _db;

  /**
   * The last received snapshot version. This is part of `metadata` but we store it separately to
   * avoid extra conversion to/from GPBTimestamp.
   */
  FSTSnapshotVersion *_lastRemoteSnapshotVersion;
}

- (instancetype)initWithDB:(std::shared_ptr<DB>)db serializer:(FSTLocalSerializer *)serializer {
  if (self = [super init]) {
    FSTAssert(db, @"db must not be NULL");
    _db = db;
    _serializer = serializer;
  }
  return self;
}

- (void)start {
  std::string key = [FSTLevelDBTargetGlobalKey key];
  FSTPBTargetGlobal *metadata = [self metadataForKey:key];
  if (!metadata) {
    metadata = [FSTPBTargetGlobal message];
  }
  _lastRemoteSnapshotVersion = [self.serializer decodedVersion:metadata.lastRemoteSnapshotVersion];

  self.metadata = metadata;
}

#pragma mark - FSTQueryCache implementation

- (FSTTargetID)highestTargetID {
  return self.metadata.highestTargetId;
}

- (FSTSnapshotVersion *)lastRemoteSnapshotVersion {
  return _lastRemoteSnapshotVersion;
}

- (void)setLastRemoteSnapshotVersion:(FSTSnapshotVersion *)snapshotVersion
                               group:(FSTWriteGroup *)group {
  _lastRemoteSnapshotVersion = snapshotVersion;
  self.metadata.lastRemoteSnapshotVersion = [self.serializer encodedVersion:snapshotVersion];
  [group setMessage:self.metadata forKey:[FSTLevelDBTargetGlobalKey key]];
}

- (void)shutdown {
  _db.reset();
}

- (void)addQueryData:(FSTQueryData *)queryData group:(FSTWriteGroup *)group {
  // TODO(mcg): actually populate listen sequence number
  FSTTargetID targetID = queryData.targetID;
  std::string key = [FSTLevelDBTargetKey keyWithTargetID:targetID];
  [group setMessage:[self.serializer encodedQueryData:queryData] forKey:key];

  NSString *canonicalID = queryData.query.canonicalID;
  std::string indexKey =
      [FSTLevelDBQueryTargetKey keyWithCanonicalID:canonicalID targetID:targetID];
  std::string emptyBuffer;
  [group setData:emptyBuffer forKey:indexKey];

  FSTPBTargetGlobal *metadata = self.metadata;
  if (targetID > metadata.highestTargetId) {
    metadata.highestTargetId = targetID;
    [group setMessage:metadata forKey:[FSTLevelDBTargetGlobalKey key]];
  }
}

- (void)removeQueryData:(FSTQueryData *)queryData group:(FSTWriteGroup *)group {
  FSTTargetID targetID = queryData.targetID;

  [self removeMatchingKeysForTargetID:targetID group:group];

  std::string key = [FSTLevelDBTargetKey keyWithTargetID:targetID];
  [group removeMessageForKey:key];

  std::string indexKey =
      [FSTLevelDBQueryTargetKey keyWithCanonicalID:queryData.query.canonicalID targetID:targetID];
  [group removeMessageForKey:indexKey];
}

/**
 * Looks up the query global metadata associated with the given key.
 *
 * @return the parsed protocol buffer message or nil if the row referenced by the given key does
 *     not exist.
 */
- (nullable FSTPBTargetGlobal *)metadataForKey:(const std::string &)key {
  std::string value;
  Status status = _db->Get(GetStandardReadOptions(), key, &value);
  if (status.IsNotFound()) {
    return nil;
  } else if (!status.ok()) {
    FSTFail(@"metadataForKey: failed loading key %s with status: %s", key.c_str(),
            status.ToString().c_str());
  }

  NSData *data =
      [[NSData alloc] initWithBytesNoCopy:(void *)value.data() length:value.size() freeWhenDone:NO];

  NSError *error;
  FSTPBTargetGlobal *proto = [FSTPBTargetGlobal parseFromData:data error:&error];
  if (!proto) {
    FSTFail(@"FSTPBTargetGlobal failed to parse: %@", error);
  }

  return proto;
}

/**
 * Parses the given bytes as an FSTPBTarget protocol buffer and then converts to the equivalent
 * query data.
 */
- (FSTQueryData *)decodedTargetWithSlice:(Slice)slice {
  NSData *data =
      [[NSData alloc] initWithBytesNoCopy:(void *)slice.data() length:slice.size() freeWhenDone:NO];

  NSError *error;
  FSTPBTarget *proto = [FSTPBTarget parseFromData:data error:&error];
  if (!proto) {
    FSTFail(@"FSTPBTarget failed to parse: %@", error);
  }

  return [self.serializer decodedQueryData:proto];
}

- (nullable FSTQueryData *)queryDataForQuery:(FSTQuery *)query {
  // Scan the query-target index starting with a prefix starting with the given query's canonicalID.
  // Note that this is a scan rather than a get because canonicalIDs are not required to be unique
  // per target.
  Slice canonicalID = StringView(query.canonicalID);
  std::unique_ptr<Iterator> indexItererator(_db->NewIterator(GetStandardReadOptions()));
  std::string indexPrefix = [FSTLevelDBQueryTargetKey keyPrefixWithCanonicalID:canonicalID];
  indexItererator->Seek(indexPrefix);

  // Simultaneously scan the targets table. This works because each (canonicalID, targetID) pair is
  // unique and ordered, so when scanning a table prefixed by exactly one canonicalID, all the
  // targetIDs will be unique and in order.
  std::string targetPrefix = [FSTLevelDBTargetKey keyPrefix];
  std::unique_ptr<Iterator> targetIterator(_db->NewIterator(GetStandardReadOptions()));

  FSTLevelDBQueryTargetKey *rowKey = [[FSTLevelDBQueryTargetKey alloc] init];
  for (; indexItererator->Valid(); indexItererator->Next()) {
    Slice indexKey = indexItererator->key();

    // Only consider rows matching exactly the specific canonicalID of interest.
    if (!indexKey.starts_with(indexPrefix) || ![rowKey decodeKey:indexKey] ||
        canonicalID != rowKey.canonicalID) {
      // End of this canonicalID's possible targets.
      break;
    }

    // Each row is a unique combination of canonicalID and targetID, so this foreign key reference
    // can only occur once.
    std::string targetKey = [FSTLevelDBTargetKey keyWithTargetID:rowKey.targetID];
    targetIterator->Seek(targetKey);
    if (!targetIterator->Valid() || targetIterator->key() != targetKey) {
      NSString *foundKeyDescription = @"the end of the table";
      if (targetIterator->Valid()) {
        foundKeyDescription = [FSTLevelDBKey descriptionForKey:targetIterator->key()];
      }
      FSTFail(
          @"Dangling query-target reference found: "
          @"%@ points to %@; seeking there found %@",
          [FSTLevelDBKey descriptionForKey:indexKey], [FSTLevelDBKey descriptionForKey:targetKey],
          foundKeyDescription);
    }

    // Finally after finding a potential match, check that the query is actually equal to the
    // requested query.
    FSTQueryData *target = [self decodedTargetWithSlice:targetIterator->value()];
    if ([target.query isEqual:query]) {
      return target;
    }
  }

  return nil;
}

#pragma mark Matching Key tracking

- (void)addMatchingKeys:(FSTDocumentKeySet *)keys
            forTargetID:(FSTTargetID)targetID
                  group:(FSTWriteGroup *)group {
  // Store an empty value in the index which is equivalent to serializing a GPBEmpty message. In the
  // future if we wanted to store some other kind of value here, we can parse these empty values as
  // with some other protocol buffer (and the parser will see all default values).
  std::string emptyBuffer;

  [keys enumerateObjectsUsingBlock:^(FSTDocumentKey *documentKey, BOOL *stop) {
    [group setData:emptyBuffer
            forKey:[FSTLevelDBTargetDocumentKey keyWithTargetID:targetID documentKey:documentKey]];
    [group setData:emptyBuffer
            forKey:[FSTLevelDBDocumentTargetKey keyWithDocumentKey:documentKey targetID:targetID]];
  }];
}

- (void)removeMatchingKeys:(FSTDocumentKeySet *)keys
               forTargetID:(FSTTargetID)targetID
                     group:(FSTWriteGroup *)group {
  [keys enumerateObjectsUsingBlock:^(FSTDocumentKey *key, BOOL *stop) {
    [group
        removeMessageForKey:[FSTLevelDBTargetDocumentKey keyWithTargetID:targetID documentKey:key]];
    [group
        removeMessageForKey:[FSTLevelDBDocumentTargetKey keyWithDocumentKey:key targetID:targetID]];
    [self.garbageCollector addPotentialGarbageKey:key];
  }];
}

- (void)removeMatchingKeysForTargetID:(FSTTargetID)targetID group:(FSTWriteGroup *)group {
  std::string indexPrefix = [FSTLevelDBTargetDocumentKey keyPrefixWithTargetID:targetID];
  std::unique_ptr<Iterator> indexIterator(_db->NewIterator(GetStandardReadOptions()));
  indexIterator->Seek(indexPrefix);

  FSTLevelDBTargetDocumentKey *rowKey = [[FSTLevelDBTargetDocumentKey alloc] init];
  for (; indexIterator->Valid(); indexIterator->Next()) {
    Slice indexKey = indexIterator->key();

    // Only consider rows matching this specific targetID.
    if (![rowKey decodeKey:indexKey] || rowKey.targetID != targetID) {
      break;
    }
    FSTDocumentKey *documentKey = rowKey.documentKey;

    // Delete both index rows
    [group removeMessageForKey:indexKey];
    [group removeMessageForKey:[FSTLevelDBDocumentTargetKey keyWithDocumentKey:documentKey
                                                                      targetID:targetID]];
    [self.garbageCollector addPotentialGarbageKey:documentKey];
  }
}

- (FSTDocumentKeySet *)matchingKeysForTargetID:(FSTTargetID)targetID {
  std::string indexPrefix = [FSTLevelDBTargetDocumentKey keyPrefixWithTargetID:targetID];
  std::unique_ptr<Iterator> indexIterator(_db->NewIterator(GetStandardReadOptions()));
  indexIterator->Seek(indexPrefix);

  FSTDocumentKeySet *result = [FSTDocumentKeySet keySet];
  FSTLevelDBTargetDocumentKey *rowKey = [[FSTLevelDBTargetDocumentKey alloc] init];
  for (; indexIterator->Valid(); indexIterator->Next()) {
    Slice indexKey = indexIterator->key();

    // Only consider rows matching this specific targetID.
    if (![rowKey decodeKey:indexKey] || rowKey.targetID != targetID) {
      break;
    }

    result = [result setByAddingObject:rowKey.documentKey];
  }

  return result;
}

#pragma mark - FSTGarbageSource implementation

- (BOOL)containsKey:(FSTDocumentKey *)key {
  std::string indexPrefix = [FSTLevelDBDocumentTargetKey keyPrefixWithResourcePath:key.path];
  std::unique_ptr<Iterator> indexIterator(_db->NewIterator(GetStandardReadOptions()));
  indexIterator->Seek(indexPrefix);

  if (indexIterator->Valid()) {
    FSTLevelDBDocumentTargetKey *rowKey = [[FSTLevelDBDocumentTargetKey alloc] init];
    if ([rowKey decodeKey:indexIterator->key()] && [rowKey.documentKey isEqualToKey:key]) {
      return YES;
    }
  }

  return NO;
}

@end

NS_ASSUME_NONNULL_END
