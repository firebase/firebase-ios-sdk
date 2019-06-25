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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_VECTOR_OF_PTR_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_VECTOR_OF_PTR_H_

#include <initializer_list>
#include <memory>
#include <utility>
#include <vector>

#include "absl/algorithm/container.h"

namespace firebase {
namespace firestore {
namespace util {

/**
 * A std::vector of some pointer type where equality and many other operations
 * are defined as operating on the value pointed to rather than on the pointers
 * themselves.
 *
 * Contrast with `std::vector<std::shared_ptr<T>>`, where `operator==` just
 * checks if the pointers in the collection are equal rather than checking if
 * the things the pointers point to are equal.
 *
 * This is useful in cases where values of type T need to be held by pointer
 * for some reason, usually this is to enable polymorphism or because copying
 * values of T is expensive.
 */
template <typename P>
class vector_of_ptr {
 public:
  using pointer_type = P;
  using value_type = decltype(*P());
  using vector_type = std::vector<P>;

  using iterator = typename vector_type::iterator;
  using const_iterator = typename vector_type::const_iterator;

  vector_of_ptr() = default;
  vector_of_ptr(std::initializer_list<P> values) : values_(values) {
  }

  size_t size() const {
    return values_.size();
  }

  void push_back(P value) {
    values_.push_back(std::move(value));
  }

  iterator begin() {
    return values_.begin();
  }
  const_iterator begin() const {
    return values_.begin();
  }

  iterator end() {
    return values_.end();
  }
  const_iterator end() const {
    return values_.end();
  }

  friend bool operator==(const vector_of_ptr& lhs, const vector_of_ptr& rhs) {
    return absl::c_equal(
        lhs.values_, rhs.values_, [](const P& left, const P& right) {
          return left == nullptr ? right == nullptr
                                 : right != nullptr && *left == *right;
        });
  }

  friend bool operator!=(const vector_of_ptr& lhs, const vector_of_ptr& rhs) {
    return !(lhs == rhs);
  }

 private:
  vector_type values_;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_VECTOR_OF_PTR_H_
