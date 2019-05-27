/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/nanopb/byte_string.h"

#include <cstdlib>
#include <cstring>
#include <ostream>

#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_util.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"
#include "Firestore/core/src/firebase/firestore/util/range.h"
#include "absl/strings/escaping.h"

namespace firebase {
namespace firestore {
namespace nanopb {

namespace {

/**
 * Creates a new, null-terminated byte array that's a copy of the given string
 * value.
 */
pb_bytes_array_t* MakeBytesArray(const uint8_t* data, size_t size) {
  pb_size_t pb_size = CheckedSize(size);

  // Allocate one extra byte for the null terminator that's not necessarily
  // there in a string_view. As long as we're making a copy, might as well
  // make a copy that won't overrun when used as a regular C string. This is
  // essentially just to make debugging easier--actual user data can have
  // embedded nulls so we shouldn't be using this as a C string under normal
  // circumstances.
  auto result = static_cast<pb_bytes_array_t*>(
      std::malloc(PB_BYTES_ARRAY_T_ALLOCSIZE(pb_size) + 1));
  result->size = pb_size;
  std::memcpy(result->bytes, data, pb_size);
  result->bytes[pb_size] = '\0';

  return result;
}

pb_bytes_array_t* MakeBytesArray(const char* data, size_t size) {
  return MakeBytesArray(reinterpret_cast<const uint8_t*>(data), size);
}

}  // namespace

ByteString::ByteString(const std::vector<uint8_t>& value)
    : bytes_(MakeBytesArray(value.data(), value.size())) {
}

ByteString::ByteString(const pb_bytes_array_t* bytes)
    : bytes_{MakeBytesArray(bytes->bytes, bytes->size)} {
}

ByteString::ByteString(const std::string& value)
    : bytes_{MakeBytesArray(value.data(), value.size())} {
}

ByteString::ByteString(absl::string_view value)
    : bytes_{MakeBytesArray(value.data(), value.size())} {
}

ByteString::ByteString(std::initializer_list<uint8_t> value)
    : bytes_{MakeBytesArray(value.begin(), value.size())} {
}

ByteString::ByteString(const char* value)
    : bytes_{MakeBytesArray(value, std::strlen(value))} {
}

ByteString::ByteString(const ByteString& other)
    : bytes_{MakeBytesArray(other.data(), other.size())} {
}

ByteString::ByteString(ByteString&& other) noexcept : ByteString{} {
  swap(*this, other);
}

ByteString::~ByteString() {
  std::free(bytes_);
}

/* static */ ByteString ByteString::Take(pb_bytes_array_t* bytes) {
  return ByteString{bytes};
}

pb_bytes_array_t* ByteString::release() {
  pb_bytes_array_t* result = bytes_;
  bytes_ = nullptr;
  return result;
}

std::vector<uint8_t> ByteString::ToVector() const {
  HARD_ASSERT(bytes_ != nullptr);
  return std::vector<uint8_t>{bytes_->bytes, bytes_->bytes + bytes_->size};
}

void swap(ByteString& lhs, ByteString& rhs) noexcept {
  using std::swap;
  swap(lhs.bytes_, rhs.bytes_);
}

util::ComparisonResult ByteString::CompareTo(const ByteString& rhs) const {
  return util::Compare(absl::string_view{*this}, absl::string_view{rhs});
}

size_t ByteString::Hash() const {
  return util::Hash(util::make_range(begin(), end()));
}

std::string ByteString::ToString() const {
  std::string hex = absl::BytesToHexString(ToStringView(bytes_));
  return absl::StrCat("<", hex, ">");
}

std::ostream& operator<<(std::ostream& out, const ByteString& str) {
  return out << str.ToString();
}

/* static */ absl::string_view ByteString::ToStringView(
    pb_bytes_array_t* bytes) {
  const char* str = reinterpret_cast<const char*>(bytes->bytes);
  return absl::string_view{str, bytes->size};
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase
