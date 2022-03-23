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

#include "Firestore/Protos/nanopb/google/firestore/v1/query.nanopb.h"
#include "Firestore/core/src/core/filter.h"

namespace firebase {
namespace firestore {

namespace model {
class FieldPath;
}  // namespace model

namespace core {

class FieldFilter;

/**
 * CompositeFilter is a filter
 * that is the conjunction or disjunction of other filters.
 */
class CompositeFilter : public Filter {
 public:
  using CheckingFun = std::function<bool(const std::shared_ptr<FieldFilter>)>;
  using Operator =
      _google_firestore_v1_StructuredQuery_CompositeFilter_Operator;

  static CompositeFilter Create(
      const std::vector<std::shared_ptr<Filter>>&& filters, Operator op);

  explicit CompositeFilter(const Filter& other);

  const std::vector<std::shared_ptr<Filter>>& filters() const {
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

 private:
  class Rep : public Filter::Rep {
   private:
    /**
     * Only intended to be called from CompositeFilter::Create().
     *
     * @param filters A collection of filters stored inside the CompositeFilter.
     * @param op The composite operator to apply.
     */
    Rep(const std::vector<std::shared_ptr<Filter>>&& filters, Operator op);

    Operator op() const {
      return op_;
    }

    const std::vector<std::shared_ptr<Filter>>& filters() const {
      return filters_;
    }

    Type type() const override {
      return Type::kCompositeFilter;
    }

    bool IsConjunction() const;

    bool IsDisjunction() const;

    bool IsACompositeFilter() const override {
      return true;
    }

    bool Matches(const model::Document& doc) const override;

    std::string CanonicalId() const override;

    std::string ToString() const override {
      return CanonicalId();
    };

    bool Equals(const Filter::Rep& other) const override;

    const std::shared_ptr<FieldFilter> FindFirstMatchingFilter(
        CheckingFun& condition) const;

    const model::FieldPath* GetFirstInequalityField() const override;

    bool IsEmpty() const override {
      return filters_.empty();
    }

    const std::vector<std::shared_ptr<FieldFilter>> GetFlattenedFilters()
        const override {
      return flatten_filters_;
    };

    const std::vector<std::shared_ptr<Filter>> filters_;

    std::vector<std::shared_ptr<FieldFilter>> flatten_filters_;

    Operator op_;

    friend class CompositeFilter;
  };

  explicit CompositeFilter(std::shared_ptr<const Filter::Rep> rep);

  const Rep& composite_filter_rep() const {
    return static_cast<const Rep&>(rep());
  }
};
}  // namespace core
}  // namespace firestore
}  // namespace firebase
#endif  // FIRESTORE_CORE_SRC_CORE_COMPOSITE_FILTER_H_
