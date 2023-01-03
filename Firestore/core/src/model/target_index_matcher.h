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

#ifndef FIRESTORE_CORE_SRC_MODEL_TARGET_INDEX_MATCHER_H_
#define FIRESTORE_CORE_SRC_MODEL_TARGET_INDEX_MATCHER_H_

#include <string>
#include <vector>

#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/order_by.h"
#include "Firestore/core/src/core/target.h"
#include "Firestore/core/src/model/field_index.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace model {

/**
 * A light query planner for Firestore.
 *
 * This class matches a `FieldIndex` against a Firestore Query `Target`. It
 * determines whether a given index can be used to serve the specified target.
 *
 * The following table showcases some possible index configurations:
 *
 * Query                                               | Index
 * -----------------------------------------------------------------------------
 * where('a', '==', 'a').where('b', '==', 'b')         | a ASC, b DESC
 * where('a', '==', 'a').where('b', '==', 'b')         | a ASC
 * where('a', '==', 'a').where('b', '==', 'b')         | b DESC
 * where('a', '>=', 'a').orderBy('a')                  | a ASC
 * where('a', '>=', 'a').orderBy('a', 'desc')          | a DESC
 * where('a', '>=', 'a').orderBy('a').orderBy('b')     | a ASC, b ASC
 * where('a', '>=', 'a').orderBy('a').orderBy('b')     | a ASC
 * where('a', 'array-contains', 'a').orderBy('b')      | a CONTAINS, b ASCENDING
 * where('a', 'array-contains', 'a').orderBy('b')      | a CONTAINS
 */
class TargetIndexMatcher {
 public:
  explicit TargetIndexMatcher(const core::Target& target);

  /**
   * Returns whether the index can be used to serve the TargetIndexMatcher's
   * target.
   *
   * An index is considered capable of serving the target when:
   * - The target uses all index segments for its filters and OrderBy clauses.
   *   The target can have additional filter and OrderBy clauses, but not
   *   fewer.
   * - If an ArrayContains/ArrayContainsAny is used, the index must also
   *   have a corresponding `kContains` segment.
   * - All directional index segments can be mapped to the target as a series of
   *   equality filters, a single inequality filter and a series of OrderBy
   *   clauses.
   * - The segments that represent the equality filters may appear out of order.
   * - The optional segment for the inequality filter must appear after all
   *   equality segments.
   * - The segments that represent that OrderBy clause of the target must appear
   *   in order after all equality and inequality segments. Single OrderBy
   *   clauses cannot be skipped, but a continuous OrderBy suffix may be
   *   omitted.
   */
  bool ServedByIndex(const model::FieldIndex& index);

 private:
  bool HasMatchingEqualityFilter(const model::Segment& segment);

  bool MatchesFilter(const core::FieldFilter& filter,
                     const model::Segment& segment);
  bool MatchesFilter(const absl::optional<core::FieldFilter>& filter,
                     const model::Segment& segment);

  bool MatchesOrderBy(const core::OrderBy& order_by,
                      const model::Segment& segment);

  // The collection ID (or collection group) of the query target.
  std::string collection_id_;

  absl::optional<core::FieldFilter> inequality_filter_;
  std::vector<core::FieldFilter> equality_filters_;
  std::vector<core::OrderBy> order_bys_;
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_MODEL_TARGET_INDEX_MATCHER_H_
