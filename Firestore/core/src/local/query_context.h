/*
 * Copyright 2023 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_LOCAL_QUERY_CONTEXT_H_
#define FIRESTORE_CORE_SRC_LOCAL_QUERY_CONTEXT_H_

namespace firebase {
namespace firestore {
namespace local {

/** A tracker to keep a record of important details during database local query
 * execution. */
class QueryContext {
 public:
  size_t GetDocumentReadCount() const {
    return document_read_count_;
  }

  void IncrementDocumentReadCount(size_t num) {
    document_read_count_ += num;
  }

 private:
  /** Counts the number of documents passed through during local query
   * execution. */
  size_t document_read_count_ = 0;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_QUERY_CONTEXT_H_
