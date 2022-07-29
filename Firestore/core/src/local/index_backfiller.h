// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef FIRESTORE_CORE_SRC_LOCAL_INDEX_BACKFILLER_H_
#define FIRESTORE_CORE_SRC_LOCAL_INDEX_BACKFILLER_H_

#include <string>

namespace firebase {
namespace firestore {

namespace util {
class AsyncQueue;
}

namespace model {
class IndexOffset;
}

namespace local {
class Persistence;
class LocalStore;
class LocalWriteResult;
class IndexManager;

/** Implements the steps for backfilling indexes. */
class IndexBackfiller {
 public:
  IndexBackfiller();

  /**
   * Writes index entries until the cap is reached. Returns the number of
   * documents processed.
   */
  int WriteIndexEntries(const LocalStore* local_store);

 private:
  friend class IndexBackfillerTest;

  /**
   * Writes entries for the provided collection group. Returns the number of
   * documents processed.
   */
  int WriteEntriesForCollectionGroup(const LocalStore* local_store,
                                     const std::string& collection_group,
                                     int documents_remaining_under_cap) const;

  /** Returns the next offset based on the provided documents. */
  model::IndexOffset GetNewOffset(const model::IndexOffset& existing_offset,
                                  const LocalWriteResult& lookup_result) const;

  // For testing
  void SetMaxDocumentsToProcess(int new_max) {
    max_documents_to_process_ = new_max;
  }

  int max_documents_to_process_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_INDEX_BACKFILLER_H_
