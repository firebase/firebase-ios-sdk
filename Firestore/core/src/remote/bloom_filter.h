/*
 * Copyright 2023 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_REMOTE_BLOOM_FILTER_H_
#define FIRESTORE_CORE_SRC_REMOTE_BLOOM_FILTER_H_

#include <string>
#include <vector>
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace remote {

class BloomFilter final {
 public:
  BloomFilter(std::vector<uint8_t> bitmap, int32_t padding, int32_t hash_count);

  // Copyable & movable.
  BloomFilter(const BloomFilter&) = default;
  BloomFilter(BloomFilter&&) = default;
  BloomFilter& operator=(const BloomFilter&) = default;
  BloomFilter& operator=(BloomFilter&&) = default;

  /**
   * Check whether the given string is a possible member of the bloom filter. It
   * might return false positive result, ie, the given string is not a member of
   * the bloom filter, but the method returned true.
   *
   * @param value the string to be tested for membership.
   * @return true if the given string might be contained in the bloom filter, or
   * false if the given string is definitely not contained in the bloom filter.
   */
  bool MightContain(absl::string_view value) const;

  // Get the `bit_count_` field. Used for testing purpose.
  int32_t bit_count() const {
    return bit_count_;
  }

  // When inserting a key into bitmap, the first step is to generate k hashes
  // out of it, where we need its Hash struct representation. See
  // `InsertToBitmap()` for details.
  //
  // The steps to convert a key string into a Hash struct:
  //   - Hash the key with MD5 to obtain a 128-bit hash.
  //   - Treat the resulting 128-bit hash as 2 distinct 64-bit hash values,
  //     named `h1` and `h2`, interpreted as unsigned integers using 2's
  //     complement encoding.
  // See `BloomFilterBuilder::AddKey()` for the corresponding code and more
  // details.
  struct Hash {
    uint64_t h1;
    uint64_t h2;
  };

 private:
  // The number of bits in the bloom filter. Guaranteed to be non-negative, and
  // less than the max number of bits `bitmap_` can represent, i.e.,
  // bitmap_.size() * 8.
  int32_t bit_count_ = 0;

  // The number of hash functions used to construct the filter. Guaranteed to be
  // non-negative.
  int32_t hash_count_ = 0;

  // Bloom filter's bitmap.
  std::vector<uint8_t> bitmap_;

  BloomFilter::Hash Md5HashDigest(const absl::string_view key) const;

  int32_t GetBitIndex(const BloomFilter::Hash& hash,
                      int32_t i,
                      int32_t bit_count) const;

  bool IsBitSet(const std::vector<uint8_t>& bitmap, int32_t index) const;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_BLOOM_FILTER_H_
