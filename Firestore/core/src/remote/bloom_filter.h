/*
 * Copyright 2023 Google
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

#ifndef FIREBASE_CORE_SRC_REMOTE_BLOOM_FILTER_H
#define FIREBASE_CORE_SRC_REMOTE_BLOOM_FILTER_H

#include <string>
#include "absl/status/statusor.h"

namespace firebase {
namespace firestore {
namespace remote {

class BloomFilter {
 public:
  BloomFilter(std::vector<uint8_t> bitmap, int32_t padding, int32_t hash_count);

  /**
   * Check whether the given string is a possible member of the bloom filter. It
   * might return false positive result, ie, the given string is not a member of
   * the bloom filter, but the method returned true.
   *
   * @param value the string to be tested for membership.
   * @return true if the given string might be contained in the bloom filter, or
   * false if the given string is definitely not contained in the bloom filter.
   */
  bool mightContain(std::string_view value) const;

  // Get the `bit_count_` field. Used for testing purpose.
  int32_t GetBitCount() const {
    return bit_count_;
  }

 private:
  // The number of bits in the bloom filter. Guaranteed to be non-negative, and
  // less than the max number of bits `bitmap_` can represent, i.e.,
  // bitmap_.size() * 8.
  int32_t bit_count_;

  // The number of hash functions used to construct the filter. Guaranteed to be
  // non-negative.
  int32_t hash_count_;

  // Bloom filter's bitmap.
  std::vector<uint8_t> bitmap_;

 public:
  virtual ~BloomFilter() = default;

  // Copyable & movable.
  BloomFilter(const BloomFilter&) = default;
  BloomFilter(BloomFilter&&) = default;
  BloomFilter& operator=(const BloomFilter&) = default;
  BloomFilter& operator=(BloomFilter&&) = default;

  bool operator==(const BloomFilter& other) const;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIREBASE_CORE_SRC_REMOTE_BLOOM_FILTER_H
