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

#include <objc/objc.h>

#include "Firestore/core/test/firebase/firestore/objc/objc_class_test_helper.h"
#include "gtest/gtest.h"

// Runtime function that's not declared anywhere I can find, but specified here
// https://clang.llvm.org/docs/AutomaticReferenceCounting.html#void-objc-release-id-value
//
// This should be declared as taking `id`, but this declaration makes it easier
// to invoke without casting in the tests below.
extern "C" void objc_release(void* value);

namespace firebase {
namespace firestore {
namespace objc {

TEST(ObjcClassTest, CanSendMessages) {
  ObjcClassTester tester;
  ASSERT_EQ("hello world", tester.ToString());
}

TEST(ObjcClassTest, Deallocates) {
  ObjcClassTester tester;
  ASSERT_EQ(1, tester.init_calls);
  ASSERT_EQ(0, tester.dealloc_calls);

  tester.handle.Release();
  ASSERT_EQ(1, tester.init_calls);
  ASSERT_EQ(1, tester.dealloc_calls);
}

TEST(ObjcClassTest, RetainsBehaveAsExpected) {
  ObjcClassTester tester(nullptr);
  ASSERT_EQ(0, tester.init_calls);
  ASSERT_EQ(0, tester.dealloc_calls);

  // This is plain C++, so ARC isn't managing this pointer. Initial retain count
  // is 1 though.
  FSTObjcClassTestHelper* helper = ObjcClassTester::CreateHelper();

  // Assign to the handle, bumping retain count
  tester.set_helper(helper);
  ASSERT_EQ(0, tester.init_calls);
  ASSERT_EQ(0, tester.dealloc_calls);

  // Transfer ownership to the helper
  objc_release(helper);
  ASSERT_EQ(0, tester.dealloc_calls);

  // And release
  tester.handle.Release();
  ASSERT_EQ(1, tester.dealloc_calls);
}

TEST(ObjcClassTest, Reassigns) {
  ObjcClassTester tester;
  ASSERT_EQ(1, tester.init_calls);
  ASSERT_EQ(0, tester.dealloc_calls);

  // Reassigning should deallocate the initial object allocated in the
  // constructor.
  FSTObjcClassTestHelper* helper = ObjcClassTester::CreateHelper();
  tester.set_helper(helper);
  ASSERT_EQ(1, tester.init_calls);
  ASSERT_EQ(1, tester.dealloc_calls);

  // Transfer ownership to the helper
  objc_release(helper);
  ASSERT_EQ(1, tester.dealloc_calls);

  tester.handle.Release();
  ASSERT_EQ(2, tester.dealloc_calls);
}

}  // namespace objc
}  // namespace firestore
}  // namespace firebase
