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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_QUERY_DATA_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_QUERY_DATA_H_

#include <cstdint>
#include <vector>

#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/nanopb/byte_string.h"

namespace firebase {
namespace firestore {
namespace local {

/** An enumeration for the different purposes we have for queries. */
enum class QueryPurpose {
  /** A regular, normal query. */
  kListen,

  /**
   * The query was used to refill a query after an existence filter mismatch.
   */
  kExistenceFilterMismatch,

  /** The query was used to resolve a limbo document. */
  kLimboResolution,
};

/**
 * An immutable set of metadata that the store will need to keep track of for
 * each query.
 */
class QueryData {
 public:
  /**
   * Creates a new QueryData with the given values.
   *
   * @param query The query being listened to.
   * @param target_id The target to which the query corresponds, assigned by the
   *     LocalStore for user queries or the SyncEngine for limbo queries.
   * @param purpose The purpose of the query.
   * @param snapshot_version The latest snapshot version seen for this target.
   * @param resume_token An opaque, server-assigned token that allows watching a
   *     query to be resumed after disconnecting without retransmitting all the
   *     data that matches the query. The resume token essentially identifies a
   *     point in time from which the server should resume sending results.
   */
  QueryData(core::Query&& query,
            model::TargetId target_id,
            model::ListenSequenceNumber sequence_number,
            QueryPurpose purpose,
            model::SnapshotVersion&& snapshot_version,
            nanopb::ByteString&& resume_token);

  /**
   * Convenience constructor for use when creating a QueryData for the first
   * time.
   */
  // TODO(rsgowman): Define once WatchStream::EmptyResumeToken exists.
  // QueryData(const core::Query& query, int target_id, QueryPurpose purpose);

  /**
   * Constructs an invalid QueryData. Reading any properties of the returned
   * value is undefined.
   */
  static QueryData Invalid();

  const core::Query& query() const {
    return query_;
  }

  model::TargetId target_id() const {
    return target_id_;
  }

  model::ListenSequenceNumber sequence_number() const {
    return sequence_number_;
  }

  QueryPurpose purpose() const {
    return purpose_;
  }

  const model::SnapshotVersion& snapshot_version() const {
    return snapshot_version_;
  }

  const nanopb::ByteString& resume_token() const {
    return resume_token_;
  }

  QueryData Copy(model::SnapshotVersion&& snapshot_version,
                 nanopb::ByteString&& resume_token) const;

 private:
  core::Query query_;
  model::TargetId target_id_;
  model::ListenSequenceNumber sequence_number_;
  QueryPurpose purpose_;
  model::SnapshotVersion snapshot_version_;
  nanopb::ByteString resume_token_;
};

inline bool operator==(const QueryData& lhs, const QueryData& rhs) {
  return lhs.query() == rhs.query() && lhs.target_id() == rhs.target_id() &&
         lhs.sequence_number() == rhs.sequence_number() &&
         lhs.purpose() == rhs.purpose() &&
         lhs.snapshot_version() == rhs.snapshot_version() &&
         lhs.resume_token() == rhs.resume_token();
}

inline bool operator!=(const QueryData& lhs, const QueryData& rhs) {
  return !(lhs == rhs);
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_QUERY_DATA_H_
