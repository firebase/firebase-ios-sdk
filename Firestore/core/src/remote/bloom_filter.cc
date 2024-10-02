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

#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/md5.h"
#include "Firestore/core/src/util/statusor.h"

namespace firebase {
namespace firestore {
namespace remote {

using nanopb::ByteString;
using util::Status;
using util::StatusOr;

namespace {
bool HasSameBits(const BloomFilter& lhs, const BloomFilter& rhs) {
  if (lhs.bit_count() != rhs.bit_count()) {
    return false;
  }
  if (lhs.bit_count() == 0) {
    return true;
  }

  const auto byte_count = static_cast<int32_t>(lhs.bitmap().size());
  const uint8_t* bitmap1 = lhs.bitmap().data();
  const uint8_t* bitmap2 = rhs.bitmap().data();

  // Compare all bytes from the bitmap, except for the last byte.
  for (int32_t i = 0; i < byte_count - 1; ++i) {
    if (bitmap1[i] != bitmap2[i]) {
      return false;
    }
  }

  // Compare the last byte, ignoring the padding.
  const int32_t padding = (byte_count * 8) - lhs.bit_count();
  const uint8_t last_byte1 = bitmap1[byte_count - 1] << padding;
  const uint8_t last_byte2 = bitmap2[byte_count - 1] << padding;

  return (last_byte1 == last_byte2);
}
}  // namespace

BloomFilter::Hash BloomFilter::Md5HashDigest(absl::string_view key) const {
  std::array<uint8_t, 16> md5_digest{util::CalculateMd5Digest(key)};

  // TODO(Mila): Handle big endian processor b/271174523.
  uint64_t* hash128 = reinterpret_cast<uint64_t*>(md5_digest.data());
  static_assert(sizeof(uint64_t[2]) == sizeof(uint8_t[16]), "");

  return Hash{hash128[0], hash128[1]};
}

int32_t BloomFilter::GetBitIndex(const Hash& hash, int32_t hash_index) const {
  HARD_ASSERT(hash_index >= 0);
  uint64_t hash_index_uint64 = static_cast<uint64_t>(hash_index);
  uint64_t bit_count_uint64 = static_cast<uint64_t>(bit_count_);

  uint64_t combined_hash = hash.h1 + (hash_index_uint64 * hash.h2);
  uint64_t bit_index = combined_hash % bit_count_uint64;

  HARD_ASSERT(bit_index <= INT32_MAX);
  return static_cast<int32_t>(bit_index);
}

bool BloomFilter::IsBitSet(int32_t index) const {
  uint8_t byte_at_index = bitmap_.data()[index / 8];
  int32_t offset = index % 8;
  return (byte_at_index & (static_cast<uint8_t>(0x01) << offset)) != 0;
}

BloomFilter::BloomFilter(ByteString bitmap, int32_t padding, int32_t hash_count)
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

StatusOr<BloomFilter> BloomFilter::Create(ByteString bitmap,
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

bool operator==(const BloomFilter& lhs, const BloomFilter& rhs) {
  return lhs.hash_count() == rhs.hash_count() && HasSameBits(lhs, rhs);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
