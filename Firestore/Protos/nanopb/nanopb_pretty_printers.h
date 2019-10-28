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

#include <algorithm>
#include <string>
#include <type_traits>

#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_util.h"
#include "absl/meta/type_traits.h"

#include <sstream>

namespace firebase {
namespace firestore {

std::string ToStringImpl(pb_bytes_array_t* value);
std::string ToStringImpl(bool value);

inline std::string Indent(int level) {
  constexpr int kIndentWidth = 2;
  return std::string(level * kIndentWidth, ' ');
}

template <typename T>
using HasToString = typename std::is_member_function_pointer<decltype(&T::ToString)>;

template <typename T>
using ScalarExceptEnum = absl::conjunction<std::is_scalar<T>, absl::negation<std::is_enum<T>>>;

template <typename T, absl::enable_if_t<ScalarExceptEnum<T>::value, int> = 0>
std::string ToStringImpl(const T& value) {
  std::ostringstream stream;
  // stream.precision();
  stream << value;
  return stream.str();
}

template <typename T, absl::enable_if_t<HasToString<T>::value, int> = 0>
std::string ToStringImpl(const T& value, int indent) {
  return value.ToString(indent);
}

inline std::string ToStringImpl(pb_bytes_array_t* value) {
  return absl::StrCat("\"", nanopb::ByteString(value).ToString(), "\"");
}

inline std::string ToStringImpl(bool value) {
  return absl::StrCat(value ? "true" : "false");
}

// PrintField

template <typename T, absl::enable_if_t<!std::is_scalar<T>::value, int> = 0>
std::string PrintField(absl::string_view name, const T& value, int indent, bool always_print = false) {
  auto contents = ToStringImpl(value, indent);
  if (contents.empty()) {
    if (!always_print) {
      return "";
    } else {
      return absl::StrCat(Indent(indent), name, "{\n", Indent(indent), "}\n");
    }
  }

  return absl::StrCat(Indent(indent), name, contents, "\n");
}

template <typename T, absl::enable_if_t<std::is_scalar<T>::value, int> = 0>
std::string PrintField(absl::string_view name, T value, int indent, bool always_print = false) {
  if (value == T{} && !always_print) {
    return "";
  }
  return absl::StrCat(Indent(indent), name, ToStringImpl(value), "\n");
}

template <typename T>
std::string PrintEnumField(absl::string_view name, T value, int indent, bool always_print) {
  if (value == T{} && !always_print) {
    return "";
  }

  return absl::StrCat(Indent(indent), name, EnumToString(value), "\n");
}

}  // namespace firestore
}  // namespace firebase

#endif  // PROTOS_NANOPB_NANOPB_PRETTY_PRINTERS_H_
