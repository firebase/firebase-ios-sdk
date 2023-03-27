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
#include <vector>

#include "Firestore/core/src/remote/bloom_filter.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace remote {

struct BloomFilterParameters {
  std::vector<uint8_t> bitmap;
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

  ExistenceFilter(
      int count,
      absl::optional<nanopb::Message<google_firestore_v1_BloomFilter>>
          bloom_filter)
      : count_{count}, bloom_filter_{std::move(bloom_filter)} {
  }

  int count() const {
    return count_;
  }

  const absl::optional<nanopb::Message<google_firestore_v1_BloomFilter>>&
  bloom_filter() const {
    return bloom_filter_;
  }

 private:
  int count_ = 0;
  absl::optional<nanopb::Message<google_firestore_v1_BloomFilter>>
      bloom_filter_;
};

inline bool operator==(const ExistenceFilter& lhs, const ExistenceFilter& rhs) {
  if (lhs.count() != rhs.count()) {
    return false;
  }
  if (lhs.bloom_filter().has_value() != rhs.bloom_filter().has_value()) {
    return false;
  }

  if (lhs.bloom_filter().has_value()) {
    const google_firestore_v1_BloomFilter* lhs_bloom_filter =
        lhs.bloom_filter().value().get();
    const google_firestore_v1_BloomFilter* rhs_bloom_filter =
        rhs.bloom_filter().value().get();
    if (lhs_bloom_filter->hash_count != rhs_bloom_filter->hash_count) {
      return false;
    }
    if (lhs_bloom_filter->has_bits != rhs_bloom_filter->has_bits) {
      return false;
    }
    if (lhs_bloom_filter->has_bits) {
      if (lhs_bloom_filter->bits.padding != rhs_bloom_filter->bits.padding) {
        return false;
      }
      if ((lhs_bloom_filter->bits.bitmap == nullptr) !=
          (rhs_bloom_filter->bits.bitmap == nullptr)) {
        return false;
      }
      if (lhs_bloom_filter->bits.bitmap != nullptr) {
        const absl::string_view lhs_bitmap(
            reinterpret_cast<const char*>(lhs_bloom_filter->bits.bitmap->bytes),
            lhs_bloom_filter->bits.bitmap->size);
        const absl::string_view rhs_bitmap(
            reinterpret_cast<const char*>(rhs_bloom_filter->bits.bitmap->bytes),
            rhs_bloom_filter->bits.bitmap->size);
        if (lhs_bitmap != rhs_bitmap) {
          return false;
        }
      }
    }
  }

  return true;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_EXISTENCE_FILTER_H_
