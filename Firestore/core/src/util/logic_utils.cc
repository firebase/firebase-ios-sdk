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

#include "Firestore/core/src/util/logic_utils.h"

#include <utility>
#include <vector>

#include "Firestore/core/src/core/composite_filter.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace util {

using core::CompositeFilter;
using core::FieldFilter;
using core::Filter;

void LogicUtils::AssertFieldFilterOrCompositeFilter(const Filter& filter) {
  HARD_ASSERT(filter.IsAFieldFilter() || filter.IsACompositeFilter(),
              "Only field filters and composite filters are accepted.");
}

bool LogicUtils::IsSingleFieldFilter(const Filter& filter) {
  return filter.IsAFieldFilter();
}

bool LogicUtils::IsFlatConjunction(const Filter& filter) {
  return filter.IsACompositeFilter() &&
         CompositeFilter(filter).IsFlatConjunction();
}

bool LogicUtils::IsDisjunctionOfFieldFiltersAndFlatConjunctions(
    const Filter& filter) {
  if (filter.IsACompositeFilter()) {
    const CompositeFilter composite_filter(filter);
    if (composite_filter.IsDisjunction()) {
      return std::all_of(composite_filter.filters().cbegin(),
                         composite_filter.filters().cend(),
                         [](const Filter& sub_filter) {
                           return IsSingleFieldFilter(sub_filter) ||
                                  IsFlatConjunction(sub_filter);
                         });
    }
  }
  return false;
}

bool LogicUtils::IsDisjunctiveNormalForm(const Filter& filter) {
  // A single field filter is always in DNF form.
  // An AND of several field filters ("Flat AND") is in DNF form. e.g (A && B).
  // An OR of field filters and "Flat AND"s is in DNF form. e.g. A || (B && C)
  // || (D && F). Everything else is not in DNF form.
  return IsSingleFieldFilter(filter) || IsFlatConjunction(filter) ||
         IsDisjunctionOfFieldFiltersAndFlatConjunctions(filter);
}

Filter LogicUtils::ApplyAssociation(const Filter& filter) {
  AssertFieldFilterOrCompositeFilter(filter);

  if (IsSingleFieldFilter(filter)) {
    return filter;
  }

  CompositeFilter composite_filter(filter);

  // Example: (A | (((B)) | (C | D) | (E & F & (G | H)) -->
  // (A | B | C | D | (E & F & (G | H))
  const auto& filters = composite_filter.filters();

  // If the composite filter only contains 1 filter, apply associativity to it.
  if (filters.size() == 1U) {
    return ApplyAssociation(filters[0]);
  }

  // Associativity applied to a flat composite filter results in itself.
  if (composite_filter.IsFlat()) {
    return std::move(composite_filter);
  }

  // First apply associativity to all subfilters. This will in turn recursively
  // apply associativity to all nested composite filters and field filters.
  std::vector<Filter> updated_filters;
  for (const auto& subfilter : filters) {
    updated_filters.push_back(ApplyAssociation(subfilter));
  }

  // For composite subfilters that perform the same kind of logical operation
  // as `compositeFilter`, take out their filters and add them to
  // `compositeFilter`. For example: composite_filter = (A | (B | C | D))
  // composite_subfilter = (B | C | D)
  // Result: (A | B | C | D)
  // Note that the `composite_subfilter` has been eliminated, and its filters
  // (B, C, D) have been added to the top-level "composite_subfilter".
  std::vector<Filter> new_subfilters;
  for (const Filter& subfilter : updated_filters) {
    if (subfilter.IsAFieldFilter()) {
      new_subfilters.push_back(subfilter);
    } else if (subfilter.IsACompositeFilter()) {
      CompositeFilter composite_subfilter(subfilter);
      if (composite_subfilter.op() == composite_filter.op()) {
        // composite_filter: (A | (B | C))
        // composite_subfilter: (B | C)
        // Result: (A | B | C)
        new_subfilters.insert(
            new_subfilters.end(),
            std::make_move_iterator(composite_subfilter.filters().begin()),
            std::make_move_iterator(composite_subfilter.filters().end()));
      } else {
        // composite_filter: (A | (B & C))
        // composite_subfilter: (B & C)
        // Result: (A | (B & C))
        new_subfilters.push_back(std::move(composite_subfilter));
      }
    }
  }
  if (new_subfilters.size() == 1U) {
    return new_subfilters[0];
  }
  return CompositeFilter::Create(std::move(new_subfilters),
                                 composite_filter.op());
}

