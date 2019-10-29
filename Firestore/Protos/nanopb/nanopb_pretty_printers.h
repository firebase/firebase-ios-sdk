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

#include <sstream>
#include <string>

#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_util.h"
#include "absl/strings/str_cat.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {

namespace internal {

inline std::string Indent(int level) {
  constexpr int kIndentWidth = 2;
  return std::string(level * kIndentWidth, ' ');
}

inline std::string ToString(pb_bytes_array_t* value) {
  return absl::StrCat("\"", nanopb::ByteString(value).ToString(), "\"");
}

inline std::string ToString(bool value) {
  return value ? std::string{"true"} : std::string{"false"};
}

template <typename T>
std::string ToString(const T& value) {
  std::ostringstream stream;
  // `std::to_string` doesn't allow changing width and precision for floating
  // point values, leading to output inconsistent with "official" proto
  // libraries.
  stream << value;
  return stream.str();
}

}  // namespace internal

template <typename T>
std::string PrintMessageField(absl::string_view name,
                              const T& value,
                              int indent,
                              bool always_print) {
  auto contents = value.ToString(indent);
  if (contents.empty()) {
    if (!always_print) {
      return "";
    } else {
      return absl::StrCat(internal::Indent(indent), name, "{\n", internal::Indent(indent), "}\n");
    }
  }

  return absl::StrCat(internal::Indent(indent), name, contents, "\n");
}

template <typename T>
std::string PrintPrimitiveField(absl::string_view name, T value, int indent, bool always_print) {
  if (value == T{} && !always_print) {
    return "";
  }
  return absl::StrCat(internal::Indent(indent), name, internal::ToString(value), "\n");
}

template <typename T>
std::string PrintEnumField(absl::string_view name, T value, int indent, bool always_print) {
  if (value == T{} && !always_print) {
    return "";
  }

  return absl::StrCat(internal::Indent(indent), name, EnumToString(value), "\n");
}

template <typename T>
std::string PrintHeader(bool is_root, absl::string_view message_name, const T* message_ptr) {
  if (is_root) {
    auto p = absl::Hex{reinterpret_cast<uintptr_t>(message_ptr)};
    return absl::StrCat("<", message_name, "0x", p, ">: {\n");
  } else {
    return "{\n";
  }
}

inline std::string PrintTail(bool is_root, int indent) {
  return internal::Indent(is_root ? 0 : indent) + '}';
}

}  // namespace firestore
}  // namespace firebase

#endif  // PROTOS_NANOPB_NANOPB_PRETTY_PRINTERS_H_
