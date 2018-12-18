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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_MEMORY_QUERY_CACHE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_MEMORY_QUERY_CACHE_H_

#if !defined(__OBJC__)
#error "For now, this file must only be included by ObjC source files."
#endif  // !defined(__OBJC__)

#import <Foundation/Foundation.h>

#include <cstdint>
#include <utility>

#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"

@class FSTLocalSerializer;
@class FSTMemoryPersistence;
@class FSTQuery;
@class FSTQueryData;
@class FSTReferenceSet;

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace local {

typedef void (^TargetEnumerator)(FSTQueryData*, BOOL*);

class MemoryQueryCache {
 public:
  MemoryQueryCache(FSTMemoryPersistence* persistence);

  // Targets
  void Add(FSTQueryData* query_data);

  void Update(FSTQueryData* query_data);

  void Remove(FSTQueryData* query_data);

  FSTQueryData *_Nullable Get(FSTQuery* query);

  void EnumerateTargets(TargetEnumerator block);

  int RemoveThroughBound(model::ListenSequenceNumber upper_bound, NSDictionary<NSNumber*, FSTQueryData*>* live_targets);

  // Keys
  void AddMatchingKeys(const model::DocumentKeySet &keys, model::TargetId target_id);

  void RemoveMatchingKeys(const model::DocumentKeySet &keys, model::TargetId target_id);

  void RemoveMatchingKeysForTargetId(model::TargetId target_id);

  model::DocumentKeySet GetMatchingKeys(model::TargetId target_id);

  bool Contains(const model::DocumentKey& key);

  size_t CalculateByteSize(FSTLocalSerializer* serializer);

  int32_t count() const { return static_cast<int32_t>([queries_ count]); }

  model::ListenSequenceNumber highest_listen_sequence_number() const { return highest_listen_sequence_number_; }

  model::TargetId highest_target_id() const { return highest_target_id_; }

  const model::SnapshotVersion& last_remote_snapshot_version() const { return last_remote_snapshot_version_; }

  void set_last_remote_snapshot_version(model::SnapshotVersion version) {
    last_remote_snapshot_version_ = std::move(version);
  }

 private:
  FSTMemoryPersistence* persistence_;
  model::ListenSequenceNumber highest_listen_sequence_number_;
  /** The highest numbered target ID encountered. */
  model::TargetId highest_target_id_;
  /** The last received snapshot version. */
  model::SnapshotVersion last_remote_snapshot_version_;

  /** Maps a query to the data about that query. */
  NSMutableDictionary<FSTQuery*, FSTQueryData *>* queries_;
  /** A ordered bidirectional mapping between documents and the remote target IDs. */
  FSTReferenceSet* references_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_MEMORY_QUERY_CACHE_H_
