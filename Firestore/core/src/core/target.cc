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

#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/operator.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/util/equality.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/hashing.h"
#include "absl/strings/str_cat.h"

namespace firebase {
namespace firestore {
namespace core {

using model::DocumentKey;
using model::FieldPath;
using model::Segment;

namespace {

std::vector<_google_firestore_v1_Value> MakeValueVector(
    const _google_firestore_v1_ArrayValue* array) {
  std::vector<_google_firestore_v1_Value> result;

  _google_firestore_v1_Value* ptr = array->values;
  for (pb_size_t i = 0; i < array->values_count; ++i) {
    result.push_back(ptr[i]);
  }

  return result;
}

std::vector<_google_firestore_v1_Value> ValuesFrom(
    const std::unordered_map<std::string, _google_firestore_v1_Value>&
        field_value_map) {
  std::vector<_google_firestore_v1_Value> result;
  for (const auto& entry_pair : field_value_map) {
    result.push_back(entry_pair.second);
  }

  return result;
}

}  // namespace

// MARK: - Accessors

bool Target::IsDocumentQuery() const {
  return DocumentKey::IsDocumentKey(path_) && !collection_group_ &&
         filters_.empty();
}

// MARK: - Indexing support

std::vector<FieldFilter> Target::GetFieldFiltersForPath(
    const model::FieldPath& path) {
  std::vector<FieldFilter> result;
  for (const Filter& filter : filters_) {
    if (filter.IsAFieldFilter() && filter.field() == path) {
      result.push_back(FieldFilter(filter));
    }
  }
  return result;
}

IndexedValues Target::GetArrayValues(const model::FieldIndex& field_index) {
  auto segment = field_index.GetArraySegment();
  if (!segment.has_value()) return absl::nullopt;

  for (const FieldFilter& filter :
       GetFieldFiltersForPath(segment.value().field_path())) {
    switch (filter.op()) {
      case Filter::Operator::ArrayContains:
        return MakeValueVector(NOT_NULL(&(filter.value().array_value)));
      case Filter::Operator::ArrayContainsAny:
        return std::vector<_google_firestore_v1_Value>{filter.value()};
      default:
        continue;
    }
  }

  return absl::nullopt;
}

IndexedValues Target::GetNotInValues(const model::FieldIndex& field_index) {
  std::unordered_map<std::string, _google_firestore_v1_Value> field_value_map;
  for (const auto& segment : field_index.GetDirectionalSegments()) {
    for (const auto& field_filter :
         GetFieldFiltersForPath(segment.field_path())) {
      switch (field_filter.op()) {
        case Filter::Operator::Equal:
        case Filter::Operator::In:
          // Encode equality prefix, which is encoded in the index value before
          // the inequality (e.g. `a == 'a' && b != 'b'` is encoded to `value !=
          // 'ab'`).
          field_value_map[segment.field_path().CanonicalString()] =
              field_filter.value();
          break;
        case Filter::Operator::NotIn:
        case Filter::Operator::NotEqual:
          field_value_map[segment.field_path().CanonicalString()] =
              field_filter.value();
          return ValuesFrom(
              field_value_map);  // NotIn/NotEqual is always a suffix
        default:
          continue;
      }
    }
  }

  return absl::nullopt;
}

absl::optional<Bound> Target::GetLowerBound(
    const model::FieldIndex& field_index) {
  std::vector<_google_firestore_v1_Value> values;
  bool inclusive = true;

  // For each segment, retrieve a lower bound if there is a suitable filter or
  // startAt.
  for (const auto& segment : field_index.GetDirectionalSegments()) {
    auto segment_bound = segment.kind() == Segment::Kind::kAscending
                             ? GetAscendingBound(segment, start_at_)
                             : GetDescendingBound(segment, start_at_);

    if (!segment_bound.first.has_value()) {
      // No lower bound exists
      return absl::nullopt;
    }

    values.push_back(segment_bound.first.value());
    inclusive = (inclusive && segment_bound.second);
  }

  auto position =
      nanopb::MakeSharedMessage<_google_firestore_v1_ArrayValue>({});
  nanopb::SetRepeatedField(&position->values, &position->values_count, values);
  return Bound::FromValue(std::move(position), inclusive);
}

absl::optional<Bound> Target::GetUpperBound(
    const model::FieldIndex& field_index) {
  std::vector<_google_firestore_v1_Value> values;
  bool inclusive = true;

  // For each segment, retrieve an upper bound if there is a suitable filter or
  // endAt.
  for (const auto& segment : field_index.GetDirectionalSegments()) {
    auto segment_bound = segment.kind() == Segment::Kind::kAscending
                             ? GetDescendingBound(segment, end_at_)
                             : GetAscendingBound(segment, end_at_);

    if (!segment_bound.first.has_value()) {
      // No lower bound exists
      return absl::nullopt;
    }

    values.push_back(segment_bound.first.value());
    inclusive = (inclusive && segment_bound.second);
  }

  auto position =
      nanopb::MakeSharedMessage<_google_firestore_v1_ArrayValue>({});
  nanopb::SetRepeatedField(&position->values, &position->values_count, values);
  return Bound::FromValue(std::move(position), inclusive);
}

std::pair<absl::optional<_google_firestore_v1_Value>, bool>
Target::GetAscendingBound(const Segment& segment,
                          const absl::optional<Bound>& bound) {
  absl::optional<_google_firestore_v1_Value> segment_value;
  bool segment_inclusive = true;

  // Process all filters to find a value for the current field segment
  for (const auto& field_filter :
       GetFieldFiltersForPath(segment.field_path())) {
    absl::optional<_google_firestore_v1_Value> filter_value;
    bool filter_inclusive = true;

    switch (field_filter.op()) {
      case Filter::Operator::LessThan:
      case Filter::Operator::LessThanOrEqual:
        filter_value =
            *model::GetLowerBound(field_filter.value().which_value_type);
        break;
      case Filter::Operator::Equal:
      case Filter::Operator::In:
      case Filter::Operator::GreaterThanOrEqual:
        filter_value = field_filter.value();
        break;
      case Filter::Operator::GreaterThan:
        filter_value = field_filter.value();
        filter_inclusive = false;
        break;
      case Filter::Operator::NotEqual:
      case Filter::Operator::NotIn:
        filter_value = *model::MinValue();
        break;
      default:
        continue;
        // Remaining filters cannot be used as bound.
    }

    // Set segment_value to max(segment_value, filter_value)
    if (model::Compare(segment_value, filter_value) ==
        util::ComparisonResult::Ascending) {
      segment_value = filter_value;
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
        if (model::Compare(segment_value, cursor_value) ==
            util::ComparisonResult::Ascending) {
          segment_value = cursor_value;
          segment_inclusive = bound.value().before();
        }
      }
    }
  }

