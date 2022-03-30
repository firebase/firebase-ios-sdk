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
#include "absl/strings/str_cat.h"

namespace firebase {
namespace firestore {
namespace core {

using model::DocumentKey;
using model::FieldPath;
using model::Segment;

namespace {

// Takes the ownership of the given array value message, converting it to a
// vector of value messages.
std::vector<google_firestore_v1_Value> MakeValueVector(
    google_firestore_v1_ArrayValue array) {
  std::vector<google_firestore_v1_Value> result;

  for (pb_size_t i = 0; i < array.values_count; ++i) {
    result.push_back(array.values[i]);
  }

  return result;
}

// Moves the values from the given unordred_map into the resulting vector.
std::vector<google_firestore_v1_Value> ValuesFrom(
    std::unordered_map<std::string,
                       nanopb::Message<google_firestore_v1_Value>>&&
        field_value_map) {
  std::vector<google_firestore_v1_Value> result;
  for (auto& entry_pair : field_value_map) {
    result.push_back(*entry_pair.second);
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
      case FieldFilter::Operator::ArrayContains: {
        std::vector<google_firestore_v1_Value> result;
        result.push_back(filter.value());
        return result;
      }
      case FieldFilter::Operator::ArrayContainsAny: {
        return MakeValueVector(filter.value().array_value);
      }
      default:
        continue;
    }
  }

  return absl::nullopt;
}

IndexedValues Target::GetNotInValues(const model::FieldIndex& field_index) {
  std::unordered_map<std::string, nanopb::Message<google_firestore_v1_Value>>
      field_value_map;
  for (const auto& segment : field_index.GetDirectionalSegments()) {
    for (const auto& field_filter :
         GetFieldFiltersForPath(segment.field_path())) {
      switch (field_filter.op()) {
        case FieldFilter::Operator::Equal:
        case FieldFilter::Operator::In:
          // Encode equality prefix, which is encoded in the index value before
          // the inequality (e.g. `a == 'a' && b != 'b'` is encoded to `value !=
          // 'ab'`).
          field_value_map[segment.field_path().CanonicalString()] =
              model::DeepClone(field_filter.value());
          break;
        case FieldFilter::Operator::NotIn:
        case FieldFilter::Operator::NotEqual:
          field_value_map[segment.field_path().CanonicalString()] =
              model::DeepClone(field_filter.value());
          return ValuesFrom(
              std::move(field_value_map));  // NotIn/NotEqual is always a suffix
        default:
          continue;
      }
    }
  }

  return absl::nullopt;
}

absl::optional<Bound> Target::GetLowerBound(
    const model::FieldIndex& field_index) {
  std::vector<nanopb::Message<google_firestore_v1_Value>> messages;
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

    messages.push_back(std::move(segment_bound.first.value()));
    inclusive = (inclusive && segment_bound.second);
  }

  // Give up message ownership and move `google_firestore_v1_Value` into
  // `values`. Their ownership will be assumed by `position` below.
  std::vector<google_firestore_v1_Value> values;
  for (auto& message : messages) {
    values.push_back(std::move(*message.release()));
  }

  auto position =
      nanopb::MakeSharedMessage<google_firestore_v1_ArrayValue>({});
  nanopb::SetRepeatedField(&position->values, &position->values_count, values);
  return Bound::FromValue(std::move(position), inclusive);
}

absl::optional<Bound> Target::GetUpperBound(
    const model::FieldIndex& field_index) {
  std::vector<nanopb::Message<google_firestore_v1_Value>> messages;
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

    messages.push_back(std::move(segment_bound.first.value()));
    inclusive = (inclusive && segment_bound.second);
  }

  // Give up message ownership and move `google_firestore_v1_Value` into
  // `values`. Their ownership will be assumed by `position` below.
  std::vector<google_firestore_v1_Value> values;
  for (auto& message : messages) {
    values.push_back(std::move(*message.release()));
  }

