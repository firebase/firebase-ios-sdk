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

#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_string.h"

#include <cstdlib>
#include <utility>

#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_util.h"

namespace firebase {
namespace firestore {
namespace nanopb {

String::~String() {
  std::free(bytes_);
}

/* static */ pb_bytes_array_t* String::MakeBytesArray(absl::string_view value) {
  pb_size_t size = CheckedSize(value.size());

  // Allocate one extra byte for the null terminator that's not necessarily
  // there in a string_view. As long as we're making a copy, might as well
  // make a copy that won't overrun when used as a regular C string. This is
  // essentially just to make debugging easier--actual user data can have
  // embedded nulls so we shouldn't be using this as a C string under normal
  // circumstances.
  auto result = static_cast<pb_bytes_array_t*>(
      malloc(PB_BYTES_ARRAY_T_ALLOCSIZE(size) + 1));
  result->size = size;
  memcpy(result->bytes, value.data(), size);
  result->bytes[size] = '\0';

  return result;
}

pb_bytes_array_t* String::release() {
  pb_bytes_array_t* result = bytes_;
  bytes_ = nullptr;
  return result;
}

void swap(String& lhs, String& rhs) noexcept {
  using std::swap;
  swap(lhs.bytes_, rhs.bytes_);
}

util::ComparisonResult String::CompareTo(const String& rhs) const {
  return util::Compare(absl::string_view{*this}, absl::string_view{rhs});
}

/* static */ String String::Wrap(pb_bytes_array_t* bytes) {
  return String{bytes};
}

/* static */ absl::string_view String::ToStringView(pb_bytes_array_t* bytes) {
  const char* str = reinterpret_cast<const char*>(bytes->bytes);
  return absl::string_view{str, bytes->size};
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase
