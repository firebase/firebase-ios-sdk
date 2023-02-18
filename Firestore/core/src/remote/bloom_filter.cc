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
// #include <CommonCrypto/CommonDigest.h>
#include <openssl/md5.h>

namespace firebase {
namespace firestore {
namespace remote {

/** Helper function to hash a string using md5 hashing algorithm, and return an
 * array of 16 bytes. */
BloomFilter::Hash BloomFilter::Md5HashDigest(
    const absl::string_view key) const {
  unsigned char md5_digest[MD5_DIGEST_LENGTH];

  MD5_CTX context;
  MD5_Init(&context);
  MD5_Update(&context, key.data(), key.size());
  MD5_Final(md5_digest, &context);

  uint64_t* hash128 = reinterpret_cast<uint64_t*>(md5_digest);
  return BloomFilter::Hash{hash128[0], hash128[1]};
}

/**
 * Calculate the ith hash value based on the hashed 64 bit unsigned integers,
 * and calculate its corresponding bit index in the bitmap to be checked.
 */
int32_t BloomFilter::GetBitIndex(const BloomFilter::Hash& hash,
                                 int32_t i,
                                 int32_t bit_count) const {
  //  CHECK_GT(bit_count, 0);  // Crash ok.
  uint64_t val = hash.h1 + i * hash.h2;
  return val % bit_count;
}

/** Return whether the bit at the given index in the bitmap is set to 1. */
bool BloomFilter::IsBitSet(const std::vector<uint8_t>& bitmap,
                           int32_t index) const {
  uint8_t byteAtIndex = bitmap[index / 8];
  int offset = index % 8;
  return (byteAtIndex & (0x01 << offset)) != 0;
}

BloomFilter::BloomFilter(std::vector<uint8_t> bitmap,
                         int32_t padding,
                         int32_t hash_count) {
  if (padding < 0 || padding >= 8) {
    throw std::invalid_argument(&"Invalid padding: "[padding]);
  }
  if (hash_count < 0) {
    throw std::invalid_argument(&"Invalid hash count: "[hash_count]);
  }
  if (bitmap.size() > 0 && hash_count == 0) {
    // Only empty bloom filter can have 0 hash count.
    throw std::invalid_argument(&"Invalid hash count: "[hash_count]);
  }
  if (bitmap.size() == 0) {
    // Empty bloom filter should have 0 padding.
    if (padding != 0) {
      throw std::invalid_argument(
          &"Expected padding of 0 when bitmap length is 0, but got "[padding]);
    }
  }

  bitmap_ = bitmap;
  hash_count_ = hash_count;
  bit_count_ = bitmap.size() * 8 - padding;
}

/**
 * Check whether the given string is a possible member of the bloom filter. It
 * might return false positive result, ie, the given string is not a member of
 * the bloom filter, but the method returned true.
 *
 * @param value the string to be tested for membership.
 * @return true if the given string might be contained in the bloom filter, or
 * false if the given string is definitely not contained in the bloom filter.
 */
bool BloomFilter::MightContain(const absl::string_view value) const {
  // Empty bitmap should return false on membership check.
  if (bit_count_ == 0) return false;
  Hash hash = Md5HashDigest(value);
  // The `hash_count_` and `bit_count_` fields are guaranteed to be
  // non-negative when the `BloomFilter` object is constructed.
  for (int32_t i = 0; i < hash_count_; i++) {
    int32_t index = GetBitIndex(hash, i, bit_count_);
    if (!IsBitSet(bitmap_, index)) {
      return false;
    }
  }
  return true;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
