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

#include "Firestore/core/src/core/target.h"

#include <ostream>
#include <set>
#include <unordered_map>
#include <vector>

#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/util/equality.h"
#include "Firestore/core/src/util/hashing.h"
#include "Firestore/core/src/util/maps.h"
#include "absl/strings/str_cat.h"

namespace firebase {
namespace firestore {
namespace core {

using model::DocumentKey;
using model::FieldPath;
using model::Segment;
using util::MapWithInsertionOrder;

namespace {

// Copies the values of `array` into a `std::vector`.
std::vector<google_firestore_v1_Value> MakeValueVector(
    google_firestore_v1_ArrayValue array) {
  std::vector<google_firestore_v1_Value> result;

  for (pb_size_t i = 0; i < array.values_count; ++i) {
    result.push_back(array.values[i]);
  }

  return result;
}

}  // namespace

// MARK: - Accessors

bool Target::IsDocumentQuery() const {
  return DocumentKey::IsDocumentKey(path_) && !collection_group_ &&
         filters_.empty();
}

size_t Target::GetSegmentCount() const {
  std::set<FieldPath> fields;
  bool has_array_segment = false;
  for (const Filter& filter : filters_) {
    for (const FieldFilter& sub_filter : filter.GetFlattenedFilters()) {
      // __name__ is not an explicit segment of any index, so we don't need to
      // count it.
      if (sub_filter.field().IsKeyFieldPath()) {
        continue;
      }

      // ARRAY_CONTAINS or ARRAY_CONTAINS_ANY filters must be counted
      // separately. For instance, it is possible to have an index for "a ARRAY
      // a ASC". Even though these are on the same field, they should be counted
      // as two separate segments in an index.
      if (sub_filter.op() == FieldFilter::Operator::ArrayContains ||
          sub_filter.op() == FieldFilter::Operator::ArrayContainsAny) {
        has_array_segment = true;
      } else {
        fields.insert(sub_filter.field());
      }
    }
  }
  for (const auto& order_by : order_bys_) {
    // __name__ is not an explicit segment of any index, so we don't need to
    // count it.
    if (!order_by.field().IsKeyFieldPath()) {
      fields.insert(order_by.field());
    }
  }
  return fields.size() + (has_array_segment ? 1 : 0);
}

std::vector<FieldFilter> Target::GetFieldFiltersForPath(
    const model::FieldPath& path) const {
  std::vector<FieldFilter> result;
  for (const Filter& filter : filters_) {
    if (filter.IsAFieldFilter()) {
      FieldFilter field_filter(filter);
      if (field_filter.field() != path) {
        continue;
      }
      result.push_back(std::move(field_filter));
    }
  }

  return result;
}

IndexedValues Target::GetArrayValues(
    const model::FieldIndex& field_index) const {
  auto segment = field_index.GetArraySegment();
  if (!segment.has_value()) return absl::nullopt;

  for (const FieldFilter& filter :
       GetFieldFiltersForPath(segment.value().field_path())) {
    switch (filter.op()) {
      case FieldFilter::Operator::ArrayContainsAny: {
        return MakeValueVector(filter.value().array_value);
      }
      case FieldFilter::Operator::ArrayContains: {
        std::vector<google_firestore_v1_Value> result;
        result.push_back(filter.value());
        return result;
      }
      default:
        continue;
    }
  }

  return absl::nullopt;
}

IndexedValues Target::GetNotInValues(
    const model::FieldIndex& field_index) const {
  MapWithInsertionOrder<std::string, google_firestore_v1_Value> field_value_map;
  for (const auto& segment : field_index.GetDirectionalSegments()) {
    for (const auto& field_filter :
         GetFieldFiltersForPath(segment.field_path())) {
      switch (field_filter.op()) {
        case FieldFilter::Operator::Equal:
        case FieldFilter::Operator::In:
          // Encode equality prefix, which is encoded in the index value before
          // the inequality (e.g. `a == 'a' && b != 'b'` is encoded to `value !=
          // 'ab'`).
          field_value_map.Put(segment.field_path().CanonicalString(),
                              field_filter.value());
          break;
        case FieldFilter::Operator::NotIn:
        case FieldFilter::Operator::NotEqual:
          field_value_map.Put(segment.field_path().CanonicalString(),
                              field_filter.value());
          return field_value_map
              .ConsumeValues();  // NotIn/NotEqual is always a suffix
        default:
          continue;
      }
    }
  }

  return absl::nullopt;
}

IndexBoundValues Target::GetLowerBound(
    const model::FieldIndex& field_index) const {
  std::vector<google_firestore_v1_Value> values;
  bool inclusive = true;

  // For each segment, retrieve a lower bound if there is a suitable filter or
  // startAt.
  for (const auto& segment : field_index.GetDirectionalSegments()) {
    auto segment_bound = segment.kind() == Segment::Kind::kAscending
                             ? GetAscendingBound(segment, start_at_)
                             : GetDescendingBound(segment, start_at_);

    values.push_back(std::move(segment_bound.value));
    inclusive = (inclusive && segment_bound.inclusive);
  }

  return IndexBoundValues{inclusive, std::move(values)};
}

IndexBoundValues Target::GetUpperBound(
    const model::FieldIndex& field_index) const {
  std::vector<google_firestore_v1_Value> values;
  bool inclusive = true;

  // For each segment, retrieve an upper bound if there is a suitable filter or
  // endAt.
  for (const auto& segment : field_index.GetDirectionalSegments()) {
    auto segment_bound = segment.kind() == Segment::Kind::kAscending
                             ? GetDescendingBound(segment, end_at_)
                             : GetAscendingBound(segment, end_at_);

    values.push_back(std::move(segment_bound.value));
    inclusive = (inclusive && segment_bound.inclusive);
  }

  return IndexBoundValues{inclusive, std::move(values)};
}

Target::IndexBoundValue Target::GetAscendingBound(
    const Segment& segment, const absl::optional<Bound>& bound) const {
  google_firestore_v1_Value segment_value = model::MinValue();
  bool segment_inclusive = true;

  // Process all filters to find a value for the current field segment
  for (const auto& field_filter :
       GetFieldFiltersForPath(segment.field_path())) {
    google_firestore_v1_Value filter_value = model::MinValue();
    bool filter_inclusive = true;

    switch (field_filter.op()) {
      case FieldFilter::Operator::LessThan:
      case FieldFilter::Operator::LessThanOrEqual:
        filter_value = model::GetLowerBound(field_filter.value());
        break;
      case FieldFilter::Operator::Equal:
      case FieldFilter::Operator::In:
      case FieldFilter::Operator::GreaterThanOrEqual:
        filter_value = field_filter.value();
        break;
      case FieldFilter::Operator::GreaterThan:
        filter_value = field_filter.value();
        filter_inclusive = false;
        break;
      case FieldFilter::Operator::NotEqual:
      case FieldFilter::Operator::NotIn:
        filter_value = model::MinValue();
        break;
      default:
        // Remaining filters cannot be used as bound.
        continue;
    }

    // Increase segment_value to filter_value if filter_value is larger.
    if (model::LowerBoundCompare(segment_value, segment_inclusive, filter_value,
                                 filter_inclusive) ==
        util::ComparisonResult::Ascending) {
      segment_value = std::move(filter_value);
      segment_inclusive = filter_inclusive;
    }
  }

  // If there is an additional bound, compare the values against the existing
  // range to see if we can narrow the scope.
  if (bound.has_value()) {
    for (size_t i = 0; i < order_bys_.size(); ++i) {
      const auto& order_by = order_bys_[i];
      if (order_by.field() == segment.field_path()) {
        auto cursor_value = bound.value().position()->values[i];
        // Increase segment_value to cursor_value if cursor_value is larger.
        if (model::LowerBoundCompare(segment_value, segment_inclusive,
                                     cursor_value, bound.value().inclusive()) ==
            util::ComparisonResult::Ascending) {
          segment_value = cursor_value;
          segment_inclusive = bound.value().inclusive();
        }
      }
    }
  }

  return Target::IndexBoundValue{segment_inclusive, std::move(segment_value)};
}

Target::IndexBoundValue Target::GetDescendingBound(
    const Segment& segment, const absl::optional<Bound>& bound) const {
  google_firestore_v1_Value segment_value = model::MaxValue();
  bool segment_inclusive = true;

  // Process all filters to find a value for the current field segment
  for (const auto& field_filter :
       GetFieldFiltersForPath(segment.field_path())) {
    google_firestore_v1_Value filter_value = model::MaxValue();
    bool filter_inclusive = true;

    switch (field_filter.op()) {
      case FieldFilter::Operator::GreaterThanOrEqual:
      case FieldFilter::Operator::GreaterThan:
        filter_value = model::GetUpperBound(field_filter.value());
        filter_inclusive = false;
        break;
      case FieldFilter::Operator::Equal:
      case FieldFilter::Operator::In:
      case FieldFilter::Operator::LessThanOrEqual:
        filter_value = field_filter.value();
        break;
      case FieldFilter::Operator::LessThan:
        filter_value = field_filter.value();
        filter_inclusive = false;
        break;
      case FieldFilter::Operator::NotIn:
      case FieldFilter::Operator::NotEqual:
        filter_value = model::MaxValue();
        break;
      default:
        // Remaining filters cannot be used as bound.
        continue;
    }

    // Decrease segment_value to filter_value if filter_value is smaller.
    if (model::UpperBoundCompare(segment_value, segment_inclusive, filter_value,
                                 filter_inclusive) ==
        util::ComparisonResult::Descending) {
      segment_value = std::move(filter_value);
      segment_inclusive = filter_inclusive;
    }
  }

  // If there is an additional bound, compare the values against the existing
  // range to see if we can narrow the scope.
  if (bound.has_value()) {
    for (size_t i = 0; i < order_bys_.size(); ++i) {
      const auto& order_by = order_bys_[i];
      if (order_by.field() == segment.field_path()) {
        auto cursor_value = bound.value().position()->values[i];
        // Decrease segment_value to cursor_value if cursor_value is smaller.
        if (model::UpperBoundCompare(segment_value, segment_inclusive,
                                     cursor_value, bound.value().inclusive()) ==
            util::ComparisonResult::Descending) {
          segment_value = cursor_value;
          segment_inclusive = bound.value().inclusive();
        }
      }
    }
  }

  return IndexBoundValue{segment_inclusive, std::move(segment_value)};
}

// MARK: - Utilities
const std::string& Target::CanonicalId() const {
  if (!canonical_id_.empty()) return canonical_id_;

  std::string result;
  absl::StrAppend(&result, path_.CanonicalString());

  if (collection_group_) {
    absl::StrAppend(&result, "|cg:", *collection_group_);
  }

  // Add filters.
  absl::StrAppend(&result, "|f:");
  for (const auto& filter : filters_) {
    absl::StrAppend(&result, filter.CanonicalId());
  }

  // Add order by.
  absl::StrAppend(&result, "|ob:");
  for (const OrderBy& order_by : order_bys()) {
    absl::StrAppend(&result, order_by.CanonicalId());
  }

  // Add limit.
  if (limit_ != kNoLimit) {
    absl::StrAppend(&result, "|l:", limit_);
  }

  if (start_at_) {
    absl::StrAppend(&result, start_at_->inclusive() ? "|lb:b:" : "|lb:a:");
    absl::StrAppend(&result, start_at_->PositionString());
  }

  if (end_at_) {
    absl::StrAppend(&result, end_at_->inclusive() ? "|ub:a:" : "|ub:b:");
    absl::StrAppend(&result, end_at_->PositionString());
  }

  canonical_id_ = std::move(result);
  return canonical_id_;
}

size_t Target::Hash() const {
  return util::Hash(CanonicalId());
}

std::string Target::ToString() const {
  return absl::StrCat("Target(canonical_id=", CanonicalId(), ")");
}

std::ostream& operator<<(std::ostream& os, const Target& target) {
  return os << target.ToString();
}

bool operator==(const Target& lhs, const Target& rhs) {
  return lhs.path() == rhs.path() &&
         util::Equals(lhs.collection_group(), rhs.collection_group()) &&
         lhs.filters() == rhs.filters() && lhs.order_bys() == rhs.order_bys() &&
         lhs.limit() == rhs.limit() && lhs.start_at() == rhs.start_at() &&
         lhs.end_at() == rhs.end_at();
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
