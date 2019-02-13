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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_TYPE_TRAITS_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_TYPE_TRAITS_H_

#if __OBJC__
#import <objc/objc.h>  // for id
#endif

#include <type_traits>
#include <utility>

#include "absl/meta/type_traits.h"

namespace firebase {
namespace firestore {
namespace util {

#if __OBJC__

/**
 * A type trait that identifies whether or not the given pointer points to an
 * Objective-C object.
 *
 * is_objective_c_pointer<NSObject*>::value == true
 * is_objective_c_pointer<NSArray<NSString*>*>::value == true
 *
 * // id is a dynamically typed pointer to an Objective-C object.
 * is_objective_c_pointer<id>::value == true
 *
 * // pointers to C++ classes are not Objective-C pointers.
 * is_objective_c_pointer<void*>::value == false
 * is_objective_c_pointer<std::string*>::value == false
 * is_objective_c_pointer<std::unique_ptr<int>>::value == false
 */
template <typename T>
using is_objective_c_pointer = std::is_convertible<T, id>;

#endif  // __OBJC__

// is_iterable

template <typename T, typename = absl::void_t<>>
struct is_iterable : std::false_type {};

template <typename T>
struct is_iterable<
    T,
    absl::void_t<decltype(std::declval<T>().begin(), std::declval<T>().end())>>
    : std::true_type {};

// is_associative_container

template <typename T, typename = absl::void_t<>>
struct is_associative_container : std::false_type {};

template <typename T>
struct is_associative_container<
    T,
    absl::void_t<decltype(std::declval<typename T::mapped_type>())>>
    : std::true_type {};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_TYPE_TRAITS_H_
