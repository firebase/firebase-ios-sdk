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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_BYTE_STRING_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_BYTE_STRING_H_

#include <pb.h>

#include <cstdint>
#include <iosfwd>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/util/comparison.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace nanopb {

/**
 * A string-like object backed by a nanopb byte array.
 */
class ByteString : public util::Comparable<ByteString> {
 public:
  ByteString() = default;

  explicit ByteString(const std::vector<uint8_t>& value);

  /**
   * Creates a new ByteString whose backing byte array is a copy of the of the
   * given string.
   */
  explicit ByteString(const std::string& value);

  /**
   * Creates a new ByteString whose backing byte array is a copy of the of the
   * given string_view.
   */
  explicit ByteString(absl::string_view value);

  /**
   * Creates a new ByteString whose backing byte array is a copy of the of the
   * given C string.
   */
  explicit ByteString(const char* value);

  ByteString(const ByteString& other);

  ByteString(ByteString&& other) noexcept;

  ~ByteString();

  ByteString& operator=(ByteString other) {
    swap(*this, other);
    return *this;
  }

  /**
   * Creates a new ByteString that takes ownership of the given byte array.
   */
  static ByteString Take(pb_bytes_array_t* bytes);

  /**
   * Returns a pointer to the character data backing this ByteString. The return
   * value is `nullptr` if the backing bytes are themselves null.
   */
  const uint8_t* data() const {
    return bytes_ ? bytes_->bytes : nullptr;
  }

  size_t size() const {
    return bytes_ ? bytes_->size : 0;
  }

  bool empty() const {
    return size() == 0;
  }

  /** Returns a const view of the underlying byte array. */
  const pb_bytes_array_t* get() const {
    return bytes_;
  }

  /**
   * Returns the current byte array and assigns the backing byte array to
   * nullptr, releasing the ownership of the array contents to the caller.
   */
  pb_bytes_array_t* release();

  /**
   * Copies the backing byte array into a new vector of bytes.
   */
  std::vector<uint8_t> CopyVector() const;

  /**
   * Converts this ByteString to an absl::string_view (without changing
   * ownership).
   */
  explicit operator absl::string_view() const {
    return ToStringView(bytes_);
  }

  /**
   * Swaps the contents of the given Strings.
   */
  friend void swap(ByteString& lhs, ByteString& rhs) noexcept;

  util::ComparisonResult CompareTo(const ByteString& rhs) const;

  std::string ToString() const;
  friend std::ostream& operator<<(std::ostream& out, const ByteString& str);

 private:
  explicit ByteString(pb_bytes_array_t* bytes) : bytes_{bytes} {
  }

  static absl::string_view ToStringView(pb_bytes_array_t* bytes);

  pb_bytes_array_t* bytes_ = nullptr;
};

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_BYTE_STRING_H_
