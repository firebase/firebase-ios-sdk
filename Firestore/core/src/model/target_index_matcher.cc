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

#include "Firestore/core/src/model/target_index_matcher.h"

#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace model {

using core::FieldFilter;
using core::Filter;
using core::OrderBy;
using core::Target;

TargetIndexMatcher::TargetIndexMatcher(const core::Target& target) {
  collection_id_ = target.collection_group() != nullptr
                       ? *target.collection_group()
                       : target.path().last_segment();
  order_bys_ = target.order_bys();
  inequality_filter_ = absl::nullopt;

  for (const Filter& filter : target.filters()) {
    FieldFilter field_filter(filter);
    if (field_filter.IsInequality()) {
      HARD_ASSERT(!inequality_filter_.has_value() ||
                      inequality_filter_->field() == field_filter.field(),
                  "Only a single inequality is supported");
      inequality_filter_ = field_filter;
    } else {
      equality_filters_.push_back(field_filter);
    }
  }
}

bool TargetIndexMatcher::ServedByIndex(const model::FieldIndex& index) {
  HARD_ASSERT(index.collection_group() == collection_id_,
              "Collection IDs do not match");

  // If there is an array element, find a matching filter.
  const auto& array_segment = index.GetArraySegment();
  if (array_segment.has_value() &&
      !HasMatchingEqualityFilter(array_segment.value())) {
    return false;
  }

  std::vector<Segment> segments = index.GetDirectionalSegments();
  size_t segment_index = 0;
  // Process all equalities first. Equalities can appear out of order.
  for (; segment_index < segments.size(); ++segment_index) {
    // We attempt to greedily match all segments to equality filters. If a
    // filter matches an index segment, we can mark the segment as used. Since
    // it is not possible to use the same field path in both an equality and
    // inequality/oderBy clause, we do not have to consider the possibility that
    // a matching equality segment should instead be used to map to an
    // inequality filter or orderBy clause.
    if (!HasMatchingEqualityFilter(segments[segment_index])) {
      // If we cannot find a matching filter, we need to verify whether the
      // remaining segments map to the target's inequality and its orderBy
      // clauses.
      break;
    }
  }

  // If we already have processed all segments, all segments are used to serve
  // the equality filters and we do not need to map any segments to the target's
  // inequality and orderBy clauses.
  if (segment_index == segments.size()) {
    return true;
  }

  // `order_bys_` has at least one element.
  auto order_by_iter = order_bys_.begin();

  // If there is an inequality filter, the next segment must match both the
  // filter and the first OrderBy clause.
  if (inequality_filter_.has_value()) {
    if (!MatchesFilter(inequality_filter_, segments[segment_index]) ||
        !MatchesOrderBy(*order_by_iter, segments[segment_index])) {
      return false;
    }
    ++order_by_iter;
    ++segment_index;
  }

  // All remaining segments need to represent the prefix of the target's
  // OrderBy.
  for (; segment_index < segments.size(); ++segment_index) {
    if (order_by_iter == order_bys_.end() ||
        !MatchesOrderBy(*order_by_iter, segments[segment_index])) {
      return false;
    }
    ++order_by_iter;
  }

  return true;
}

bool TargetIndexMatcher::HasMatchingEqualityFilter(const Segment& segment) {
  for (const auto& filter : equality_filters_) {
    if (MatchesFilter(filter, segment)) {
      return true;
    }
  }
  return false;
}

bool TargetIndexMatcher::MatchesFilter(
    const absl::optional<core::FieldFilter>& filter, const Segment& segment) {
  if (!filter.has_value()) {
    return false;
  }
  return MatchesFilter(filter.value(), segment);
}

bool TargetIndexMatcher::MatchesFilter(const FieldFilter& filter,
                                       const Segment& segment) {
  if (filter.field() != segment.field_path()) {
    return false;
  }

  bool is_array_op = filter.op() == FieldFilter::Operator::ArrayContains ||
                     filter.op() == FieldFilter::Operator::ArrayContainsAny;
  return (segment.kind() == Segment::kContains) == is_array_op;
}

bool TargetIndexMatcher::MatchesOrderBy(const OrderBy& order_by,
                                        const Segment& segment) {
  if (order_by.field() != segment.field_path()) {
    return false;
  }
  return (segment.kind() == Segment::kAscending &&
          order_by.direction() == core::Direction::Ascending) ||
         (segment.kind() == Segment::kDescending &&
          order_by.direction() == core::Direction::Descending);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
