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

#ifndef FIRESTORE_CORE_SRC_INDEX_INDEX_ENTRY_H_
#define FIRESTORE_CORE_SRC_INDEX_INDEX_ENTRY_H_

#include <iostream>
#include <memory>
#include <string>
#include <utility>

#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/util/comparison.h"

namespace firebase {
namespace firestore {
namespace index {

/** Represents an index entry saved by the SDK in its local storage. */
class IndexEntry : public util::Comparable<IndexEntry> {
 public:
  IndexEntry(int32_t index_id,
             model::DocumentKey key,
             std::string array_value,
             std::string directional_value)
      : index_id_(index_id),
        key_(std::move(key)),
        array_value_(std::move(array_value)),
        directional_value_(std::move(directional_value)) {
  }

  /**
   * Returns an IndexEntry entry that sorts immediately after the current
   * directional value.
   */
  IndexEntry Successor() const;

  int32_t index_id() const {
    return index_id_;
  }

  const model::DocumentKey& document_key() const {
    return key_;
  }

  const std::string& array_value() const {
    return array_value_;
  }

  const std::string& directional_value() const {
    return directional_value_;
  }

  util::ComparisonResult CompareTo(const IndexEntry& rhs) const;
  size_t Hash() const;

  std::string ToString() const;
  friend std::ostream& operator<<(std::ostream& out, const IndexEntry& entry);

 private:
  int32_t index_id_;
  model::DocumentKey key_;
  std::string array_value_;
  std::string directional_value_;
};

}  // namespace index
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_INDEX_INDEX_ENTRY_H_
