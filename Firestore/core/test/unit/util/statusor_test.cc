/*
 * Copyright 2017, 2018 Google
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

// Unit tests for StatusOr

#include "Firestore/core/src/util/statusor.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {
namespace {

using std::string;

class Base1 {
 public:
  virtual ~Base1() = default;
  int pad_;
};

class Base2 {
 public:
  virtual ~Base2() = default;
  int yetotherpad_;
};

class Derived : public Base1, public Base2 {
 public:
  ~Derived() override = default;
  int evenmorepad_;
};

class CopyNoAssign {
 public:
  explicit CopyNoAssign(int value) : foo_(value) {
  }
  CopyNoAssign(const CopyNoAssign& other) : foo_(other.foo_) {
  }
  int foo_;

 private:
  const CopyNoAssign& operator=(const CopyNoAssign&);
};

class NoDefaultConstructor {
 public:
  explicit NoDefaultConstructor(int foo);
};

static_assert(!std::is_default_constructible<NoDefaultConstructor>(),
              "Should not be default-constructible.");

StatusOr<std::unique_ptr<int>> ReturnUniquePtr() {
  // Uses implicit constructor from T&&
  return std::unique_ptr<int>(new int(0));
}

TEST(StatusOr, ElementType) {
  static_assert(std::is_same<StatusOr<int>::element_type, int>(), "");
  static_assert(std::is_same<StatusOr<char>::element_type, char>(), "");
}

TEST(StatusOr, TestNoDefaultConstructorInitialization) {
  // Explicitly initialize it with an error code.
  StatusOr<NoDefaultConstructor> statusor(Status(Error::kErrorCancelled, ""));
  EXPECT_FALSE(statusor.ok());
  EXPECT_EQ(statusor.status().code(), Error::kErrorCancelled);

  // Default construction of StatusOr initializes it with an UNKNOWN error code.
  StatusOr<NoDefaultConstructor> statusor2;
  EXPECT_FALSE(statusor2.ok());
  EXPECT_EQ(statusor2.status().code(), Error::kErrorUnknown);
}

TEST(StatusOr, TestMoveOnlyInitialization) {
  StatusOr<std::unique_ptr<int>> thing(ReturnUniquePtr());
  ASSERT_TRUE(thing.ok());
  EXPECT_EQ(0, *thing.ValueOrDie());
  int* previous = thing.ValueOrDie().get();

  thing = ReturnUniquePtr();
  ASSERT_TRUE(thing.ok());
  EXPECT_EQ(0, *thing.ValueOrDie());

  // Avoid EXPECT_NE here because that would print the pointers and what they
  // point to, but reassigning thing above deleted the memory.
  EXPECT_FALSE(previous == thing.ValueOrDie().get());
}

TEST(StatusOr, TestMoveOnlyStatusCtr) {
  StatusOr<std::unique_ptr<int>> thing(Status(Error::kErrorCancelled, ""));
  ASSERT_FALSE(thing.ok());
}

TEST(StatusOr, TestMoveOnlyValueExtraction) {
  StatusOr<std::unique_ptr<int>> thing(ReturnUniquePtr());
  ASSERT_TRUE(thing.ok());
  std::unique_ptr<int> ptr = thing.ConsumeValueOrDie();
  EXPECT_EQ(0, *ptr);

  thing = std::move(ptr);
  ptr = std::move(thing.ValueOrDie());
  EXPECT_EQ(0, *ptr);
}

TEST(StatusOr, TestMoveOnlyConversion) {
  StatusOr<std::unique_ptr<const int>> const_thing(ReturnUniquePtr());
  EXPECT_TRUE(const_thing.ok());
  EXPECT_EQ(0, *const_thing.ValueOrDie());

  // Test rvalue converting assignment
  const int* const_previous = const_thing.ValueOrDie().get();
  const_thing = ReturnUniquePtr();
  EXPECT_TRUE(const_thing.ok());
  EXPECT_EQ(0, *const_thing.ValueOrDie());

  // Avoid EXPECT_NE here because that would print the pointers and what they
  // point to, but reassigning const_thing above deleted the memory.
  EXPECT_FALSE(const_previous == const_thing.ValueOrDie().get());
}

TEST(StatusOr, TestMoveOnlyVector) {
  // Sanity check that StatusOr<MoveOnly> works in vector.
  std::vector<StatusOr<std::unique_ptr<int>>> vec;
  vec.push_back(ReturnUniquePtr());
  vec.resize(2);
  auto another_vec = std::move(vec);
  EXPECT_EQ(0, *another_vec[0].ValueOrDie());
  EXPECT_EQ(Error::kErrorUnknown, another_vec[1].status().code());
}

TEST(StatusOr, TestMoveWithValuesAndErrors) {
  StatusOr<string> status_or(string(1000, '0'));
  StatusOr<string> value1(string(1000, '1'));
  StatusOr<string> value2(string(1000, '2'));
  StatusOr<string> error1(Status(Error::kErrorUnknown, "error1"));
  StatusOr<string> error2(Status(Error::kErrorUnknown, "error2"));

  ASSERT_TRUE(status_or.ok());
  EXPECT_EQ(string(1000, '0'), status_or.ValueOrDie());

  // Overwrite the value in status_or with another value.
  status_or = std::move(value1);
  ASSERT_TRUE(status_or.ok());
  EXPECT_EQ(string(1000, '1'), status_or.ValueOrDie());

  // Overwrite the value in status_or with an error.
  status_or = std::move(error1);
  ASSERT_FALSE(status_or.ok());
  EXPECT_EQ("error1", status_or.status().error_message());

  // Overwrite the error in status_or with another error.
  status_or = std::move(error2);
  ASSERT_FALSE(status_or.ok());
  EXPECT_EQ("error2", status_or.status().error_message());

  // Overwrite the error with a value.
  status_or = std::move(value2);
  ASSERT_TRUE(status_or.ok());
  EXPECT_EQ(string(1000, '2'), status_or.ValueOrDie());
}

TEST(StatusOr, TestCopyWithValuesAndErrors) {
  StatusOr<string> status_or(string(1000, '0'));
  StatusOr<string> value1(string(1000, '1'));
  StatusOr<string> value2(string(1000, '2'));
  StatusOr<string> error1(Status(Error::kErrorUnknown, "error1"));
  StatusOr<string> error2(Status(Error::kErrorUnknown, "error2"));

  ASSERT_TRUE(status_or.ok());
  EXPECT_EQ(string(1000, '0'), status_or.ValueOrDie());

  // Overwrite the value in status_or with another value.
  status_or = value1;
  ASSERT_TRUE(status_or.ok());
  EXPECT_EQ(string(1000, '1'), status_or.ValueOrDie());

  // Overwrite the value in status_or with an error.
  status_or = error1;
  ASSERT_FALSE(status_or.ok());
  EXPECT_EQ("error1", status_or.status().error_message());

  // Overwrite the error in status_or with another error.
  status_or = error2;
  ASSERT_FALSE(status_or.ok());
  EXPECT_EQ("error2", status_or.status().error_message());

  // Overwrite the error with a value.
  status_or = value2;
  ASSERT_TRUE(status_or.ok());
  EXPECT_EQ(string(1000, '2'), status_or.ValueOrDie());

  // Verify original values unchanged.
  EXPECT_EQ(string(1000, '1'), value1.ValueOrDie());
  EXPECT_EQ("error1", error1.status().error_message());
  EXPECT_EQ("error2", error2.status().error_message());
  EXPECT_EQ(string(1000, '2'), value2.ValueOrDie());
}

TEST(StatusOr, TestDefaultCtor) {
  StatusOr<int> thing;
  EXPECT_FALSE(thing.ok());
  EXPECT_EQ(thing.status().code(), Error::kErrorUnknown);
}

TEST(StatusOrDeathTest, TestDefaultCtorValue) {
  StatusOr<int> thing;
  EXPECT_ANY_THROW(thing.ValueOrDie());

  const StatusOr<int> thing2;
  EXPECT_ANY_THROW(thing.ValueOrDie());
}

TEST(StatusOr, TestStatusCtor) {
  StatusOr<int> thing(Status(Error::kErrorCancelled, ""));
  EXPECT_FALSE(thing.ok());
  EXPECT_EQ(thing.status().code(), Error::kErrorCancelled);
}

TEST(StatusOr, TestValueCtor) {
  const int kI = 4;
  const StatusOr<int> thing(kI);
  EXPECT_TRUE(thing.ok());
  EXPECT_EQ(kI, thing.ValueOrDie());
}

TEST(StatusOr, TestCopyCtorStatusOk) {
  const int kI = 4;
  const StatusOr<int> original(kI);
  const StatusOr<int> copy(original);
  EXPECT_EQ(copy.status(), original.status());
  EXPECT_EQ(original.ValueOrDie(), copy.ValueOrDie());
}

TEST(StatusOr, TestCopyCtorStatusNotOk) {
  StatusOr<int> original(Status(Error::kErrorCancelled, ""));
  StatusOr<int> copy(original);
  EXPECT_EQ(copy.status(), original.status());
}

TEST(StatusOr, TestCopyCtorNonAssignable) {
  const int kI = 4;
  CopyNoAssign value(kI);
  StatusOr<CopyNoAssign> original(value);
  StatusOr<CopyNoAssign> copy(original);
  EXPECT_EQ(copy.status(), original.status());
  EXPECT_EQ(original.ValueOrDie().foo_, copy.ValueOrDie().foo_);
}

TEST(StatusOr, TestCopyCtorStatusOKConverting) {
  const int kI = 4;
  StatusOr<int> original(kI);
  StatusOr<double> copy(original);
  EXPECT_EQ(copy.status(), original.status());
  EXPECT_DOUBLE_EQ(original.ValueOrDie(), copy.ValueOrDie());
}

TEST(StatusOr, TestCopyCtorStatusNotOkConverting) {
  StatusOr<int> original(Status(Error::kErrorCancelled, ""));
  StatusOr<double> copy(original);
  EXPECT_EQ(copy.status(), original.status());
}

TEST(StatusOr, TestAssignmentStatusOk) {
  const int kI = 4;
  StatusOr<int> source(kI);
  StatusOr<int> target;
  target = source;
  EXPECT_EQ(target.status(), source.status());
  EXPECT_EQ(source.ValueOrDie(), target.ValueOrDie());
}

TEST(StatusOr, TestAssignmentStatusNotOk) {
  StatusOr<int> source(Status(Error::kErrorCancelled, ""));
  StatusOr<int> target;
  target = source;
  EXPECT_EQ(target.status(), source.status());
}

TEST(StatusOr, TestStatus) {
  StatusOr<int> good(4);
  EXPECT_TRUE(good.ok());
  StatusOr<int> bad(Status(Error::kErrorCancelled, ""));
  EXPECT_FALSE(bad.ok());
  EXPECT_EQ(bad.status(), Status(Error::kErrorCancelled, ""));
}

TEST(StatusOr, TestValue) {
  const int kI = 4;
  StatusOr<int> thing(kI);
  EXPECT_EQ(kI, thing.ValueOrDie());
}

TEST(StatusOr, TestValueConst) {
  const int kI = 4;
  const StatusOr<int> thing(kI);
  EXPECT_EQ(kI, thing.ValueOrDie());
}

TEST(StatusOrDeathTest, TestValueNotOk) {
  StatusOr<int> thing(Status(Error::kErrorCancelled, "cancelled"));
  EXPECT_ANY_THROW(thing.ValueOrDie());
}

TEST(StatusOrDeathTest, TestValueNotOkConst) {
  const StatusOr<int> thing(Status(Error::kErrorUnknown, ""));
  EXPECT_ANY_THROW(thing.ValueOrDie());
}

TEST(StatusOr, TestPointerDefaultCtor) {
  StatusOr<int*> thing;
  EXPECT_FALSE(thing.ok());
  EXPECT_EQ(thing.status().code(), Error::kErrorUnknown);
}

TEST(StatusOrDeathTest, TestPointerDefaultCtorValue) {
  StatusOr<int*> thing;
  EXPECT_ANY_THROW(thing.ValueOrDie());
}

TEST(StatusOr, TestPointerStatusCtor) {
  StatusOr<int*> thing(Status(Error::kErrorCancelled, ""));
  EXPECT_FALSE(thing.ok());
  EXPECT_EQ(thing.status(), Status(Error::kErrorCancelled, ""));
}

TEST(StatusOr, TestPointerValueCtor) {
  const int kI = 4;
  StatusOr<const int*> thing(&kI);
  EXPECT_TRUE(thing.ok());
  EXPECT_EQ(&kI, thing.ValueOrDie());
}

TEST(StatusOr, TestPointerCopyCtorStatusOk) {
  const int kI = 0;
  StatusOr<const int*> original(&kI);
  StatusOr<const int*> copy(original);
  EXPECT_EQ(copy.status(), original.status());
  EXPECT_EQ(original.ValueOrDie(), copy.ValueOrDie());
}

TEST(StatusOr, TestPointerCopyCtorStatusNotOk) {
  StatusOr<int*> original(Status(Error::kErrorCancelled, ""));
  StatusOr<int*> copy(original);
  EXPECT_EQ(copy.status(), original.status());
}

TEST(StatusOr, TestPointerCopyCtorStatusOKConverting) {
  Derived derived;
  StatusOr<Derived*> original(&derived);
  StatusOr<Base2*> copy(original);
  EXPECT_EQ(copy.status(), original.status());
  EXPECT_EQ(static_cast<const Base2*>(original.ValueOrDie()),
            copy.ValueOrDie());
}

TEST(StatusOr, TestPointerCopyCtorStatusNotOkConverting) {
  StatusOr<Derived*> original(Status(Error::kErrorCancelled, ""));
  StatusOr<Base2*> copy(original);
  EXPECT_EQ(copy.status(), original.status());
}

TEST(StatusOr, TestPointerAssignmentStatusOk) {
  const int kI = 0;
  StatusOr<const int*> source(&kI);
  StatusOr<const int*> target;
  target = source;
  EXPECT_EQ(target.status(), source.status());
  EXPECT_EQ(source.ValueOrDie(), target.ValueOrDie());
}

TEST(StatusOr, TestPointerAssignmentStatusNotOk) {
  StatusOr<int*> source(Status(Error::kErrorCancelled, ""));
  StatusOr<int*> target;
  target = source;
  EXPECT_EQ(target.status(), source.status());
}

TEST(StatusOr, TestPointerStatus) {
  const int kI = 0;
  StatusOr<const int*> good(&kI);
  EXPECT_TRUE(good.ok());
  StatusOr<const int*> bad(Status(Error::kErrorCancelled, ""));
  EXPECT_EQ(bad.status(), Status(Error::kErrorCancelled, ""));
}

TEST(StatusOr, TestPointerValue) {
  const int kI = 0;
  StatusOr<const int*> thing(&kI);
  EXPECT_EQ(&kI, thing.ValueOrDie());
}

TEST(StatusOr, TestPointerValueConst) {
  const int kI = 0;
  const StatusOr<const int*> thing(&kI);
  EXPECT_EQ(&kI, thing.ValueOrDie());
}

// NOTE(tucker): tensorflow::StatusOr does not support this kind
// of resize op.
// NOTE(rsgowman): We stole StatusOr from tensorflow, so this applies here too.
// TEST(StatusOr, StatusOrVectorOfUniquePointerCanResize) {
//   using EvilType = std::vector<std::unique_ptr<int>>;
//   static_assert(std::is_copy_constructible<EvilType>::value, "");
//   std::vector<StatusOr<EvilType>> v(5);
//   v.reserve(v.capacity() + 10);
// }

TEST(StatusOrDeathTest, TestPointerValueNotOk) {
  StatusOr<int*> thing(Status(Error::kErrorCancelled, "cancelled"));
  EXPECT_ANY_THROW(thing.ValueOrDie());
}

TEST(StatusOrDeathTest, TestPointerValueNotOkConst) {
  const StatusOr<int*> thing(Status(Error::kErrorCancelled, "cancelled"));
  EXPECT_ANY_THROW(thing.ValueOrDie());
}

}  // namespace
}  // namespace util
}  // namespace firestore
}  // namespace firebase
