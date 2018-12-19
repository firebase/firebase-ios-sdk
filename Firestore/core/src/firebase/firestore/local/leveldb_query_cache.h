/*
 * Copyright 2018 Google
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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LEVELDB_QUERY_CACHE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LEVELDB_QUERY_CACHE_H_

#if !defined(__OBJC__)
#error "For now, this file must only be included by ObjC source files."
#endif  // !defined(__OBJC__)

#import <Foundation/Foundation.h>

// TODO(gsoltis): temporary include for `TargetEnumerator`. This will move once
// the QueryCache interface is defined, and then likely be deleted or replaced
// in favor of an iterator.
#import "Firestore/Protos/objc/firestore/local/Target.pbobjc.h"
#include "Firestore/core/src/firebase/firestore/local/memory_query_cache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "absl/strings/string_view.h"
#include "leveldb/db.h"

@class FSTLevelDB;
@class FSTLocalSerializer;
@class FSTQuery;
@class FSTQueryData;

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace local {

typedef void (^OrphanedDocumentEnumerator)(const model::DocumentKey&,
                                           model::ListenSequenceNumber,
                                           BOOL*);

/** Cached Queries backed by LevelDB. */
class LevelDbQueryCache {
 public:
  /**
   * Retrieves the global singleton metadata row from the given database, if it
   * exists.
   * TODO(gsoltis): remove this method once fully ported to transactions.
   */
  static FSTPBTargetGlobal* ReadMetadata(leveldb::DB* db);

  /**
   * Creates a new query cache in the given LevelDB.
   *
   * @param db The LevelDB in which to create the cache.
   */
  LevelDbQueryCache(FSTLevelDB* db, FSTLocalSerializer* serializer);

  // Target-related methods
  void AddTarget(FSTQueryData* query_data);

  void UpdateTarget(FSTQueryData* query_data);

  void RemoveTarget(FSTQueryData* query_data);

  FSTQueryData* _Nullable GetTarget(FSTQuery* query);

  void EnumerateTargets(TargetEnumerator block);

  int RemoveTargets(model::ListenSequenceNumber upper_bound,
                    NSDictionary<NSNumber*, FSTQueryData*>* live_targets);

  // Key-related methods
  void AddMatchingKeys(const model::DocumentKeySet& keys,
                       model::TargetId target_id);

  void RemoveMatchingKeys(const model::DocumentKeySet& keys,
                          model::TargetId target_id);

  void RemoveAllKeysForTarget(model::TargetId target_id);

  model::DocumentKeySet GetMatchingKeys(model::TargetId target_id);

  bool Contains(const model::DocumentKey& key);

  // Other methods and accessors
  int32_t count() const {
    return metadata_.targetCount;
  }

  model::TargetId highest_target_id() const {
    return metadata_.highestTargetId;
  }

  model::ListenSequenceNumber highest_listen_sequence_number() const {
    return metadata_.highestListenSequenceNumber;
  }

  const model::SnapshotVersion& last_remote_snapshot_version() const {
    return last_remote_snapshot_version_;
  }

  void set_last_remote_snapshot_version(model::SnapshotVersion version);

  // Non-interface methods
  void Start();

  void EnumerateOrphanedDocuments(OrphanedDocumentEnumerator block);

 private:
  void Save(FSTQueryData* query_data);
  bool UpdateMetadata(FSTQueryData* query_data);
  void SaveMetadata();
  /**
   * Parses the given bytes as an FSTPBTarget protocol buffer and then converts
   * to the equivalent query data.
   */
  FSTQueryData* DecodeTarget(absl::string_view encoded);

  // This instance is owned by FSTLevelDB; avoid a retain cycle.
  __weak FSTLevelDB* db_;
  FSTLocalSerializer* serializer_;
  /** A write-through cached copy of the metadata for the query cache. */
  FSTPBTargetGlobal* metadata_;
  model::SnapshotVersion last_remote_snapshot_version_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LEVELDB_QUERY_CACHE_H_
