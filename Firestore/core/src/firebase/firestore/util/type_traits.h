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

namespace firebase {
namespace firestore {
namespace util {

#if __OBJC__

/**
 * A type trait that identifies whether or not the given type is an Objective-C
 * class.
 *
 * is_objective_c_class<NSObject>::value == true
 * is_objective_c_class<NSArray<NSString*>>::value == true
 *
 * // id is a pointer to an Objective-C object, not an Objective-C class.
 * is_objective_c_class<id>::value == false
 *
 * // fundamental types and C++ classes are not Objective-C classes.
 * is_objective_c_class<int>::value == false
 * is_objective_c_class<std::string>::value == false
 */
template <typename T>
struct is_objective_c_class {
 private:
  using yes_type = char (&)[10];
  using no_type = char (&)[1];

  /**
   * A non-existent function declared to produce a pointer to type T (which is
   * consistent with the way Objective-C objects are referenced).
   *
   * Note that there is no definition for this function but that's okay because
   * we only need it to reason about the function's type at compile type.
   */
  static T* Instance();

  static yes_type Choose(id value);
  static no_type Choose(...);

 public:
  using value_type = bool;

  enum { value = sizeof(Choose(Instance())) == sizeof(yes_type) };

  constexpr operator bool() const {
    return value;
  }

  constexpr bool operator()() const {
    return value;
  }
};

#endif  // __OBJC__

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_TYPE_TRAITS_H_
