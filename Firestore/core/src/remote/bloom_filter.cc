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

#include "Firestore/core/src/remote/bloom_filter.h"

#include <utility>

#include "CommonCrypto/CommonDigest.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/src/util/warnings.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::Status;
using util::StatusOr;

// TODO(Mila): Replace CommonCrypto with platform based MD5 calculation and
// remove suppress.
SUPPRESS_DEPRECATED_DECLARATIONS_BEGIN();

BloomFilter::Hash BloomFilter::Md5HashDigest(absl::string_view key) const {
  unsigned char md5_digest[CC_MD5_DIGEST_LENGTH];

  CC_MD5_CTX context;
  CC_MD5_Init(&context);
  CC_MD5_Update(&context, key.data(), key.size());
  CC_MD5_Final(md5_digest, &context);

  // TODO(Mila): Replace this casting with safer function (b/270568625).
  uint64_t* hash128 = reinterpret_cast<uint64_t*>(md5_digest);
  return Hash{hash128[0], hash128[1]};
}
SUPPRESS_END();

int32_t BloomFilter::GetBitIndex(const Hash& hash, int32_t hash_index) const {
  uint64_t hash_index_uint64 = static_cast<uint64_t>(hash_index);
  uint64_t bit_count_uint64 = static_cast<uint64_t>(bit_count_);

  uint64_t val = hash.h1 + (hash_index_uint64 * hash.h2);
  uint64_t bit_index = val % bit_count_uint64;

  HARD_ASSERT(bit_index <= INT32_MAX);
  return bit_index;
}

bool BloomFilter::IsBitSet(int32_t index) const {
  uint8_t byte_at_index = bitmap_[index / 8];
  int offset = index % 8;
  return (byte_at_index & (static_cast<uint8_t>(0x01) << offset)) != 0;
}

BloomFilter::BloomFilter(std::vector<uint8_t> bitmap,
                         int32_t padding,
                         int32_t hash_count)
    : bit_count_(static_cast<int32_t>(bitmap.size()) * 8 - padding),
      hash_count_(hash_count),
      bitmap_(std::move(bitmap)) {
  HARD_ASSERT(padding >= 0 && padding < 8);
  HARD_ASSERT(hash_count_ >= 0);
  // Only empty bloom filter can have 0 hash count.
  HARD_ASSERT(bitmap_.size() == 0 || hash_count_ != 0);
  // Empty bloom filter should have 0 padding.
  HARD_ASSERT(bitmap_.size() != 0 || padding == 0);
  HARD_ASSERT(bit_count_ >= 0);
}

StatusOr<BloomFilter> BloomFilter::Create(std::vector<uint8_t> bitmap,
                                          int32_t padding,
                                          int32_t hash_count) {
  if (padding < 0 || padding >= 8) {
    return Status(firestore::Error::kErrorInvalidArgument,
                  "Invalid padding: " + std::to_string(padding));
  }
  if (hash_count < 0) {
    return Status(firestore::Error::kErrorInvalidArgument,
                  "Invalid hash count: " + std::to_string(hash_count));
  }
  if (bitmap.size() > 0 && hash_count == 0) {
    // Only empty bloom filter can have 0 hash count.
    return Status(firestore::Error::kErrorInvalidArgument,
                  "Invalid hash count: " + std::to_string(hash_count));
  }
  if (bitmap.size() == 0 && padding != 0) {
    // Empty bloom filter should have 0 padding.
    return Status(firestore::Error::kErrorInvalidArgument,
                  "Expected padding of 0 when bitmap length is 0, but got " +
                      std::to_string(padding));
  }

  return BloomFilter(std::move(bitmap), padding, hash_count);
}

bool BloomFilter::MightContain(absl::string_view value) const {
  // Empty bitmap should return false on membership check.
  if (bit_count_ == 0) return false;
  Hash hash = Md5HashDigest(value);
  // The `hash_count_` and `bit_count_` fields are guaranteed to be
  // non-negative when the `BloomFilter` object is constructed.
  for (int32_t i = 0; i < hash_count_; ++i) {
    int32_t index = GetBitIndex(hash, i);
    if (!IsBitSet(index)) {
      return false;
    }
  }
  return true;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
