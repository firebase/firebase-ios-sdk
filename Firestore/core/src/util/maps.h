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

#ifndef FIRESTORE_CORE_SRC_UTIL_MAPS_H_
#define FIRESTORE_CORE_SRC_UTIL_MAPS_H_

#include <unordered_map>
#include <utility>
#include <vector>

namespace firebase {
namespace firestore {
namespace util {

/**
 * A map supports consuming values in the insertion order.
 */
template <typename K, typename V>
class MapWithInsertionOrder {
 public:
  /** Adds or replaces a key and its associated value in the map. */
  void Put(const K& key, const V& value) {
    if (field_value_map_.find(key) != field_value_map_.end()) {
      *field_value_map_[key] = value;
    } else {
      values_.push_back(value);
      field_value_map_[key] = values_.end() - 1;
    }
  }

  /** Consumes the values added to the map in the insertion order. */
  std::vector<V>&& ConsumeValues() {
    return std::move(values_);
  }

 private:
  std::vector<V> values_;
  std::unordered_map<K, typename std::vector<V>::iterator> field_value_map_;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_UTIL_MAPS_H_
