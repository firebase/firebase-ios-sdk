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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_QUERY_CACHE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_QUERY_CACHE_H_

#if !defined(__OBJC__)
#error "For now, this file must only be included by ObjC source files."
#endif  // !defined(__OBJC__)

#import <Foundation/Foundation.h>

#include <unordered_map>

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"

@class FSTQuery;
@class FSTQueryData;

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace local {

/**
 * Represents cached targets received from the remote backend. This contains
 * both a mapping between targets and the documents that matched them according
 * to the server, but also metadata about the targets.
 *
 * The cache is keyed by FSTQuery and entries in the cache are FSTQueryData
 * instances.
 */
class QueryCache {
 public:
  typedef void (^TargetEnumerator)(FSTQueryData*, BOOL*);

  virtual ~QueryCache() {
  }

  // Target-related methods

  /**
   * Adds an entry in the cache.
   *
   * The cache key is extracted from `queryData.query`. The key must not already
   * exist in the cache.
   *
   * @param query_data A new FSTQueryData instance to put in the cache.
   */
  virtual void AddTarget(FSTQueryData* query_data) = 0;

  /**
   * Updates an entry in the cache.
   *
   * The cache key is extracted from `queryData.query`. The entry must already
   * exist in the cache, and it will be replaced.
   * @param query_data An FSTQueryData instance to replace an existing entry in
   * the cache
   */
  virtual void UpdateTarget(FSTQueryData* query_data) = 0;

  /** Removes the cached entry for the given query data. The entry must already
   * exist in the cache. */
  virtual void RemoveTarget(FSTQueryData* query_data) = 0;

  /**
   * Looks up an FSTQueryData entry in the cache.
   *
   * @param query The query corresponding to the entry to look up.
   * @return The cached FSTQueryData entry, or nil if the cache has no entry for
   * the query.
   */
  virtual FSTQueryData* _Nullable GetTarget(FSTQuery* query) = 0;

  virtual void EnumerateTargets(TargetEnumerator block) = 0;

  virtual int RemoveTargets(
      model::ListenSequenceNumber upper_bound,
      const std::unordered_map<model::TargetId, FSTQueryData*>&
          live_targets) = 0;

  // Key-related methods
  virtual void AddMatchingKeys(const model::DocumentKeySet& keys,
                               model::TargetId target_id) = 0;

  virtual void RemoveMatchingKeys(const model::DocumentKeySet& keys,
                                  model::TargetId target_id) = 0;

  virtual model::DocumentKeySet GetMatchingKeys(model::TargetId target_id) = 0;

  virtual bool Contains(const model::DocumentKey& key) = 0;

  // Accessors

  /** Returns the number of targets cached. */
  virtual size_t size() const = 0;

  /**
   * Returns the highest listen sequence number of any query seen by the cache.
   */
  virtual model::ListenSequenceNumber highest_listen_sequence_number()
      const = 0;

  /**
   * Returns the highest target ID of any query in the cache. Typically called
   * during startup to seed a target ID generator and avoid collisions with
   * existing queries. If there are no queries in the cache, returns zero.
   */
  virtual model::TargetId highest_target_id() const = 0;

  /**
   * A global snapshot version representing the last consistent snapshot we
   * received from the backend. This is monotonically increasing and any
   * snapshots received from the backend prior to this version (e.g. for targets
   * resumed with a resume_token) should be suppressed (buffered) until the
   * backend has caught up to this snapshot version again. This prevents our
   * cache from ever going backwards in time.
   *
   * This is updated whenever our we get a TargetChange with a read_time and
   * empty target_ids.
   */
  virtual const model::SnapshotVersion& GetLastRemoteSnapshotVersion()
      const = 0;

  /**
   * Set the snapshot version representing the last consistent snapshot received
   * from the backend. (see `GetLastRemoteSnapshotVersion()` for more details).
   *
   * @param version The new snapshot version.
   */
  virtual void SetLastRemoteSnapshotVersion(model::SnapshotVersion version) = 0;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_QUERY_CACHE_H_
