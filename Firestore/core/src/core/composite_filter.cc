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

#include "Firestore/core/src/core/composite_filter.h"

#include <algorithm>
#include <utility>

#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/hashing.h"
#include "Firestore/core/src/util/string_format.h"
#include "absl/strings/str_join.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace core {

using model::FieldPath;

namespace {

using Operator = _google_firestore_v1_StructuredQuery_CompositeFilter_Operator;

const char* CanonicalName(Operator op) {
  switch (op) {
      // TODO(orquery): Replace with Operator.OR.
    case Operator::google_firestore_v1_StructuredQuery_\
CompositeFilter_Operator_OPERATOR_UNSPECIFIED:
      return "or";
    case Operator::
        google_firestore_v1_StructuredQuery_CompositeFilter_Operator_AND:
      return "and";
    default:
      UNREACHABLE();
  }
}

}  // namespace

CompositeFilter CompositeFilter::Create(
    const std::vector<std::shared_ptr<Filter>>&& filters, Operator op) {
  return CompositeFilter(
      std::make_shared<const Rep>(Rep(std::move(filters), op)));
}

CompositeFilter::CompositeFilter(std::shared_ptr<const Filter::Rep> rep)
    : Filter(std::move(rep)) {
}

CompositeFilter::Rep::Rep(const std::vector<std::shared_ptr<Filter>>&& filters,
                          Operator op)
    : filters_(std::move(filters)), op_(op) {
  for (const auto& filter_ptr : filters_) {
    std::copy(filter_ptr->GetFlattenedFilters().begin(),
              filter_ptr->GetFlattenedFilters().end(),
              std::back_inserter(flatten_filters_));
  }
}

CompositeFilter::CompositeFilter(const Filter& other) : Filter(other) {
  HARD_ASSERT(other.IsACompositeFilter());
}

bool CompositeFilter::Rep::IsConjunction() const {
  return op_ ==
         Operator::
             google_firestore_v1_StructuredQuery_CompositeFilter_Operator_AND;
}

bool CompositeFilter::Rep::IsDisjunction() const {
  // TODO(orquery): Replace with Operator.OR.
  return op_ == Operator::google_firestore_v1_StructuredQuery_\
CompositeFilter_Operator_OPERATOR_UNSPECIFIED;
}

bool CompositeFilter::Rep::Matches(const model::Document& doc) const {
  if (IsConjunction()) {
    // For conjunctions, all filters must match, so return false if any filter
    // doesn't match.
    for (const auto& filter_ptr : filters_) {
      if (!filter_ptr->Matches(doc)) {
        return false;
      }
    }
    return true;
  } else {
    // For disjunctions, at least one filter should match.
    for (const auto& filter_ptr : filters_) {
      if (filter_ptr->Matches(doc)) {
        return true;
      }
    }
    return false;
  }
}

std::string CompositeFilter::Rep::CanonicalId() const {
  // TODO(orquery): Add special case for flat AND filters.
  return util::StringFormat(
      "%s(%s)", CanonicalName(op_),
      absl::StrJoin(filters_, ",",
                    [](std::string* out, const std::shared_ptr<Filter>& f) {
                      return absl::StrAppend(out, f->CanonicalId());
                    }));
}

bool CompositeFilter::Rep::Equals(const Filter::Rep& other) const {
  if (!other.IsACompositeFilter()) return false;
  const auto& other_rep = static_cast<const CompositeFilter::Rep&>(other);
  // Note: This comparison requires order of filters in the list to be the same,
  // and it does not remove duplicate subfilters from each composite filter.
  // It is therefore way less expensive.
  // TODO(orquery): Consider removing duplicates and ignoring order of filters
  // in the list.
  return op_ == other_rep.op_ && filters_ == other_rep.filters_;
}

const std::shared_ptr<FieldFilter>
CompositeFilter::Rep::FindFirstMatchingFilter(CheckingFun& condition) const {
  for (const auto& field_filter_ptr : flatten_filters_) {
    if (condition(field_filter_ptr)) {
      return field_filter_ptr;
    }
  }
  return nullptr;
}

const model::FieldPath* CompositeFilter::Rep::GetFirstInequalityField() const {
  CheckingFun condition =
      [](const std::shared_ptr<FieldFilter>& field_filter_ptr) {
        return field_filter_ptr->IsInequality();
      };
  const std::shared_ptr<FieldFilter> found = FindFirstMatchingFilter(condition);
  if (found) {
    return &found->field();
  }
  return nullptr;
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
