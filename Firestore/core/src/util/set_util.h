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

#ifndef FIRESTORE_CORE_SRC_UTIL_SET_UTIL_H_
#define FIRESTORE_CORE_SRC_UTIL_SET_UTIL_H_

#include <set>

#include "Firestore/core/src/util/comparison.h"

namespace firebase {
namespace firestore {
namespace util {

/**
 * Compares two (sorted) `std::set`s for equality using their natural ordering.
 * The method computes the intersection and invokes `on_add` for every element
 * that is in `after` but not `before`. `on_remove` is invoked for every
 * element in `before` but missing from `after`.
 *
 * The method runs in O(n) where n is the size of the two lists.
 *
 * @param existing - The elements that exist in the original set.
 * @param new_entries - The elements to diff against the original set.
 * @param comparator - The comparator for the elements in before and after.
 * @param on_add - A function to invoke for every element that is part of `
 * after` but not `before`.
 * @param on_remove - A function to invoke for every element that is part of
 * `before` but not `after`.
 */
template <typename T>
void DiffSets(std::set<T> existing,
              std::set<T> new_entries,
              Comparator<T> comparator,
              std::function<void(const T&)> on_add,
              std::function<void(const T&)> on_remove) {
  auto existing_iter = existing.cbegin();
  auto new_iter = new_entries.cbegin();
  // Walk through the two sets at the same time, using the ordering defined by
  // `CompareTo`.
  while (existing_iter != existing.cend() || new_iter != new_entries.cend()) {
    bool added = false;
    bool removed = false;

    if (existing_iter != existing.cend() && new_iter != new_entries.cend()) {
      util::ComparisonResult cmp =
          comparator.Compare(*existing_iter, *new_iter);
      if (cmp == util::ComparisonResult::Ascending) {
        // The element was removed if the next element in our ordered
        // walkthrough is only in `existing`.
        removed = true;
      } else if (cmp == util::ComparisonResult::Descending) {
        // The element was added if the next element in our ordered
        // walkthrough is only in `new_entries`.
        added = true;
      }
    } else if (existing_iter != existing.cend()) {
      removed = true;
    } else {
      added = true;
    }

    if (added) {
      on_add(*new_iter);
      new_iter++;
    } else if (removed) {
      on_remove(*existing_iter);
      existing_iter++;
    } else {
      if (existing_iter != existing.cend()) {
        existing_iter++;
      }
      if (new_iter != new_entries.cend()) {
        new_iter++;
      }
    }
  }
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_SET_UTIL_H_