Filter LogicUtils::ApplyDistribution(const Filter& lhs, const Filter& rhs) {
  AssertFieldFilterOrCompositeFilter(lhs);
  AssertFieldFilterOrCompositeFilter(rhs);

  // Since `applyDistribution` is recursive, we must apply association at the
  // end of each distribution in order to ensure the result is as flat as
  // possible for the next round of distributions.
  if (lhs.IsAFieldFilter() && rhs.IsAFieldFilter()) {
    return ApplyAssociation(
        ApplyDistribution(FieldFilter(lhs), FieldFilter(rhs)));
  } else if (lhs.IsAFieldFilter() && rhs.IsACompositeFilter()) {
    return ApplyAssociation(
        ApplyDistribution(FieldFilter(lhs), CompositeFilter(rhs)));
  } else if (lhs.IsACompositeFilter() && rhs.IsAFieldFilter()) {
    return ApplyAssociation(
        ApplyDistribution(FieldFilter(rhs), CompositeFilter(lhs)));
  } else {
    return ApplyAssociation(
        ApplyDistribution(CompositeFilter(lhs), CompositeFilter(rhs)));
  }
}

Filter LogicUtils::ApplyDistribution(FieldFilter&& lhs, FieldFilter&& rhs) {
  // Conjunction distribution for two field filters is the conjunction of them.
  return CompositeFilter::Create({std::move(lhs), std::move(rhs)},
                                 CompositeFilter::Operator::And);
}

Filter LogicUtils::ApplyDistribution(FieldFilter&& field_filter,
                                     CompositeFilter&& composite_filter) {
  // There are two cases:
  // A & (B & C) --> (A & B & C)
  // A & (B | C) --> (A & B) | (A & C)
  if (composite_filter.IsConjunction()) {
    // Case 1
    return composite_filter.WithAddedFilters({field_filter});
  } else {
    // Case 2
    std::vector<Filter> new_filters;
    for (const Filter& subfilter : composite_filter.filters()) {
      new_filters.push_back(ApplyDistribution(field_filter, subfilter));
    }
    return CompositeFilter::Create(std::move(new_filters),
                                   CompositeFilter::Operator::Or);
  }
}

Filter LogicUtils::ApplyDistribution(CompositeFilter&& lhs,
                                     CompositeFilter&& rhs) {
  HARD_ASSERT(!lhs.IsEmpty() && !rhs.IsEmpty(),
              "Found an empty composite filter");

  // There are four cases:
  // (A & B) & (C & D) --> (A & B & C & D)
  // (A & B) & (C | D) --> (A & B & C) | (A & B & D)
  // (A | B) & (C & D) --> (C & D & A) | (C & D & B)
  // (A | B) & (C | D) --> (A & C) | (A & D) | (B & C) | (B & D)

  // Case 1 is a merge.
  if (lhs.IsConjunction() && rhs.IsConjunction()) {
    return lhs.WithAddedFilters(rhs.filters());
  }

  // Case 2,3,4 all have at least one side (lhs or rhs) that is a disjunction.
  // In all three cases we should take each element of the disjunction and
  // distribute it over the other side, and return the disjunction of
  // the distribution results.
  const CompositeFilter& disjunction_side = lhs.IsDisjunction() ? lhs : rhs;
  const CompositeFilter& other_side = lhs.IsDisjunction() ? rhs : lhs;
  std::vector<Filter> results;
  for (const Filter& subfilter : disjunction_side.filters()) {
    results.push_back(ApplyDistribution(subfilter, other_side));
  }
  return CompositeFilter::Create(std::move(results),
                                 CompositeFilter::Operator::Or);
}

