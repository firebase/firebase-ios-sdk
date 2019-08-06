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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_FILTER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_FILTER_H_

#include <iosfwd>
#include <memory>
#include <string>

#include "Firestore/core/src/firebase/firestore/immutable/append_only_list.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"

namespace firebase {
namespace firestore {
namespace core {

/** Interface used for all query filters. All filters are immutable. */
class Filter {
 public:
  /**
   * Operator is a value relation operator that can be used to filter documents.
   * It is similar to NSPredicateOperatorType, but only has operators supported
   * by Firestore.
   */
  enum class Operator {
    LessThan,
    LessThanOrEqual,
    Equal,
    GreaterThanOrEqual,
    GreaterThan,
    ArrayContains,
    In,
    ArrayContainsAny,
  };

  // For lack of RTTI, all subclasses must identify themselves so that
  // comparisons properly take type into account.
  enum class Type {
    kArrayContainsAnyFilter,
    kArrayContainsFilter,
    kFieldFilter,
    kInFilter,
    kKeyFieldFilter,
    kKeyFieldInFilter,
  };

  virtual ~Filter() = default;

  virtual Type type() const = 0;

  /**
   * Returns true if this instance is FieldFilter or any derived class.
   * Equivalent to `instanceof FieldFilter` on other platforms.
   *
   * Note this is different than checking `type() == Type::kFieldFilter` which
   * is only true if the type is exactly FieldFilter.
   */
  virtual bool IsAFieldFilter() const {
    return false;
  }

  /** Returns the field the Filter operates over. */
  virtual const model::FieldPath& field() const = 0;

  /** Returns true if a document matches the filter. */
  virtual bool Matches(const model::Document& doc) const = 0;

  /** A unique ID identifying the filter; used when serializing queries. */
  virtual std::string CanonicalId() const = 0;

  /** A debug description of the Filter. */
  virtual std::string ToString() const = 0;

  virtual size_t Hash() const = 0;

  virtual bool IsInequality() const {
    return false;
  }

  friend bool operator==(const Filter& lhs, const Filter& rhs) {
    return lhs.Equals(rhs);
  }

 private:
  virtual bool Equals(const Filter& other) const = 0;
};

inline bool operator!=(const Filter& lhs, const Filter& rhs) {
  return !(lhs == rhs);
}

/** A list of Filters, as used in Queries and elsewhere. */
using FilterList = immutable::AppendOnlyList<std::shared_ptr<const Filter>>;

std::ostream& operator<<(std::ostream& os, const Filter& filter);

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_FILTER_H_
