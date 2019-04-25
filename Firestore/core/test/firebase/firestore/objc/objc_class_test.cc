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

#include "Firestore/core/src/firebase/firestore/objc/objc_class.h"

#include "Firestore/core/test/firebase/firestore/objc/objc_class_test_helper.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace objc {

TEST(ObjcClassTest, CanSendMessages) {
  ObjcClassWrapper tester;
  tester.CreateValue();
  ASSERT_EQ("FSTObjcClassTestValue", tester.ToString());
}

TEST(ObjcClassTest, Deallocates) {
  AllocationTracker tracker;

  tracker.ScopedRun([&]() {
    ObjcClassWrapper wrapper(&tracker);
    ASSERT_EQ(1, tracker.init_calls);
    ASSERT_EQ(0, tracker.dealloc_calls);

    // Exiting the scope destroys the wrapper and its handle.
  });
  ASSERT_EQ(1, tracker.init_calls);
  ASSERT_EQ(1, tracker.dealloc_calls);
}

TEST(ObjcClassTest, MultipleReleasesAreAllowed) {
  AllocationTracker tracker;

  tracker.ScopedRun([&]() {
    ObjcClassWrapper wrapper(&tracker);
    ASSERT_EQ(0, tracker.dealloc_calls);

    // Explicitly calling Release() here means that the second call in the
    // destructor is a duplicate. This shows that multiple calls are allowed.
    //
    // Note that checking whether or not the object is deallocated after the
    // explicit release is fragile. See comments on ScopedRun for rationale.
    wrapper.handle.Release();
  });
  ASSERT_EQ(1, tracker.dealloc_calls);
}

TEST(ObjcClassTest, SupportsCopying) {
  AllocationTracker tracker;

  tracker.ScopedRun([&]() {
    ObjcClassWrapper second;

    tracker.ScopedRun([&]() {
      ObjcClassWrapper first(&tracker);
      second = first;
      ASSERT_EQ(1, tracker.init_calls);
      ASSERT_EQ(0, tracker.dealloc_calls);
    });

    // first deallocated, but the value should survive
    ASSERT_EQ(0, tracker.dealloc_calls);
  });

  // second deallocated
  ASSERT_EQ(1, tracker.dealloc_calls);
}

TEST(ObjcClassTest, SupportsMoving) {
  AllocationTracker tracker;
  ObjcClassWrapper first;

  tracker.ScopedRun([&]() {
    // Create the value separately inside the autorelease pool so that any
    // unintentional autorelease doesn't invalidate the test.
    first.CreateValue(&tracker);

    // Ownership transfered, so the value's lifetime should be bound to
    // `second`.
    ObjcClassWrapper second = std::move(first);
    ASSERT_EQ(0, tracker.dealloc_calls);
  });

  // If moving has succeeded, then `first` no longer has a reference to the
  // value and the destruction of `second` in the inner block should trigger
  // dealloc.
  ASSERT_EQ(1, tracker.dealloc_calls);
}

TEST(ObjcClassTest, Reassigns) {
  AllocationTracker tracker;

  tracker.ScopedRun([&]() {
    ObjcClassWrapper wrapper(&tracker);
    ASSERT_EQ(1, tracker.init_calls);
    ASSERT_EQ(0, tracker.dealloc_calls);

    tracker.ScopedRun([&]() {
      // Reassigning should deallocate the initial object allocated in the
      // constructor.
      ObjcClassWrapper wrapper2(&tracker);
      ASSERT_EQ(2, tracker.init_calls);
      ASSERT_EQ(0, tracker.dealloc_calls);

      wrapper.SetValue(wrapper2.handle);
      ASSERT_EQ(1, tracker.dealloc_calls);

      // Transfer ownership to the helper
    });

    ASSERT_EQ(1, tracker.dealloc_calls);
  });

  ASSERT_EQ(2, tracker.dealloc_calls);
}

}  // namespace objc
}  // namespace firestore
}  // namespace firebase
