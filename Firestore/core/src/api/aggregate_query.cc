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

#include "Firestore/core/src/api/aggregate_query.h"

#include <utility>

#include "Firestore/core/src/api/api_fwd.h"
#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/core/firestore_client.h"
#include "Firestore/core/src/model/aggregate_field.h"

using firebase::firestore::model::AggregateAlias;
using firebase::firestore::model::AggregateField;

namespace firebase {
namespace firestore {
namespace api {

bool operator==(const AggregateQuery& lhs, const AggregateQuery& rhs) {
  return lhs.query_ == rhs.query_ && lhs.aggregates_ == rhs.aggregates_;
}

size_t AggregateQuery::Hash() const {
  return util::Hash(query_, aggregates_);
}

AggregateQuery::AggregateQuery(Query query,
                               std::vector<AggregateField>&& aggregates)
    : query_{std::move(query)}, aggregates_{std::move(aggregates)} {
}

void AggregateQuery::GetAggregate(AggregateQueryCallback&& callback) {
  query_.firestore()->client()->RunAggregateQuery(query_.query(), aggregates_,
                                                  std::move(callback));
}

// TODO(b/280805906) Remove this count specific API after the c++ SDK migrates
// to the new Aggregate API
void AggregateQuery::Get(CountQueryCallback&& callback) {
  this->GetAggregate(
      [callback = std::move(callback)](const StatusOr<ObjectValue>& result) {
        if (!result.ok()) {
          callback(StatusOr<int64_t>(std::move(result.status())));
          return;
        }

        absl::optional<google_firestore_v1_Value> count_value =
            result.ValueOrDie().Get(AggregateAlias("count").StringValue());
        HARD_ASSERT(count_value.has_value() &&
                    count_value.value().which_value_type ==
                        google_firestore_v1_Value_integer_value_tag);
        callback(StatusOr<int64_t>(count_value->integer_value));
      });
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
