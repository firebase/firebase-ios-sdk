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

#include <utility>

#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/remote/bloom_filter.h"

namespace firebase {
namespace firestore {
namespace remote {

struct BloomFilterParameters {
  nanopb::ByteString bitmap;
  int32_t padding;
  int32_t hash_count;
};

inline bool operator==(const BloomFilterParameters& lhs,
                       const BloomFilterParameters& rhs) {
  return lhs.padding == rhs.padding && lhs.hash_count == rhs.hash_count &&
         lhs.bitmap == rhs.bitmap;
}

class ExistenceFilter {
 public:
  ExistenceFilter() = default;

  ExistenceFilter(int count,
                  absl::optional<BloomFilterParameters> bloom_filter_parameters)
      : count_{count},
        bloom_filter_parameters_{std::move(bloom_filter_parameters)} {
  }

  int count() const {
    return count_;
  }

  const absl::optional<BloomFilterParameters>& bloom_filter_parameters() const {
    return bloom_filter_parameters_;
  }

 private:
  int count_ = 0;
  absl::optional<BloomFilterParameters> bloom_filter_parameters_;
};

inline bool operator==(const ExistenceFilter& lhs, const ExistenceFilter& rhs) {
  return lhs.count() == rhs.count() &&
         lhs.bloom_filter_parameters() == rhs.bloom_filter_parameters();
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_EXISTENCE_FILTER_H_
