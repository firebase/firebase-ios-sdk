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

#include <cstdlib>
#include <functional>
#include <string>
#include <utility>

#include "Firestore/core/src/firebase/firestore/util/comparison.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace nanopb {

class String : public util::Comparable<String> {
 public:
  static pb_bytes_array_t* MakeBytesArray(absl::string_view value) {
    auto size = static_cast<pb_size_t>(value.size());

    // Allocate one extra byte for the null terminator that's not necessarily
    // there in a string_view. As long as we're making a copy, might as well
    // make a copy that can be used as a regular C string too.
    auto result = reinterpret_cast<pb_bytes_array_t*>(
        malloc(PB_BYTES_ARRAY_T_ALLOCSIZE(size) + 1));
    result->size = size;
    memcpy(result->bytes, value.data(), size);
    result->bytes[size] = '\0';

    return result;
  }

  String() {
  }

  explicit String(const char* value) : bytes_{MakeBytesArray(value)} {
  }

  explicit String(const std::string& value) : bytes_{MakeBytesArray(value)} {
  }

  explicit String(absl::string_view value) : bytes_{MakeBytesArray(value)} {
  }

  String(const String& other)
      : bytes_{MakeBytesArray(absl::string_view{other})} {
  }

  String(String&& other) noexcept : String{} {
    swap(*this, other);
  }

  ~String() {
    delete bytes_;
  }

  String& operator=(String other) {
    using std::swap;
    swap(*this, other);
    return *this;
  }

  size_t Hash() const {
    std::hash<absl::string_view>{}.operator()(absl::string_view{*this});
  }

  bool empty() const {
    return !bytes_ || bytes_->size == 0;
  }

  explicit operator absl::string_view() const {
    const char* str = reinterpret_cast<const char*>(bytes_->bytes);
    return absl::string_view{str, bytes_->size};
  }

  friend void swap(String& lhs, String& rhs) noexcept {
    using std::swap;
    swap(lhs.bytes_, rhs.bytes_);
  }

  friend bool operator==(const String& lhs, const String& rhs) {
    return absl::string_view{lhs} == absl::string_view{rhs};
  }
  friend bool operator<(const String& lhs, const String& rhs) {
    return absl::string_view{lhs} < absl::string_view{rhs};
  }

  friend bool operator==(const String& lhs, absl::string_view rhs) {
    absl::string_view lhs_view{lhs};
    return lhs_view == rhs;
  }
  friend bool operator!=(const String& lhs, absl::string_view rhs) {
    return !(lhs == rhs);
  }

 private:
  pb_bytes_array_t* bytes_ = nullptr;
};  // namespace nanopb

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_NANOPB_STRING_H_
