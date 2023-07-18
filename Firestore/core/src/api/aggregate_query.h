/*
 * Copyright 2022 Google LLC
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
#ifndef FIRESTORE_CORE_SRC_API_AGGREGATE_QUERY_H_
#define FIRESTORE_CORE_SRC_API_AGGREGATE_QUERY_H_

#include <vector>

#include "Firestore/core/src/api/query_core.h"

using firebase::firestore::model::AggregateField;

namespace firebase {
namespace firestore {
namespace api {

/**
 * An `AggregateQuery` is built from a Firestore Query. It returns some
 * aggregations on the potential result set, instead of all documents matching
 * the query.
 */
class AggregateQuery {
 public:
  explicit AggregateQuery(Query query,
                          std::vector<AggregateField>&& aggregates);

  // TODO(b/280805906) this destructor is marked as virtual because this class
  // is mocked in api/aggregate_query_test.cc. The virtual keyword can be
  // removed when the tests and mocking are removed.
  virtual ~AggregateQuery() = default;

  const Query& query() const {
    return query_;
  }

  friend bool operator==(const AggregateQuery& lhs, const AggregateQuery& rhs);
  size_t Hash() const;

  // TODO(b/280805906) this method is marked as virtual to allow mocking
  // in api/aggregate_query_test.cc. The virtual keyword can be removed
  // when the tests and mocking are removed.
  virtual void GetAggregate(AggregateQueryCallback&& callback);

  // TODO(b/280805906) Remove this count specific API after the c++ SDK migrates
  // to the new Aggregate API Backward-compatible getter for count result
  void Get(CountQueryCallback&& callback);

 private:
  friend class AggregateQueryTest;
  Query query_;
  std::vector<AggregateField> aggregates_;
};

bool operator==(const AggregateQuery& lhs, const AggregateQuery& rhs);

inline bool operator!=(const AggregateQuery& lhs, const AggregateQuery& rhs) {
  return !(lhs == rhs);
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_AGGREGATE_QUERY_H_
