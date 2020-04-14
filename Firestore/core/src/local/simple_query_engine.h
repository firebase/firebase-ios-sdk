/*
 * Copyright 2019 Google
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

#ifndef FIRESTORE_CORE_SRC_LOCAL_SIMPLE_QUERY_ENGINE_H_
#define FIRESTORE_CORE_SRC_LOCAL_SIMPLE_QUERY_ENGINE_H_

#include "Firestore/core/src/local/query_engine.h"

namespace firebase {
namespace firestore {
namespace local {

class SimpleQueryEngine : public QueryEngine {
 public:
  void SetLocalDocumentsView(LocalDocumentsView* local_documents) override {
    local_documents_view_ = local_documents;
  }

  model::DocumentMap GetDocumentsMatchingQuery(
      const core::Query& query,
      const model::SnapshotVersion& last_limbo_free_snapshot_version,
      const model::DocumentKeySet& remote_keys) override;

  Type type() const override {
    return Type::Simple;
  }

 private:
  LocalDocumentsView* local_documents_view_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_SIMPLE_QUERY_ENGINE_H_
