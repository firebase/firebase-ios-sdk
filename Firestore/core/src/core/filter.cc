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

#include "Firestore/core/src/core/filter.h"

#include "Firestore/core/src/core/field_filter.h"

#include <ostream>

namespace firebase {
namespace firestore {
namespace core {

bool operator==(const Filter& lhs, const Filter& rhs) {
  return lhs.rep_ == nullptr
             ? rhs.rep_ == nullptr
             : (rhs.rep_ != nullptr && lhs.rep_->Equals(*rhs.rep_));
}

std::ostream& operator<<(std::ostream& os, const Filter& filter) {
  return os << filter.ToString();
}

Filter::Rep::Rep()
    : memoized_flattened_filters_(
          std::make_shared<MemoizedFlattenedFilters>()) {
}

Filter::Rep::~Rep() {
  // Add a comment about WHY this call_once here is necessary (i.e. so that the
  // destructor synchronizes with some other thread that potentially won the
  // race to set memoized_flattened_filters_.filters).
  std::call_once(memoized_flattened_filters_->once, [] {});
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
