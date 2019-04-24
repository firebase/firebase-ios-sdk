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
  ObjcClassWrapper tester(nullptr);
  ASSERT_EQ("FSTObjcClassTestValue", tester.ToString());
}

TEST(ObjcClassTest, Deallocates) {
  AllocationTracker tracker;
  ObjcClassWrapper wrapper(&tracker);
  ASSERT_EQ(1, tracker.init_calls);
  ASSERT_EQ(0, tracker.dealloc_calls);

  wrapper.handle.Release();
  ASSERT_EQ(1, tracker.init_calls);
  ASSERT_EQ(1, tracker.dealloc_calls);
}

TEST(ObjcClassTest, MultipleReleasesAreAllowed) {
  AllocationTracker tracker;
  ObjcClassWrapper wrapper(&tracker);

  wrapper.handle.Release();
  ASSERT_EQ(1, tracker.dealloc_calls);

  wrapper.handle.Release();
  ASSERT_EQ(1, tracker.dealloc_calls);
}

TEST(ObjcClassTest, SupportsCopying) {
  AllocationTracker tracker;

  tracker.Run([&]() {
    ObjcClassWrapper second;

    tracker.Run([&]() {
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

  tracker.Run([&]() {
    ObjcClassWrapper second;
    tracker.Run([&]() {
      // Moving does not bump reference count.
      ObjcClassWrapper first(&tracker);
      second = std::move(first);

      ASSERT_EQ(1, tracker.init_calls);
      ASSERT_EQ(0, tracker.dealloc_calls);
    });

    ASSERT_EQ(0, tracker.dealloc_calls);
  });

  ASSERT_EQ(1, tracker.dealloc_calls);
}

TEST(ObjcClassTest, Reassigns) {
  AllocationTracker tracker;

  tracker.Run([&]() {
    ObjcClassWrapper wrapper(&tracker);
    ASSERT_EQ(1, tracker.init_calls);
    ASSERT_EQ(0, tracker.dealloc_calls);

    tracker.Run([&]() {
      // Reassigning should deallocate the initial object allocated in the
      // constructor.
      ObjcClassWrapper wrapper2(&tracker);
      wrapper.set_value(wrapper2.handle);
      ASSERT_EQ(2, tracker.init_calls);
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
