/*
 * Copyright 2022 Google
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

#ifndef FIRESTORE_CORE_SRC_MODEL_MUTATION_OVERLAY_H_
#define FIRESTORE_CORE_SRC_MODEL_MUTATION_OVERLAY_H_

#include <cstdlib>
#include <iosfwd>
#include <string>
#include <utility>

#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/mutation.h"

namespace firebase {
namespace firestore {
namespace model {
namespace mutation {

class Overlay;

bool operator==(const Overlay&, const Overlay&);

inline bool operator!=(const Overlay& lhs, const Overlay& rhs) {
  return !(lhs == rhs);
}

std::ostream& operator<<(std::ostream&, const Overlay&);

class Overlay {
 public:
  Overlay() = default;

  Overlay(int largest_batch_id, Mutation&& mutation) : largest_batch_id_(largest_batch_id), mutation_(std::move(mutation)) {
  }

  bool is_valid() const {
    return mutation_.is_valid();
  }

  int largest_batch_id() const {
    return largest_batch_id_;
  }

  const Mutation& mutation() const& {
    return mutation_;
  }

  Mutation&& mutation() && {
    return std::move(mutation_);
  }

  const DocumentKey& key() const {
    return mutation().key();
  }

  friend bool operator==(const Overlay&, const Overlay&);

  std::size_t Hash() const;

  std::string ToString() const;

  friend std::ostream& operator<<(std::ostream&, const Overlay&);

 private:
  int largest_batch_id_ = 0;
  Mutation mutation_;
};

}  // namespace mutation
}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_MODEL_MUTATION_OVERLAY_H_
