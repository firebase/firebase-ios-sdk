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
template <typename T>
bool Equals(T* lhs, T* rhs) {
  static_assert(is_objective_c_pointer<T*>{}(),
                "Can only compare Objective-C objects");
  return (lhs == nil && rhs == nil) || [lhs isEqual:rhs];
}

/** Checks two C++ containers of Objective-C objects for "deep" equality. */
template <typename T>
bool Equals(const T& lhs, const T& rhs) {
  using Ptr = typename T::value_type;
  static_assert(is_objective_c_pointer<Ptr>{}(),
                "Can only compare containers of Objective-C objects");

  return lhs.size() == rhs.size() &&
         std::equal(lhs.begin(), lhs.end(), rhs.begin(),
                    [](Ptr o1, Ptr o2) { return Equals(o1, o2); });
}

/** Hashes a C++ container of Objective-C objects. */
template <typename T>
size_t Hash(const T& container) {
  using Ptr = typename T::value_type;
  static_assert(is_objective_c_pointer<Ptr>{}(),
                "Can only hash containers of Objective-C objects");

  return std::accumulate(
      container.begin(), container.end(), 0u,
      [](size_t state, Ptr ptr) { return 31 * state + [ptr hash]; });
}

////////////////////////////////////////////////////////////////////////////////

template <typename T, typename = absl::void_t<>>
struct is_associative_container : std::false_type {
};
template <typename T>
struct is_associative_container<T, absl::void_t<
    decltype(std::declval<typename T::mapped_type>())>>
  : std::true_type {
};

template <typename T, typename = absl::void_t<>>
struct has_to_string : std::false_type {
};
template <typename T>
struct has_to_string<T, absl::void_t<decltype(std::declval<T>().ToString())>> : std::true_type {
};

template <typename T, typename = absl::void_t<>>
struct is_iterable : std::false_type {
};
template <typename T>
struct is_iterable<T, absl::void_t<decltype(std::declval<T>().begin(),
   std::declval<T>().end() )>> : std::true_type {
};

// template <typename T, typename = absl::void_t<>>
// struct is_objective_c_pointer2 : std::false_type {
// };
// template <typename T>
// struct is_objective_c_pointer2<T, absl::void_t<decltype(typename
//     T::mapped_type)>> : std::true_type {
// };

template <typename T>
struct is_objective_c_pointer2 : std::is_convertible<T, id> {
};


template <typename T>
std::string ToString(const T& value);

// Fallback

// template <typename T, typename B>
// std::string ToStringDefault(const T& value, B) {
//   static_assert(false, "OBC");
// }

template <typename T>
std::string ToStringDefault(const T& value, std::true_type) {
  return value.ToString();
}

// Fallback

template <typename T>
std::string ObjCToString(const T& value, std::false_type) {
  return ToStringDefault(value, has_to_string<T>{});
}

template <typename T>
std::string ObjCToString(const T& value, std::true_type) {
  return MakeString([value description]);
}

// Fallback

template <typename T>
std::string ContainerToString(const T& value, std::false_type) {
  return ObjCToString(value, is_objective_c_pointer2<T>{});
}

template <typename T>
std::string ContainerToString(const T& value, std::true_type) {
  std::string contents =
      absl::StrJoin(value, ",", [](std::string* out, const typename T::value_type& element) {
        out->append(ToString(element));
      });
  return std::string{"["} + contents + "]";
}

// Fallback

template <typename T>
std::string MapToString(const T& value, std::false_type) {
  return ContainerToString(value, is_iterable<T>{});
}

template <typename T>
std::string MapToString(const T& value, std::true_type) {
  std::string contents = absl::StrJoin(
      value, ",",
      [](std::string* out, const typename T::value_type& kv) {
        out->append(StringFormat("%s: %s", ToString(kv.first), ToString(kv.second)));
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
/*
template <typename T>
NSString* Description(const T& container) {
  using Ptr = typename T::value_type;
  static_assert(
      is_objective_c_pointer<Ptr>{}(),
      "Can only describe the contents of containers of Objective-C objects");

  std::string contents =
      absl::StrJoin(container, ",", [](std::string* out, Ptr element) {
        std::string description = MakeString([element description]);
        out->append(description);
      });
  return WrapNSString(std::string{"["} + contents + "]");
}

template <typename T, typename KeyFn, typename ValueFn>
NSString* MapDescription(const T& map,
                         const KeyFn& key_fn,
                         const ValueFn& value_fn) {
  std::string contents = absl::StrJoin(
      map, ",", [&](std::string* out, const typename T::value_type& kv) {
        std::string key_descr = key_fn(kv.first);
        std::string value_descr = value_fn(kv.second);
        out->append(StringFormat("%s: %s", key_descr, value_descr));
      });
  return WrapNSString(std::string{"{"} + contents + "}");
}

template <typename T>
NSString* MapDescription(const T& map) {
  return MapDescription(map, std::mem_fn(typename T::key_type::ToString),
                        std::mem_fn(typename T::mapped_type::ToString));
}
*/

/*
template <typename T, typename = absl::enable_if_t<is_iterable<T>>>
std::string ToString(const T& container) {
  std::string contents =
      absl::StrJoin(container, ",", [](std::string* out, Ptr element) {
        std::string description = MakeString([element description]);
        out->append(description);
      });
  return WrapNSString(std::string{"["} + contents + "]");
}

template <typename T, typename = absl::enable_if_t<has_to_string<T>>>
std::string ToString(const T& value) {
  return value.ToString();
}

template <typename T, typename = absl::enable_if_t<is_objective_c_pointer<T>>>
std::string ToString(T* objc_ptr) {
  return MakeString([objc_ptr description]);
}
*/



// template <typename T, typename = absl::enable_if_t<is_associative_container<T>>>
// std::string ToString(const T& map) {
//   return value.ToString();
// }


// template <typename T, typename Fn, typename =
// absl::enable_if_t<is_associative_container<T>>> NSString* Description(const
// T& map, const Fn& key_description_fn) {
//   using Ptr = T::mapped_type;
//   static_assert(is_objective_c_pointer(Ptr{}),
//                 "Can only describe the contents of maps of Objective-C
//                 objects");

//   std::string contents = absl::StrJoin(
//       container, ",",
//       [](std::string* out, const T::value_type& kv) {
//         std::string key_description = key_description_fn(kv.first);
//         std::string value_description = MakeString([kv.second description]);
//         out->append(absl::StringFormat("%s: %s", key_description,
//         value_description));
//       });
//   return WrapNSString(std::string{"{"} + contents + "}");
// }

}  // namespace objc
}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_OBJC_COMPAITBILITY_H_
