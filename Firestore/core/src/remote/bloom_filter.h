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
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/util/statusor.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace remote {

class BloomFilter final {
 public:
  BloomFilter(nanopb::ByteString bitmap, int32_t padding, int32_t hash_count);

  // Copyable & movable.
  BloomFilter(const BloomFilter&) = default;
  BloomFilter(BloomFilter&&) = default;
  BloomFilter& operator=(const BloomFilter&) = default;
  BloomFilter& operator=(BloomFilter&&) = default;

  /**
   * Creates a BloomFilter object or returns a status.
   *
   * @return a new BloomFilter if the inputs are valid, otherwise returns a not
   * `ok()` status.
   */
  static util::StatusOr<BloomFilter> Create(nanopb::ByteString bitmap,
                                            int32_t padding,
                                            int32_t hash_count);

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

  /**
   * The number of bits in the bloom filter. Guaranteed to be non-negative, and
   * less than the max number of bits the bitmap can represent, i.e.,
   * bitmap().size() * 8.
   */
  int32_t bit_count() const {
    return bit_count_;
  }

  /**
   * The number of hash functions used to construct the filter. Guaranteed to
   * be non-negative.
   */
  int32_t hash_count() const {
    return hash_count_;
  }

  /** Bloom filter's bitmap. */
  const nanopb::ByteString& bitmap() const {
    return bitmap_;
  }

 private:
  /**
   * When checking membership of a key in bitmap, the first step is to generate
   * a 128-bit hash, and treat it as 2 distinct 64-bit hash values, named `h1`
   * and `h2`, interpreted as unsigned integers using 2's complement encoding.
   */
  struct Hash {
    uint64_t h1;
    uint64_t h2;
  };

  /**
   * Calculate the MD5 digest of the given string, and return a Hash object.
   */
  Hash Md5HashDigest(absl::string_view key) const;

  /**
   * Calculate the ith hash value based on the hashed 64 bit unsigned integers,
   * and calculate its corresponding bit index in the bitmap to be checked.
   */
  int32_t GetBitIndex(const Hash& hash, int32_t hash_index) const;

  /** Return whether the bit at the given index in the bitmap is set to 1. */
  bool IsBitSet(int32_t index) const;

  int32_t bit_count_ = 0;

  int32_t hash_count_ = 0;

  nanopb::ByteString bitmap_;
};

bool operator==(const BloomFilter& lhs, const BloomFilter& rhs);

inline bool operator!=(const BloomFilter& lhs, const BloomFilter& rhs) {
  return !(lhs == rhs);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_BLOOM_FILTER_H_
