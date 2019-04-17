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

#ifndef FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_OBJC_OBJC_CLASS_TEST_HELPER_H_
#define FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_OBJC_OBJC_CLASS_TEST_HELPER_H_

#include <cstddef>
#include <string>

#include "Firestore/core/src/firebase/firestore/objc/objc_class.h"

OBJC_CLASS(FSTObjcClassTestHelper);

namespace firebase {
namespace firestore {
namespace objc {

class ObjcClassTester {
 public:
  /** Creates the tester with a backing test helper. */
  ObjcClassTester();

  /** Creates the tester with no backing test helper. */
  explicit ObjcClassTester(std::nullptr_t);

  /** Creates a new, unmanaged test helper. */
  static FSTObjcClassTestHelper* CreateHelper();

  void set_helper(FSTObjcClassTestHelper* helper);

  std::string ToString() const;

  int init_calls = 0;
  int dealloc_calls = 0;
  Handle<FSTObjcClassTestHelper> handle;
};

}  // namespace objc
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_OBJC_OBJC_CLASS_TEST_HELPER_H_
