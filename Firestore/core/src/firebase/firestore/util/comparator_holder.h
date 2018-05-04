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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_COMPARATOR_HOLDER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_COMPARATOR_HOLDER_H_

#include <type_traits>

namespace firebase {
namespace firestore {
namespace util {

/**
 * A holder of some comparator (e.g. std::less or util::Comparator) that
 * implements the empty base optimization for the common case where the
 * comparator occupies no storage.
 */
template <typename C, bool = std::is_empty<C>::value>
class ComparatorHolder {
 protected:
  explicit ComparatorHolder(const C& comparator) noexcept
      : comparator_(comparator) {
  }

 public:
  const C& comparator() const noexcept {
    return comparator_;
  }

 private:
  C comparator_;
};

// Implementation to use when C is empty.
template <typename C>
class ComparatorHolder<C, true> : private C {
 protected:
  explicit ComparatorHolder(const C& /* comparator */) noexcept {
  }

 public:
  const C& comparator() const noexcept {
    return *this;
  }
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_COMPARATOR_HOLDER_H_
