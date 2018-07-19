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

namespace firebase {
namespace firestore {
namespace local {

using core::Query;
using model::SnapshotVersion;

QueryData::QueryData(const Query& query,
                     int target_id,
                     QueryPurpose purpose,
                     const SnapshotVersion& snapshot_version,
                     const std::vector<uint8_t>& resume_token)
    : query_(&query),
      target_id_(target_id),
      purpose_(purpose),
      snapshot_version_(&snapshot_version),
      resume_token_(&resume_token) {
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

QueryData QueryData::Copy(const SnapshotVersion& snapshot_version,
                          const std::vector<uint8_t>& resume_token) const {
  return QueryData(*query_, target_id_, purpose_, snapshot_version,
                   resume_token);
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
