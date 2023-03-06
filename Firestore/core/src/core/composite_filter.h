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

#ifndef FIRESTORE_CORE_SRC_CORE_COMPOSITE_FILTER_H_
#define FIRESTORE_CORE_SRC_CORE_COMPOSITE_FILTER_H_

#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/core/filter.h"

namespace firebase {
namespace firestore {

namespace model {
class FieldPath;
}  // namespace model

namespace core {

class FieldFilter;

/**
 * CompositeFilter is a filter that is the conjunction or disjunction of
 * other filters.
 */
class CompositeFilter : public Filter {
 public:
  using CheckFunction = std::function<bool(const FieldFilter&)>;

  enum class Operator { And, Or };

  static CompositeFilter Create(std::vector<Filter>&& filters, Operator op);

  explicit CompositeFilter(const Filter& other);

  const std::vector<Filter>& filters() const {
    return composite_filter_rep().filters();
  }

  Operator op() const {
    return composite_filter_rep().op();
  }

  bool IsConjunction() const {
    return composite_filter_rep().IsConjunction();
  }

  bool IsDisjunction() const {
    return composite_filter_rep().IsDisjunction();
  }

  /**
   * Returns true if this filter is a conjunction of field filters only. Returns
   * false otherwise.
   */
  bool IsFlatConjunction() const {
    return composite_filter_rep().IsFlatConjunction();
  }

  /**
   * Returns true if this filter does not contain any composite filters. Returns
   * false otherwise.
   */
  bool IsFlat() const {
    return composite_filter_rep().IsFlat();
  }

  /**
   * Returns a new composite filter that contains all filter from `this`
   * plus all the given filters.
   */
  CompositeFilter WithAddedFilters(
      const std::vector<core::Filter>& other_filters);

 private:
  class Rep : public Filter::Rep {
   private:
    /**
     * Only intended to be called from CompositeFilter::Create().
     *
     * @param filters A collection of filters stored inside the CompositeFilter.
     * @param op The composite operator to apply.
     */
    Rep(std::vector<Filter>&& filters, Operator op);

    Operator op() const {
      return op_;
    }

    const std::vector<Filter>& filters() const {
      return filters_;
    }

    Type type() const override {
      return Type::kCompositeFilter;
    }

    bool IsConjunction() const;

    bool IsDisjunction() const;

    bool IsFlat() const;

    bool IsFlatConjunction() const {
      return IsFlat() && IsConjunction();
    }

    bool IsACompositeFilter() const override {
      return true;
    }

    bool Matches(const model::Document& doc) const override;

    std::string CanonicalId() const override;

    std::string ToString() const override {
      return CanonicalId();
    };

    bool Equals(const Filter::Rep& other) const override;

    bool IsEmpty() const override {
      return filters_.empty();
    }

    const std::vector<FieldFilter>& GetFlattenedFilters() const override;

    const model::FieldPath* GetFirstInequalityField() const override;

    std::vector<Filter> GetFilters() const override {
      return filters();
    }

    /**
     * Performs a depth-first search to find and return the first FieldFilter in
     * the composite filter that satisfies the condition. Returns nullptr if
     * none of the FieldFilters satisfy the condition.
     */
    const FieldFilter* FindFirstMatchingFilter(
        const CheckFunction& condition) const;

    /** A collection of filters stored inside the CompositeFilter. */
    const std::vector<Filter> filters_;

    /** The type of and/or operator in the composite filter. */
    Operator op_;

    friend class CompositeFilter;
  };

  explicit CompositeFilter(std::shared_ptr<const Filter::Rep>&& rep);

  const Rep& composite_filter_rep() const {
    return static_cast<const Rep&>(rep());
  }
};
}  // namespace core
}  // namespace firestore
}  // namespace firebase
#endif  // FIRESTORE_CORE_SRC_CORE_COMPOSITE_FILTER_H_
