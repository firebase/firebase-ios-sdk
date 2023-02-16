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

#ifndef FIRESTORE_CORE_SRC_UTIL_LOGIC_UTILS_H_
#define FIRESTORE_CORE_SRC_UTIL_LOGIC_UTILS_H_

#include <vector>

#include "Firestore/core/src/core/filter.h"

namespace firebase {
namespace firestore {

namespace core {
class FieldFilter;
class CompositeFilter;
}  // namespace core

namespace util {

/**
 * Provides utility functions that help with boolean logic transformations
 * needed for handling complex filters used in queries.
 */
class LogicUtils {
 public:
  /**
   * Given a composite filter, returns the list of terms in its disjunctive
   * normal form.
   *
   * Each element in the return value is one term of the resulting DNF.
   * For instance: For the input: (A || B) && C, the DNF form is: (A && C) || (B
   * && C), and the return value is a list with two elements: a composite filter
   * that performs (A && C), and a composite filter that performs (B && C).
   *
   * @param filter the composite filter to calculate DNF transform for.
   * @return the terms in the DNF transform.
   */
  static std::vector<core::Filter> GetDnfTerms(
      const core::CompositeFilter& filter);

 protected:
  /**
   * Applies the associativity property to the given filter and returns the
   * resulting filter.
   *
   * A | (B | C) == (A | B) | C == (A | B | C)
   * A & (B & C) == (A & B) & C == (A & B & C)
   *
   * For more info, visit:
   * https://en.wikipedia.org/wiki/Associative_property#Propositional_logic
   */
  static core::Filter ApplyAssociation(const core::Filter& filter);

  /**
   * Performs conjunction distribution for the given filters.
   *
   * There are generally four types of distributions:
   *
   * Distribution of conjunction over disjunction:
   * P & (Q | R) == (P & Q) | (P & R)
   * Distribution of disjunction over conjunction:
   * P | (Q & R) == (P | Q) & (P | R)
   * Distribution of conjunction over conjunction:
   * P & (Q & R) == (P & Q) & (P & R)
   * Distribution of disjunction over disjunction:
   * P | (Q | R) == (P | Q) | (P | R)
   *
   * This function ONLY performs the first type (distributing conjunction over
   * disjunction) as it is meant to be used towards arriving at a DNF form.
   *
   * For more info, visit:
   * https://en.wikipedia.org/wiki/Distributive_property#Propositional_logic
   */
  static core::Filter ApplyDistribution(const core::Filter& lhs,
                                        const core::Filter& rhs);

  static core::Filter ComputeDistributedNormalForm(const core::Filter& filter);

  /**
   * The `in` filter is only a syntactic sugar over a disjunction of equalities.
   * For instance: `a in [1,2,3]` is in fact `a==1 || a==2 || a==3`. This method
   * expands any `in` filter in the given input into a disjunction of equality
   * filters and returns the expanded filter.
   */
  static core::Filter ComputeInExpansion(const core::Filter& filter);

 private:
  /**
   * Asserts that the given filter is a FieldFilter or CompositeFilter.
   */
  static void AssertFieldFilterOrCompositeFilter(const core::Filter& filter);

  /**
   * Returns true if the given filter is a single field filter. e.g. (a == 10).
   */
  static bool IsSingleFieldFilter(const core::Filter& filter);

  /**
   * Returns true if the given filter is the conjunction of one or more field
   * filters. e.g. (a == 10 && b == 20)
   */
  static bool IsFlatConjunction(const core::Filter& filter);

  /**
   * Returns true if the given filter is the disjunction of one or more "flat
   * conjunctions" and field filters. e.g. (a == 10) || (b==20 && c==30)
   */
  static bool IsDisjunctionOfFieldFiltersAndFlatConjunctions(
      const core::Filter& filter);

  /**
   * Returns whether or not the given filter is in disjunctive normal form
   * (DNF).
   *
   * In boolean logic, a disjunctive normal form (DNF) is a canonical normal
   * form of a logical formula consisting of a disjunction of conjunctions; it
   * can also be described as an OR of ANDs.
   *
   * For more info, visit: https://en.wikipedia.org/wiki/Disjunctive_normal_form
   */
  static bool IsDisjunctiveNormalForm(const core::Filter& filter);

  static core::Filter ApplyDistribution(core::FieldFilter&& lhs,
                                        core::FieldFilter&& rhs);

  static core::Filter ApplyDistribution(
      core::FieldFilter&& field_filter,
      core::CompositeFilter&& composite_filter);

  static core::Filter ApplyDistribution(core::CompositeFilter&& lhs,
                                        core::CompositeFilter&& rhs);
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_LOGIC_UTILS_H_
