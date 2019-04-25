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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_NANOPB_STRING_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_NANOPB_STRING_H_

#include <pb.h>

#include <string>
#include <utility>

#include "Firestore/core/src/firebase/firestore/util/comparison.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace nanopb {

/**
 * A string-like object backed by a nanopb byte array.
 */
class String : public util::Comparable<String> {
 public:
  /**
   * Creates a new, null-terminated byte array that's a copy of the given string
   * value.
   */
  static pb_bytes_array_t* MakeBytesArray(absl::string_view value);

  String() {
  }

  /**
   * Creates a new String whose backing byte array is a copy of the of the
   * given C string.
   */
  explicit String(const char* value) : bytes_{MakeBytesArray(value)} {
  }

  /**
   * Creates a new String whose backing byte array is a copy of the of the
   * given string.
   */
  explicit String(const std::string& value) : bytes_{MakeBytesArray(value)} {
  }

  /**
   * Creates a new String whose backing byte array is a copy of the of the
   * given string_view.
   */
  explicit String(absl::string_view value) : bytes_{MakeBytesArray(value)} {
  }

  String(const String& other)
      : bytes_{MakeBytesArray(absl::string_view{other})} {
  }

  String(String&& other) noexcept : String{} {
    swap(*this, other);
  }

  ~String();

  String& operator=(String other) {
    swap(*this, other);
    return *this;
  }

  /**
   * Creates a new String that takes ownership of the given byte array.
   */
  static String Wrap(pb_bytes_array_t* bytes);

  bool empty() const {
    return !bytes_ || bytes_->size == 0;
  }

  /**
   * Returns a pointer to the character data backing this String. The return
   * value is `nullptr` if the backing bytes are themselves null.
   */
  const char* data() const {
    return bytes_ ? reinterpret_cast<const char*>(bytes_->bytes) : nullptr;
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
   * Converts this String to an absl::string_view (without changing ownership).
   */
  explicit operator absl::string_view() const {
    return ToStringView(bytes_);
  }

  /**
   * Swaps the contents of the given Strings.
   */
  friend void swap(String& lhs, String& rhs) noexcept;

  util::ComparisonResult CompareTo(const String& rhs) const;

  friend bool operator==(const String& lhs, absl::string_view rhs) {
    absl::string_view lhs_view{lhs};
    return lhs_view == rhs;
  }

  friend bool operator!=(const String& lhs, absl::string_view rhs) {
    return !(lhs == rhs);
  }

 private:
  explicit String(pb_bytes_array_t* bytes) : bytes_{bytes} {
  }

  static absl::string_view ToStringView(pb_bytes_array_t* bytes);

  pb_bytes_array_t* bytes_ = nullptr;
};

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_NANOPB_STRING_H_
