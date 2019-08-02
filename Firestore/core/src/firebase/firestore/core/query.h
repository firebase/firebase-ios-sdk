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
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/core/order_by.h"
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
  using CollectionGroupId = std::shared_ptr<const std::string>;
  using FilterList = std::vector<std::shared_ptr<Filter>>;
  using OrderByList = std::vector<OrderBy>;

  static constexpr int32_t kNoLimit = std::numeric_limits<int32_t>::max();

  Query() = default;

  static Query Invalid() {
    return Query();
  }

  explicit Query(model::ResourcePath path,
                 CollectionGroupId collection_group = nullptr)
      : Query(path, collection_group, {}, {}) {
  }

  /**
   * Initializes a Query with a path and optional additional query constraints.
   * Path must currently be empty if this is a collection group query.
   */
  Query(model::ResourcePath path,
        CollectionGroupId collection_group,
        FilterList filters,
        OrderByList explicit_order_bys)
      : path_(std::move(path)),
        collection_group_(std::move(collection_group)),
        filters_(std::move(filters)),
        explicit_order_bys_(std::move(explicit_order_bys)) {
  }

  Query(model::ResourcePath path, std::string collection_group);

  // MARK: - Accessors

  /** The base path of the query. */
  const model::ResourcePath& path() const {
    return path_;
  }

  /** The collection group of the query, if any. */
  const std::shared_ptr<const std::string>& collection_group() const {
    return collection_group_;
  }

  /** Returns true if this Query is for a specific document. */
  bool IsDocumentQuery() const;

  /** Returns true if this Query is a collection group query. */
  bool IsCollectionGroupQuery() const {
    return collection_group_ != nullptr;
  }

  /** The filters on the documents returned by the query. */
  const FilterList& filters() const {
    return filters_;
  }

  /**
   * Returns the field of the first filter on this Query that's an inequality,
   * or nullptr if there are no inequalities.
   */
  const model::FieldPath* InequalityFilterField() const;

  /**
   * Returns the first array operator (array-contains or array-contains-any)
   * found on a filter, or nullptr if there are no array operators.
   */
  absl::optional<Filter::Operator> GetArrayOps() const;

  /**
   * Returns the first disjunctive operator (IN or array-contains-any) found
   * on a filter, or nullptr if there are no disjunctive operators.
   */
  absl::optional<Filter::Operator> GetDisjunctiveOps() const;

  /**
   * Returns the list of ordering constraints that were explicitly requested on
   * the query by the user.
   *
   * Note that the actual query performed might add additional sort orders to
   * match the behavior of the backend.
   */
  const OrderByList& explicit_order_bys() const {
    return explicit_order_bys_;
  }

  /**
   * Returns the full list of ordering constraints on the query.
   *
   * This might include additional sort orders added implicitly to match the
   * backend behavior.
   */
  const OrderByList& order_bys() const;

  /** Returns the first field in an order-by constraint, or nullptr if none. */
  const model::FieldPath* FirstOrderByField() const;

  // MARK: - Builder methods

  /**
   * Returns a copy of this Query object with the additional specified filter.
   */
  Query AddingFilter(std::shared_ptr<Filter> filter) const;

  /**
   * Returns a copy of this Query object with the additional specified order by.
   */
  Query AddingOrderBy(OrderBy order_by) const;

  // MARK: - Matching

  /**
   * Converts this collection group query into a collection query at a specific
   * path. This is used when executing collection group queries, since we have
   * to split the query into a set of collection queries, one for each
   * collection in the group.
   */
  Query AsCollectionQueryAtPath(model::ResourcePath path) const;

  /** Returns true if the document matches the constraints of this query. */
  bool Matches(const model::Document& doc) const;

 private:
  bool MatchesPathAndCollectionGroup(const model::Document& doc) const;
  bool MatchesFilters(const model::Document& doc) const;
  bool MatchesOrderBy(const model::Document& doc) const;
  bool MatchesBounds(const model::Document& doc) const;

  model::ResourcePath path_;
  std::shared_ptr<const std::string> collection_group_;

  // Filters are shared across related Query instance. i.e. when you call
  // Query::Filter(f), a new Query instance is created that contains all of the
  // existing filters, plus the new one. (Both Query and Filter objects are
  // immutable.) Filters are not shared across unrelated Query instances.
  FilterList filters_;

  // A list of fields given to sort by. This does not include the implicit key
  // sort at the end.
  OrderByList explicit_order_bys_;

  // The memoized list of sort orders.
  mutable OrderByList memoized_order_bys_;

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
