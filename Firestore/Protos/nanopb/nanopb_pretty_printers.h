/*
 * Copyright 2019 Google
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

#ifndef PROTOS_NANOPB_NANOPB_PRETTY_PRINTERS_H_
#define PROTOS_NANOPB_NANOPB_PRETTY_PRINTERS_H_

#include <pb.h>

#include <string>
#include <type_traits>

#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_util.h"
#include "absl/meta/type_traits.h"
#include "google/protobuf/empty.nanopb.h"

namespace firebase {
namespace firestore {

std::string ToStringImpl(pb_bytes_array_t* value, int indent);
// std::string ToStringImpl(int32_t value);
// std::string ToStringImpl(uint32_t value);
// std::string ToStringImpl(int64_t value);
// std::string ToStringImpl(uint64_t value);
// std::string ToStringImpl(float value);
// std::string ToStringImpl(double value);

inline std::string Indent(int level) {
  constexpr int kIndentWidth = 2;
  return std::string(' ', level * kIndentWidth);
}

template <typename T>
using HasToString = typename std::is_member_function_pointer<decltype(&T::ToString)>;

template <typename T, absl::enable_if_t<std::is_fundamental<T>::value || std::is_enum<T>::value, int> = 0>
std::string ToStringImpl(const T& value, int indent) {
  return Indent(indent) + std::to_string(value);
}

template <typename T, absl::enable_if_t<HasToString<T>::value, int> = 0>
std::string ToStringImpl(const T& value, int indent) {
  return Indent(indent) + value.ToString(indent + 1);
}

template <typename T>
std::string ToStringImpl(const T* value, pb_size_t size, int indent) {
  std::string result;
  for (pb_size_t i = 0; i != size; ++i) {
    if (i != 0) {
      result += ", ";
    }
    result += Indent(indent) + ToStringImpl(value[i], indent);
  }
  return result;
}

inline std::string ToStringImpl(pb_bytes_array_t* value, int indent) {
  return Indent(indent) + nanopb::MakeString(value);
}

// std::string ToStringImpl(int32_t value) {
//   return std::to_string(value);
// }

// std::string ToStringImpl(uint32_t value) {
//   return std::to_string(value);
// }

// std::string ToStringImpl(int64_t value) {
//   return std::to_string(value);
// }

// std::string ToStringImpl(uint64_t value) {
//   return std::to_string(value);
// }

// std::string ToStringImpl(float value) {
//   return std::to_string(value);
// }

// std::string ToStringImpl(double value) {
//   return std::to_string(value);
// }

// std::string ToStringImpl(bool value) {
//   return value ? "true" : "false";
// }

}
}  // namespace firebase

#endif  // PROTOS_NANOPB_NANOPB_PRETTY_PRINTERS_H_