  return {std::move(segment_value), segment_inclusive};
}

std::pair<absl::optional<_google_firestore_v1_Value>, bool>
Target::GetDescendingBound(const Segment& segment,
                           const absl::optional<Bound>& bound) {
  absl::optional<_google_firestore_v1_Value> segment_value;
  bool segment_inclusive = true;

  // Process all filters to find a value for the current field segment
  for (const auto& field_filter :
       GetFieldFiltersForPath(segment.field_path())) {
    absl::optional<_google_firestore_v1_Value> filter_value;
    bool filter_inclusive = true;

    switch (field_filter.op()) {
      case Filter::Operator::GreaterThanOrEqual:
      case Filter::Operator::GreaterThan:
        filter_value =
            *model::GetUpperBound(field_filter.value().which_value_type);
        filter_inclusive = false;
        break;
      case Filter::Operator::Equal:
      case Filter::Operator::In:
      case Filter::Operator::LessThanOrEqual:
        filter_value = field_filter.value();
        break;
      case Filter::Operator::LessThan:
        filter_value = field_filter.value();
        filter_inclusive = false;
        break;
      case Filter::Operator::NotIn:
      case Filter::Operator::NotEqual:
        filter_value = *model::MaxValue();
        break;
      default:
        continue;
        // Remaining filters cannot be used as bound.
    }

    // Set segment_value to min(segment_value, filter_value)
    if (model::Compare(segment_value, filter_value) ==
        util::ComparisonResult::Descending) {
      segment_value = filter_value;
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
        if (model::Compare(segment_value, cursor_value) ==
            util::ComparisonResult::Descending) {
          segment_value = cursor_value;
          segment_inclusive = bound.value().before();
        }
      }
    }
  }

  return {std::move(segment_value), segment_inclusive};
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
    absl::StrAppend(&result, "|lb:", start_at_->CanonicalId());
  }

  if (end_at_) {
    absl::StrAppend(&result, "|ub:", end_at_->CanonicalId());
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
