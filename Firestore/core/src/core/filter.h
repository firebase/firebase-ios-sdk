/*
 * Copyright 2018 Google
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

#ifndef FIRESTORE_CORE_SRC_CORE_FILTER_H_
#define FIRESTORE_CORE_SRC_CORE_FILTER_H_

#include <functional>
#include <iosfwd>
#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/util/thread_safe_memoizer.h"

namespace firebase {
namespace firestore {
namespace core {

class FieldFilter;

/** Interface used for all query filters. All filters are immutable. */
class Filter {
 public:
  // For lack of RTTI, all subclasses must identify themselves so that
  // comparisons properly take type into account.
  enum class Type {
    kFilter,
    kFieldFilter,
    kCompositeFilter,
    kArrayContainsAnyFilter,
    kArrayContainsFilter,
    kInFilter,
    kNotInFilter,
    kKeyFieldFilter,
    kKeyFieldInFilter,
    kKeyFieldNotInFilter,
  };

  Type type() const {
    return rep_->type();
  }

  /**
   * Returns true if this instance is FieldFilter or any derived class.
   * Equivalent to `instanceof FieldFilter` on other platforms.
   *
   * Note this is different than checking `type() == Type::kFieldFilter` which
   * is only true if the type is exactly FieldFilter.
   */
  bool IsAFieldFilter() const {
    return rep_->IsAFieldFilter();
  }

  bool IsACompositeFilter() const {
    return rep_->IsACompositeFilter();
  }

  bool IsInequality() const {
    return rep_->IsInequality();
  }

  /** Returns true if a document matches the filter. */
  bool Matches(const model::Document& doc) const {
    return rep_->Matches(doc);
  }

  /** A unique ID identifying the filter; used when serializing queries. */
  std::string CanonicalId() const {
    return rep_->CanonicalId();
  }

  /** A debug description of the Filter. */
  std::string ToString() const {
    return rep_->ToString();
  }

  /**
   * Returns true if and only if the filter is a composite filter that
   * doesn't contain any field filters.
   */
  bool IsEmpty() const {
    return rep_->IsEmpty();
  }

  /**
   * Returns a list of all field filters that are contained within this filter.
   */
  const std::vector<FieldFilter>& GetFlattenedFilters() const {
    return rep_->GetFlattenedFilters();
  }

  /**
   * Returns a list of all filters that are contained within this filter
   */
  std::vector<Filter> GetFilters() const {
    return rep_->GetFilters();
  }

  friend bool operator==(const Filter& lhs, const Filter& rhs);

 protected:
  class Rep {
   public:
    Rep() = default;

    virtual ~Rep() = default;

    virtual Type type() const {
      return Type::kFilter;
    }

    virtual bool IsAFieldFilter() const {
      return false;
    }

    virtual bool IsACompositeFilter() const {
      return false;
    }

    virtual bool IsInequality() const {
      return false;
    }

    /** Returns true if a document matches the filter. */
    virtual bool Matches(const model::Document& doc) const = 0;

    /** A unique ID identifying the filter; used when serializing queries. */
    virtual std::string CanonicalId() const = 0;

    virtual bool Equals(const Rep& other) const = 0;

    /** A debug description of the Filter. */
    virtual std::string ToString() const = 0;

    virtual bool IsEmpty() const = 0;

    virtual const std::vector<FieldFilter>& GetFlattenedFilters() const {
      const auto func = std::bind(&Rep::CalculateFlattenedFilters, this);
      return memoized_flattened_filters_.value(func);
    }

    virtual std::vector<Filter> GetFilters() const = 0;

   protected:
    virtual std::shared_ptr<std::vector<FieldFilter>>
    CalculateFlattenedFilters() const = 0;

   private:
    /**
     * Memoized list of all field filters that can be found by
     * traversing the tree of filters contained in this composite filter.
     */
    mutable util::ThreadSafeMemoizer<const std::vector<FieldFilter>>
        memoized_flattened_filters_;
  };

  explicit Filter(std::shared_ptr<const Rep>&& rep) : rep_(rep) {
  }

  const Rep& rep() const {
    return *rep_;
  }

 private:
  std::shared_ptr<const Rep> rep_;
};

inline bool operator!=(const Filter& lhs, const Filter& rhs) {
  return !(lhs == rhs);
}

std::ostream& operator<<(std::ostream& os, const Filter& filter);

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_CORE_FILTER_H_
