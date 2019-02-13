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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_OBJC_COMPAITBILITY_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_OBJC_COMPAITBILITY_H_

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#import <Foundation/Foundation.h>

#include <algorithm>
#include <numeric>
#include <string>
#include <type_traits>
#include <utility>

#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "Firestore/core/src/firebase/firestore/util/type_traits.h"
#include "absl/meta/type_traits.h"
#include "absl/strings/str_join.h"

namespace firebase {
namespace firestore {
namespace util {
namespace objc {

/**
 * Checks two Objective-C objects for equality using `isEqual`. Two nil objects
 * are considered equal, unlike the behavior of `isEqual`.
 */
template <typename T, typename = absl::enable_if_t<is_objective_c_pointer<T*>::value>>
bool Equals(T* lhs, T* rhs) {
  return (lhs == nil && rhs == nil) || [lhs isEqual:rhs];
}

/** Checks two C++ containers of Objective-C objects for "deep" equality. */
template <typename T, typename = absl::enable_if_t<is_iterable<T>::value>>
bool Equals(const T& lhs, const T& rhs) {
  using Ptr = typename T::value_type;
  static_assert(is_objective_c_pointer<Ptr>{}(),
                "Can only compare containers of Objective-C objects");

  return lhs.size() == rhs.size() &&
         std::equal(lhs.begin(), lhs.end(), rhs.begin(),
                    [](Ptr o1, Ptr o2) { return Equals(o1, o2); });
}

template <typename T>
std::string ToString(const T& value);

// Fallback

template <typename T>
std::string ToStringDefault(const T& value) {
  return std::to_string(value);
}

// Fallback

template <typename T>
std::string ToStringCustom(const T& value, std::false_type) {
  return ToStringDefault(value);
}

template <typename T>
std::string ToStringCustom(const T& value, std::true_type) {
  return value.ToString();
}

// Fallback

template <typename T>
std::string ObjCToString(const T& value, std::false_type) {
  return ToStringCustom(value, has_to_string<T>{});
}

template <typename T>
std::string ObjCToString(const T& value, std::true_type) {
  return MakeString([value description]);
}

// Fallback

template <typename T>
std::string ContainerToString(const T& value, std::false_type) {
  return ObjCToString(value, is_objective_c_pointer<T>{});
}

template <typename T>
std::string ContainerToString(const T& value, std::true_type) {
  std::string contents = absl::StrJoin(
      value, ", ", [](std::string* out, const typename T::value_type& element) {
        out->append(ToString(element));
      });
  return std::string{"["} + contents + "]";
}

// Fallback

template <typename T>
std::string StringToString(const T& value, std::false_type) {
  return ContainerToString(value, is_iterable<T>{});
}

template <typename T>
std::string StringToString(const T& value, std::true_type) {
  return value;
}

// Fallback

template <typename T>
std::string MapToString(const T& value, std::false_type) {
  return StringToString(value, std::is_convertible<T, std::string>{});
}

template <typename T>
std::string MapToString(const T& value, std::true_type) {
  std::string contents = absl::StrJoin(
      value, ", ", [](std::string* out, const typename T::value_type& kv) {
        out->append(
            StringFormat("%s: %s", ToString(kv.first), ToString(kv.second)));
      });
  return std::string{"{"} + contents + "}";
}

// Fallback

template <typename T>
std::string ToString(const T& value) {
  return MapToString(value, is_associative_container<T>{});
}

//////

template <typename T>
NSString* Description(const T& value) {
  return WrapNSString(ToString(value));
}

/**
 * Creates a description of C++ container of Objective-C objects, as if it were
 * an NSArray.
 */

}  // namespace objc
}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_OBJC_COMPAITBILITY_H_