  auto position =
      nanopb::MakeSharedMessage<google_firestore_v1_ArrayValue>({});
  nanopb::SetRepeatedField(&position->values, &position->values_count, values);
  return Bound::FromValue(std::move(position), inclusive);
}

IndexedBoundValue Target::GetAscendingBound(
    const Segment& segment, const absl::optional<Bound>& bound) {
  absl::optional<nanopb::Message<google_firestore_v1_Value>> segment_value;
  bool segment_inclusive = true;

  // Process all filters to find a value for the current field segment
  for (const auto& field_filter :
       GetFieldFiltersForPath(segment.field_path())) {
    absl::optional<nanopb::Message<google_firestore_v1_Value>> filter_value;
    bool filter_inclusive = true;

    switch (field_filter.op()) {
      case FieldFilter::Operator::LessThan:
      case FieldFilter::Operator::LessThanOrEqual:
        filter_value =
            model::GetLowerBound(field_filter.value().which_value_type);
        break;
      case FieldFilter::Operator::Equal:
      case FieldFilter::Operator::In:
      case FieldFilter::Operator::GreaterThanOrEqual:
        filter_value = model::DeepClone(field_filter.value());
        break;
      case FieldFilter::Operator::GreaterThan:
        filter_value = model::DeepClone(field_filter.value());
        filter_inclusive = false;
        break;
      case FieldFilter::Operator::NotEqual:
      case FieldFilter::Operator::NotIn:
        filter_value = model::MinValue();
        break;
      default:
        continue;
        // Remaining filters cannot be used as bound.
    }

    // Set segment_value to max(segment_value, filter_value)
    if (filter_value.has_value()) {
      if (!segment_value.has_value() ||
          (model::Compare(*segment_value.value(), *filter_value.value()) ==
           util::ComparisonResult::Ascending)) {
        segment_value = std::move(filter_value);
        segment_inclusive = filter_inclusive;
      }
    }
  }

  // If there is an additional bound, compare the values against the existing
  // range to see if we can narrow the scope.
  if (bound.has_value()) {
    for (size_t i = 0; i < order_bys_.size(); ++i) {
      const auto& order_by = order_bys_[i];
      if (order_by.field() == segment.field_path()) {
        auto cursor_value = bound.value().position()->values[i];
        if (!segment_value.has_value() ||
            model::Compare(*segment_value.value(), cursor_value) ==
                util::ComparisonResult::Ascending) {
          auto cloned_message = model::DeepClone(cursor_value);
          segment_value = std::move(cloned_message);
          segment_inclusive = bound.value().inclusive();
        }
      }
    }
  }

  return {std::move(segment_value), segment_inclusive};
}

IndexedBoundValue Target::GetDescendingBound(
    const Segment& segment, const absl::optional<Bound>& bound) {
  absl::optional<nanopb::Message<google_firestore_v1_Value>> segment_value;
  bool segment_inclusive = true;

  // Process all filters to find a value for the current field segment
  for (const auto& field_filter :
       GetFieldFiltersForPath(segment.field_path())) {
    absl::optional<nanopb::Message<google_firestore_v1_Value>> filter_value;
    bool filter_inclusive = true;

    switch (field_filter.op()) {
      case FieldFilter::Operator::GreaterThanOrEqual:
      case FieldFilter::Operator::GreaterThan:
        filter_value =
            model::GetUpperBound(field_filter.value().which_value_type);
        filter_inclusive = false;
        break;
      case FieldFilter::Operator::Equal:
      case FieldFilter::Operator::In:
      case FieldFilter::Operator::LessThanOrEqual:
        filter_value = model::DeepClone(field_filter.value());
        break;
      case FieldFilter::Operator::LessThan:
        filter_value = model::DeepClone(field_filter.value());
        filter_inclusive = false;
        break;
      case FieldFilter::Operator::NotIn:
      case FieldFilter::Operator::NotEqual:
        filter_value = model::MaxValue();
        break;
      default:
        continue;
        // Remaining filters cannot be used as bound.
    }

    // Set segment_value to min(segment_value, filter_value)
    if (filter_value.has_value()) {
      if (!segment_value.has_value() ||
          (model::Compare(*segment_value.value(), *filter_value.value()) ==
           util::ComparisonResult::Descending)) {
        segment_value = std::move(filter_value);
        segment_inclusive = filter_inclusive;
      }
    }
  }

  // If there is an additional bound, compare the values against the existing
  // range to see if we can narrow the scope.
  if (bound.has_value()) {
    for (size_t i = 0; i < order_bys_.size(); ++i) {
      const auto& order_by = order_bys_[i];
      if (order_by.field() == segment.field_path()) {
        auto cursor_value = bound.value().position()->values[i];
        if (!segment_value.has_value() ||
            model::Compare(*segment_value.value(), cursor_value) ==
                util::ComparisonResult::Descending) {
          segment_value = model::DeepClone(cursor_value);
          segment_inclusive = bound.value().inclusive();
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
