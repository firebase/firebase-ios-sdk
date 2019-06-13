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

#include "Firestore/core/src/firebase/firestore/local/query_data.h"

#include <utility>

namespace firebase {
namespace firestore {
namespace local {

using core::Query;
using model::SnapshotVersion;
using nanopb::ByteString;

QueryData::QueryData(Query&& query,
                     model::TargetId target_id,
                     model::ListenSequenceNumber sequence_number,
                     QueryPurpose purpose,
                     SnapshotVersion&& snapshot_version,
                     ByteString&& resume_token)
    : query_(std::move(query)),
      target_id_(target_id),
      sequence_number_(sequence_number),
      purpose_(purpose),
      snapshot_version_(std::move(snapshot_version)),
      resume_token_(std::move(resume_token)) {
}

// TODO(rsgowman): Implement once WatchStream::EmptyResumeToken exists.
/*
QueryData::QueryData(const Query& query, int target_id, QueryPurpose purpose)
    : QueryData(query,
                target_id,
                purpose,
                model::SnapshotVersion::None(),
                WatchStream::EmptyResumeToken()) {
}
*/

QueryData QueryData::Invalid() {
  return QueryData(Query::Invalid(), /*target_id=*/-1, /*sequence_number=*/-1,
                   QueryPurpose::kListen,
                   SnapshotVersion(SnapshotVersion::None()), {});
}

QueryData QueryData::Copy(SnapshotVersion&& snapshot_version,
                          ByteString&& resume_token) const {
  return QueryData(Query(query_), target_id_, sequence_number_, purpose_,
                   std::move(snapshot_version), std::move(resume_token));
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
