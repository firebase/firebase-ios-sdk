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

#ifndef FIRESTORE_CORE_SRC_MODEL_OVERLAY_H_
#define FIRESTORE_CORE_SRC_MODEL_OVERLAY_H_

#include <cstdlib>
#include <iosfwd>
#include <string>
#include <utility>

#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/mutation.h"

namespace firebase {
namespace firestore {
namespace model {

/**
 * Representation of an overlay computed by Firestore.
 *
 * Holds information about a mutation and the largest batch id in Firestore when
 * the mutation was created.
 */
class Overlay {
 public:
  Overlay() = default;

  Overlay(int largest_batch_id, Mutation mutation)
      : largest_batch_id_(largest_batch_id), mutation_(std::move(mutation)) {
  }

  int largest_batch_id() const {
    return largest_batch_id_;
  }

  const Mutation& mutation() const {
    return mutation_;
  }

  const DocumentKey& key() const {
    return mutation_.key();
  }

  std::size_t Hash() const;

  std::string ToString() const;

  friend bool operator==(const Overlay&, const Overlay&);
  friend std::ostream& operator<<(std::ostream&, const Overlay&);

 private:
  int largest_batch_id_ = -1;
  Mutation mutation_;
};

bool operator==(const Overlay&, const Overlay&);

inline bool operator!=(const Overlay& lhs, const Overlay& rhs) {
  return !(lhs == rhs);
}

std::ostream& operator<<(std::ostream&, const Overlay&);

struct OverlayHash {
  std::size_t operator()(const Overlay&) const;
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_MODEL_OVERLAY_H_