Filter LogicUtils::ComputeDistributedNormalForm(const core::Filter& filter) {
  AssertFieldFilterOrCompositeFilter(filter);

  if (filter.IsAFieldFilter()) {
    return filter;
  }

  const CompositeFilter composite_filter(filter);

  if (composite_filter.filters().size() == 1U) {
    return ComputeDistributedNormalForm(composite_filter.filters()[0]);
  }

  // Compute the DNF for each of the subfilters first.
  std::vector<Filter> result;
  for (const auto& subfilter : composite_filter.filters()) {
    result.push_back(ComputeDistributedNormalForm(subfilter));
  }
  Filter new_filter =
      CompositeFilter::Create(std::move(result), composite_filter.op());
  new_filter = ApplyAssociation(new_filter);

  if (IsDisjunctiveNormalForm(new_filter)) {
    return new_filter;
  }

  HARD_ASSERT(new_filter.IsACompositeFilter(),
              "field filters are already in DNF form.");
  const CompositeFilter new_composite_filter(new_filter);
  HARD_ASSERT(new_composite_filter.IsConjunction(),
              "Disjunction of filters all of which are already in DNF form is "
              "itself in DNF form.");
  HARD_ASSERT(new_composite_filter.filters().size() > 1U,
              "Single-filter composite filters are already in DNF form.");
  Filter running_result = new_composite_filter.filters()[0];
  for (size_t i = 1U; i < new_composite_filter.filters().size(); ++i) {
    running_result =
        ApplyDistribution(running_result, new_composite_filter.filters()[i]);
  }
  return running_result;
}

Filter LogicUtils::ComputeInExpansion(const Filter& filter) {
  AssertFieldFilterOrCompositeFilter(filter);

  std::vector<Filter> expanded_filters;

  if (filter.IsAFieldFilter()) {
    if (filter.type() == Filter::Type::kInFilter) {
      // We have reached a field filter with `in` operator.
      FieldFilter in_filter(filter);
      for (pb_size_t i = 0; i < in_filter.value().array_value.values_count;
           ++i) {
        expanded_filters.push_back(FieldFilter::Create(
            in_filter.field(), FieldFilter::Operator::Equal,
            nanopb::MakeSharedMessage(
                *model::DeepClone(in_filter.value().array_value.values[i])
                     .release())));
      }
      return CompositeFilter::Create(std::move(expanded_filters),
                                     CompositeFilter::Operator::Or);
    } else {
      // We have reached other kinds of field filters.
      return filter;
    }
  }

  // We have a composite filter.
  CompositeFilter composite_filter(filter);
  for (const auto& subfilter : composite_filter.filters()) {
    expanded_filters.push_back(ComputeInExpansion(subfilter));
  }
  return CompositeFilter::Create(std::move(expanded_filters),
                                 composite_filter.op());
}

std::vector<core::Filter> LogicUtils::GetDnfTerms(
    const core::CompositeFilter& filter) {
  if (filter.IsEmpty()) {
    return {};
  }

  // The `in` operator is a syntactic sugar over a disjunction of equalities.
  // We should first replace such filters with equality filters before running
  // the DNF transform.
  Filter result = ComputeDistributedNormalForm(ComputeInExpansion(filter));

  HARD_ASSERT(
      IsDisjunctiveNormalForm(result),
      "ComputeDistributedNormalForm did not result in disjunctive normal form");

  if (IsSingleFieldFilter(result) || IsFlatConjunction(result)) {
    return {std::move(result)};
  }

  return result.GetFilters();
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
