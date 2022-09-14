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

#include "Firestore/core/src/api/query_core.h"

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
  explicit AggregateQuery(Query query);

  const Query& query() const {
    return query_;
  }

  void Get(CountQueryCallback&& callback);

 private:
  Query query_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_AGGREGATE_QUERY_H_
