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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_QUERY_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_QUERY_H_

#include <limits>
#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"

namespace firebase {
namespace firestore {
namespace core {

/**
 * Represents the internal structure of a Firestore Query. Query instances are
 * immutable.
 */
class Query {
 public:
  static constexpr int32_t kNoLimit = std::numeric_limits<int32_t>::max();

  static Query Invalid() {
    return Query(model::ResourcePath::Empty());
  }

  /**
   * Initializes a Query with a path and optional additional query constraints.
   * Path must currently be empty if this is a collection group query.
   */
  Query(model::ResourcePath path,
        std::vector<std::shared_ptr<core::Filter>> filters = {})
      : path_(std::move(path)), filters_(std::move(filters)) {
  }

  // MARK: - Accessors

  /** The base path of the query. */
  const model::ResourcePath& path() const {
    return path_;
  }

  /** Returns true if this Query is for a specific document. */
  bool IsDocumentQuery() const;

  /** The filters on the documents returned by the query. */
  const std::vector<std::shared_ptr<core::Filter>>& filters() const {
    return filters_;
  }

  // MARK: - Builder methods

  /**
   * Returns a copy of this Query object with the additional specified filter.
   */
  Query Filter(std::shared_ptr<core::Filter> filter) const;

  // MARK: - Matching

  /** Returns true if the document matches the constraints of this query. */
  bool Matches(const model::Document& doc) const;

 private:
  bool MatchesPath(const model::Document& doc) const;
  bool MatchesFilters(const model::Document& doc) const;
  bool MatchesOrderBy(const model::Document& doc) const;
  bool MatchesBounds(const model::Document& doc) const;

  model::ResourcePath path_;

  // Filters are shared across related Query instance. i.e. when you call
  // Query::Filter(f), a new Query instance is created that contains all of the
  // existing filters, plus the new one. (Both Query and Filter objects are
  // immutable.) Filters are not shared across unrelated Query instances.
  std::vector<std::shared_ptr<core::Filter>> filters_;

  // TODO(rsgowman): Port collection group queries logic.
};

bool operator==(const Query& lhs, const Query& rhs);

inline bool operator!=(const Query& lhs, const Query& rhs) {
  return !(lhs == rhs);
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_QUERY_H_
