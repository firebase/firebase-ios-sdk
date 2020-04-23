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

#include "Firestore/core/src/objc/objc_type_traits.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace objc {

TEST(TypeTraitsTest, IsObjectiveCPointer) {
  static_assert(is_objc_pointer<NSObject*>{}, "NSObject");
  static_assert(is_objc_pointer<NSString*>{}, "NSString");
  static_assert(is_objc_pointer<NSArray<NSString*>*>{}, "NSArray<NSString*>");

  static_assert(is_objc_pointer<id>{}, "id");
  static_assert(is_objc_pointer<id<NSCopying>>{}, "id<NSCopying>");

  static_assert(!is_objc_pointer<int*>{}, "int*");
  static_assert(!is_objc_pointer<void*>{}, "void*");
  static_assert(!is_objc_pointer<int>{}, "int");
  static_assert(!is_objc_pointer<void>{}, "void");

  struct Foo {};
  static_assert(!is_objc_pointer<Foo>{}, "Foo");
  static_assert(!is_objc_pointer<Foo*>{}, "Foo");
}

}  // namespace objc
}  // namespace firestore
}  // namespace firebase
