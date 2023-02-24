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

#ifndef FIRESTORE_CORE_SRC_REMOTE_EXISTENCE_FILTER_H_
#define FIRESTORE_CORE_SRC_REMOTE_EXISTENCE_FILTER_H_

#include "Firestore/Protos/nanopb/google/firestore/v1/bloom_filter.nanopb.h"

namespace firebase {
namespace firestore {
namespace remote {

class ExistenceFilter {
 public:
  ExistenceFilter() = default;
  explicit ExistenceFilter(int count) : count_{count} {
  }

  explicit ExistenceFilter(int count,
                           google_firestore_v1_BloomFilter unchangedNames)
      : count_{count}, unchanged_names_{unchangedNames} {
  }

  int count() const {
    return count_;
  }

  google_firestore_v1_BloomFilter unchanged_names() const {
    return unchanged_names_;
  }

 private:
  int count_ = 0;
  google_firestore_v1_BloomFilter unchanged_names_;
};

inline bool operator==(const ExistenceFilter& lhs, const ExistenceFilter& rhs) {
  return lhs.count() == rhs.count() &&
         lhs.unchanged_names().hash_count == rhs.unchanged_names().hash_count &&
         lhs.unchanged_names().bits.padding ==
             rhs.unchanged_names().bits.padding &&
         lhs.unchanged_names().bits.bitmap == rhs.unchanged_names().bits.bitmap;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_EXISTENCE_FILTER_H_
