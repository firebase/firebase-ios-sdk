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

#include "Firestore/core/src/firebase/firestore/core/null_filter.h"

#include <utility>

namespace firebase {
namespace firestore {
namespace core {

using model::FieldPath;
using model::FieldValue;

NullFilter::NullFilter(FieldPath field) : field_(std::move(field)) {
}

bool NullFilter::Matches(const model::Document& doc) const {
  absl::optional<FieldValue> doc_field_value = doc.field(field_);
  return doc_field_value && doc_field_value->type() == FieldValue::Type::Null;
}

std::string NullFilter::CanonicalId() const {
  return field().CanonicalString() + " IS NULL";
}

std::string NullFilter::ToString() const {
  return CanonicalId();
}

size_t NullFilter::Hash() const {
  return field_.Hash();
}

bool NullFilter::Equals(const Filter& other) const {
  if (other.type() != Type::kNullFilter) return false;

  const auto& other_filter = static_cast<const NullFilter&>(other);
  return field() == other_filter.field();
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
