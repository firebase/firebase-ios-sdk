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

#include "bloom_filter.h"
#include <CommonCrypto/CommonDigest.h>

namespace firebase {
namespace firestore {
namespace remote {

// Helper function to hash the given key string to Hash structure using the
// MD5 hash function.
BloomFilter::Hash StringToHash(const absl::string_view key) {
  unsigned char md5_digest[CC_MD5_DIGEST_LENGTH];
  static_assert(sizeof(md5_digest) == sizeof(BloomFilter::Hash), "");

  CC_MD5_CTX context;
  CC_MD5_Init(&context);
  CC_MD5_Update(&context, key.data(), key.size());
  CC_MD5_Final(md5_digest, &context);

  uint64_t* hash128 = reinterpret_cast<uint64_t*>(md5_digest);
  // We are assuming little endian based on
  // http://g3doc/devtools/x86free/g3doc/porting.md#endianness-detection.
  return BloomFilter::Hash{hash128[0], hash128[1]};
}

// Helper function to calculate the ith hash value of the given `Hash` struct,
// and calculate its corresponding bit index in the bitmap to be set or
// checked. The caller must ensure that the `bit_count` parameter passed
// in is greater than zero.
int32_t CalculateBitIndex(const BloomFilter::Hash& hash,
                          int32_t i,
                          int32_t bit_count) {
  //  CHECK_GT(bit_count, 0);  // Crash ok.
  uint64_t val = hash.h1 + i * hash.h2;
  return val % bit_count;
}

// Return whether the bit on the given index in the bitmap is set to 1.
bool IsBitSet(const std::vector<uint8_t>& bitmap, int32_t index) {
  uint8_t byteAtIndex = bitmap[index / 8];
  int offset = index % 8;
  return (byteAtIndex & (0x01 << offset)) != 0;
}

BloomFilter::BloomFilter(std::vector<uint8_t> bitmap,
                         int32_t padding,
                         int32_t hash_count) {
  // do validation
  bitmap_ = bitmap;
  hash_count_ = hash_count;
  bit_count_ = bitmap.size() * 8 - padding;
}

bool BloomFilter::MightContain(const absl::string_view value) const {
  if (value.empty() || bit_count_ == 0) return false;
  Hash hash = StringToHash(value);
  // The `hash_count_` and `bit_count_` fields are guaranteed to be
  // non-negative when the `BloomFilter` object is constructed.
  for (int32_t i = 0; i < hash_count_; i++) {
    int32_t index = CalculateBitIndex(hash, i, bit_count_);
    if (!IsBitSet(bitmap_, index)) {
      return false;
    }
  }
  return true;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
