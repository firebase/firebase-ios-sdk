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
#include "Firestore/core/src/util/string_format.h"
#include "absl/strings/str_join.h"

namespace firebase {
namespace firestore {
namespace core {

using model::FieldPath;

namespace {

const char* CanonicalName(CompositeFilter::Operator op) {
  switch (op) {
    case CompositeFilter::Operator::Or:
      return "or";
    case CompositeFilter::Operator::And:
      return "and";
    default:
      UNREACHABLE();
  }
}

}  // namespace

CompositeFilter CompositeFilter::Create(std::vector<Filter>&& filters,
                                        Operator op) {
  return CompositeFilter(
      std::make_shared<const Rep>(Rep(std::move(filters), op)));
}

CompositeFilter::CompositeFilter(std::shared_ptr<const Filter::Rep>&& rep)
    : Filter(std::move(rep)) {
}

CompositeFilter::Rep::Rep(std::vector<Filter>&& filters, Operator op)
    : filters_(std::move(filters)), op_(op) {
}

CompositeFilter::CompositeFilter(const Filter& other) : Filter(other) {
  HARD_ASSERT(other.IsACompositeFilter());
}

bool CompositeFilter::Rep::IsConjunction() const {
  return op_ == Operator::And;
}

bool CompositeFilter::Rep::IsDisjunction() const {
  return op_ == Operator::Or;
}

bool CompositeFilter::Rep::IsFlat() const {
  return std::all_of(
      filters_.cbegin(), filters_.cend(),
      [](const Filter& filter) { return filter.IsAFieldFilter(); });
}

bool CompositeFilter::Rep::Matches(const model::Document& doc) const {
  if (IsConjunction()) {
    // For conjunctions, all filters must match, so return false if any filter
    // doesn't match.
    return std::all_of(
        filters_.cbegin(), filters_.cend(),
        [&doc](const Filter& filter) { return filter.Matches(doc); });
  } else {
    // For disjunctions, at least one filter should match.
    return std::any_of(
        filters_.cbegin(), filters_.cend(),
        [&doc](const Filter& filter) { return filter.Matches(doc); });
  }
}

std::string CompositeFilter::Rep::CanonicalId() const {
  // Older SDK versions use an implicit AND operation between their filters. In
  // the new SDK versions, the developer may use an explicit AND filter. To stay
  // consistent with the old usages, we add a special case to ensure the
  // canonical ID for these two are the same. For example: `col.whereEquals("a",
  // 1).whereEquals("b", 2)` should have the same canonical ID as
  // `col.where(and(equals("a",1), equals("b",2)))`.
  if (IsFlatConjunction()) {
    return absl::StrJoin(filters_, "", [](std::string* out, const Filter& f) {
      return absl::StrAppend(out, f.CanonicalId());
    });
  }

  return util::StringFormat(
      "%s(%s)", CanonicalName(op_),
      absl::StrJoin(filters_, ",", [](std::string* out, const Filter& f) {
        return absl::StrAppend(out, f.CanonicalId());
      }));
}

bool CompositeFilter::Rep::Equals(const Filter::Rep& other) const {
  if (!other.IsACompositeFilter()) return false;
  const auto& other_rep = static_cast<const CompositeFilter::Rep&>(other);
  // Note: This comparison requires order of filters in the list to be the same,
  // and it does not remove duplicate subfilters from each composite filter.
  // It is therefore way less expensive.
  // in the list.
  return op_ == other_rep.op_ && filters_ == other_rep.filters_;
}

CompositeFilter CompositeFilter::WithAddedFilters(
    const std::vector<core::Filter>& other_filters) {
  std::vector<Filter> merged_filters(filters());
  merged_filters.insert(merged_filters.end(), other_filters.begin(),
                        other_filters.end());
  return CompositeFilter::Create(std::move(merged_filters), op());
}

const FieldFilter* CompositeFilter::Rep::FindFirstMatchingFilter(
    const CheckFunction& condition) const {
  for (const auto& field_filter : GetFlattenedFilters()) {
    if (condition(field_filter)) {
      return &field_filter;
    }
  }
  return nullptr;
}

const std::vector<FieldFilter>& CompositeFilter::Rep::GetFlattenedFilters()
    const {
  return memoized_flattened_filters_->memoize([&]() {
    std::vector<FieldFilter> flattened_filters;
    for (const auto& filter : filters())
      std::copy(filter.GetFlattenedFilters().begin(),
                filter.GetFlattenedFilters().end(),
                std::back_inserter(flattened_filters));
    return flattened_filters;
  });
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
