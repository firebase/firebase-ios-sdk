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

  /**
   * Runs the given code block in an autorelease pool to prevent Clang's
   * generation of implicit `autorelease` calls from interfering with the test.
   *
   * Checking whether or not an object is deallocated after the a release is
   * fragile. The problem is that Clang will sometimes infer that an object
   * should be added to the autorelease pool which typically extends the
   * lifetime of the object beyond the duration of the test. While this process
   * is predictable, it's also highly opaque and we're better off avoiding any
   * dependency on that behavior at all.
   *
   * Instead, at any point where you want to check that a deallocation happens,
   * do so after the close of a ScopedRun block. ScopedRun runs the given
   * callback in an explicit AutoRelease pool, and this guarantees that even if
   * Clang does autorelease the deallocation will actually happen by the time
   * ScopedRun returns.
   */
  void ScopedRun(const std::function<void()>& callback);
};

class ObjcClassWrapper {
 public:
  /** Creates the tester with no backing test value. */
  explicit ObjcClassWrapper(AllocationTracker* tracker = nullptr);

  void CreateValue(AllocationTracker* tracker = nullptr);

  void SetValue(Handle<FSTObjcClassTestValue> helper);

  std::string ToString() const;

  Handle<FSTObjcClassTestValue> handle;
};

}  // namespace objc
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_OBJC_OBJC_CLASS_TEST_HELPER_H_
