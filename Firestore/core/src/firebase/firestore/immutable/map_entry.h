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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_MAP_ENTRY_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_MAP_ENTRY_H_

#include <functional>
#include <utility>

namespace firebase {
namespace firestore {
namespace immutable {

/**
 * Compares two keys out of a map entry.
 *
 * @tparam K The type of the first value in the pair.
 * @tparam V The type of the second value in the pair.
 * @tparam C The comparator for use for values of type K
 */
template <typename K, typename V, typename C = std::less<K>>
struct KeyComparator {
  using pair_type = std::pair<K, V>;

  explicit KeyComparator(const C& comparator = C())
      : key_comparator_(comparator) {
  }

  bool operator()(const K& lhs, const pair_type& rhs) const noexcept {
    return key_comparator_(lhs, rhs.first);
  }

  bool operator()(const pair_type& lhs, const K& rhs) const noexcept {
    return key_comparator_(lhs.first, rhs);
  }

  bool operator()(const pair_type& lhs, const pair_type& rhs) const noexcept {
    return key_comparator_(lhs.first, rhs.first);
  }

  const C& comparator() const {
    return key_comparator_;
  }

 private:
  C key_comparator_;
};

}  // namespace immutable
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_IMMUTABLE_MAP_ENTRY_H_
