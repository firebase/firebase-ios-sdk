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
#include <functional>
#include <string>

#include "Firestore/core/src/firebase/firestore/objc/objc_class.h"

OBJC_CLASS(FSTObjcClassTestValue);

namespace firebase {
namespace firestore {
namespace objc {

struct AllocationTracker {
  int init_calls = 0;
  int dealloc_calls = 0;

  void Run(const std::function<void()>& callback);
};

class ObjcClassWrapper {
 public:
  /** Creates a new, unmanaged test value. */
  static FSTObjcClassTestValue* CreateTestValue();

  /** Creates the tester with no backing test value. */
  ObjcClassWrapper();

  /** Creates the tester with a backing test value. */
  explicit ObjcClassWrapper(AllocationTracker* tracker);

  void set_value(Handle<FSTObjcClassTestValue> helper);

  std::string ToString() const;

  AllocationTracker* tracker;
  Handle<FSTObjcClassTestValue> handle;
};

}  // namespace objc
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_OBJC_OBJC_CLASS_TEST_HELPER_H_
