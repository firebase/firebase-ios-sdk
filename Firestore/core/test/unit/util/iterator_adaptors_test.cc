/*
 * Copyright 2005, 2018 Google
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

#include "Firestore/core/src/util/iterator_adaptors.h"

#include <iterator>
#include <list>
#include <map>
#include <memory>
#include <set>
#include <string>
#include <type_traits>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

#include "absl/base/macros.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

using std::unordered_map;
using std::unordered_set;

using firebase::firestore::util::deref_second_view;
using firebase::firestore::util::deref_view;
using firebase::firestore::util::iterator_first;
using firebase::firestore::util::iterator_ptr;
using firebase::firestore::util::iterator_second;
using firebase::firestore::util::iterator_second_ptr;
using firebase::firestore::util::key_view;
using firebase::firestore::util::key_view_type;
using firebase::firestore::util::make_iterator_first;
using firebase::firestore::util::make_iterator_ptr;
using firebase::firestore::util::make_iterator_second;
using firebase::firestore::util::make_iterator_second_ptr;
using firebase::firestore::util::value_view;
using firebase::firestore::util::value_view_type;
using testing::ElementsAre;
using testing::Eq;
using testing::IsEmpty;
using testing::Not;
using testing::Pair;
using testing::Pointwise;
using testing::SizeIs;

namespace {

const char* kFirst[] = {"foo", "bar"};
int kSecond[] = {1, 2};
const int kCount = ABSL_ARRAYSIZE(kFirst);

template <typename T>
struct IsConst : std::false_type {};
template <typename T>
struct IsConst<const T> : std::true_type {};
template <typename T>
struct IsConst<T&> : IsConst<T> {};

class IteratorAdaptorTest : public testing::Test {
 protected:
  // Objects declared here can be used by all tests in the test case for Foo.

  virtual void SetUp() {
    ASSERT_EQ(ABSL_ARRAYSIZE(kFirst), ABSL_ARRAYSIZE(kSecond));
  }

  virtual void TearDown() {
  }

  template <typename T>
  class InlineStorageIter : public std::iterator<std::input_iterator_tag, T> {
   public:
    T* operator->() const {
      return get();
    }
    T& operator*() const {
      return *get();
    }

   private:
    T* get() const {
      return &v_;
    }
    mutable T v_;
  };

  struct X {
    int d;
  };
};

TEST_F(IteratorAdaptorTest, HashMapFirst) {
  // Adapts an iterator to return the first value of a unordered_map::iterator.
  typedef unordered_map<std::string, int> my_container;
  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values[kFirst[i]] = kSecond[i];
  }
  for (iterator_first<my_container::iterator> it = values.begin();
       it != values.end(); ++it) {
    ASSERT_GT(it->length(), 0u);
  }
}

TEST_F(IteratorAdaptorTest, IteratorPtrUniquePtr) {
  // Tests iterator_ptr with a vector<unique_ptr<int>>.
  typedef std::vector<std::unique_ptr<int>> my_container;
  typedef iterator_ptr<my_container::iterator> my_iterator;
  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values.push_back(std::unique_ptr<int>(new int(kSecond[i])));
  }
  int i = 0;
  for (my_iterator it = values.begin(); it != values.end(); ++it, ++i) {
    int v = *it;
    *it = v;
    ASSERT_EQ(v, kSecond[i]);
  }
}

TEST_F(IteratorAdaptorTest, IteratorFirstConvertsToConst) {
  // Adapts an iterator to return the first value of a unordered_map::iterator.
  typedef unordered_map<std::string, int> my_container;
  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values[kFirst[i]] = kSecond[i];
  }
  iterator_first<my_container::iterator> iter = values.begin();
  iterator_first<my_container::const_iterator> c_iter = iter;
  for (; c_iter != values.end(); ++c_iter) {
    ASSERT_GT(c_iter->length(), 0u);
  }
}

TEST_F(IteratorAdaptorTest, IteratorFirstConstEqNonConst) {
  // verify that const and non-const iterators return the same reference.
  typedef std::vector<std::pair<int, int>> my_container;
  typedef iterator_first<my_container::iterator> my_iterator;
  typedef iterator_first<my_container::const_iterator> my_const_iterator;
  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values.push_back(std::make_pair(i, i + 1));
  }
  my_iterator iter1 = values.begin();
  const my_iterator iter2 = iter1;
  my_const_iterator c_iter1 = iter1;
  const my_const_iterator c_iter2 = c_iter1;
  for (int i = 0; i < kCount; ++i) {
    int& v1 = iter1[i];
    int& v2 = iter2[i];
    EXPECT_EQ(&v1, &values[i].first);
    EXPECT_EQ(&v1, &v2);
    const int& cv1 = c_iter1[i];
    const int& cv2 = c_iter2[i];
    EXPECT_EQ(&cv1, &values[i].first);
    EXPECT_EQ(&cv1, &cv2);
  }
}

TEST_F(IteratorAdaptorTest, HashMapSecond) {
  // Adapts an iterator to return the second value of a unordered_map::iterator.
  typedef unordered_map<std::string, int> my_container;
  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values[kFirst[i]] = kSecond[i];
  }
  for (iterator_second<my_container::iterator> it = values.begin();
       it != values.end(); ++it) {
    int v = *it;
    ASSERT_GT(v, 0);
  }
}

TEST_F(IteratorAdaptorTest, IteratorSecondConvertsToConst) {
  // Adapts an iterator to return the first value of a unordered_map::iterator.
  typedef unordered_map<std::string, int> my_container;
  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values[kFirst[i]] = kSecond[i];
  }
  iterator_second<my_container::iterator> iter = values.begin();
  iterator_second<my_container::const_iterator> c_iter = iter;
  for (; c_iter != values.end(); ++c_iter) {
    int v = *c_iter;
    ASSERT_GT(v, 0);
  }
}

TEST_F(IteratorAdaptorTest, IteratorSecondConstEqNonConst) {
  // verify that const and non-const iterators return the same reference.
  typedef std::vector<std::pair<int, int>> my_container;
  typedef iterator_second<my_container::iterator> my_iterator;
  typedef iterator_second<my_container::const_iterator> my_const_iterator;
  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values.push_back(std::make_pair(i, i + 1));
  }
  my_iterator iter1 = values.begin();
  const my_iterator iter2 = iter1;
  my_const_iterator c_iter1 = iter1;
  const my_const_iterator c_iter2 = c_iter1;
  for (int i = 0; i < kCount; ++i) {
    int& v1 = iter1[i];
    int& v2 = iter2[i];
    EXPECT_EQ(&v1, &values[i].second);
    EXPECT_EQ(&v1, &v2);
    const int& cv1 = c_iter1[i];
    const int& cv2 = c_iter2[i];
    EXPECT_EQ(&cv1, &values[i].second);
    EXPECT_EQ(&cv1, &cv2);
  }
}

TEST_F(IteratorAdaptorTest, IteratorSecondPtrConvertsToConst) {
  // Adapts an iterator to return the first value of a unordered_map::iterator.
  typedef unordered_map<std::string, int*> my_container;
  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values[kFirst[i]] = &kSecond[i];
  }
  iterator_second_ptr<my_container::iterator> iter = values.begin();
  iterator_second_ptr<my_container::const_iterator> c_iter = iter;
  for (; c_iter != values.end(); ++c_iter) {
    int v = *c_iter;
    ASSERT_GT(v, 0);
  }
}

TEST_F(IteratorAdaptorTest, IteratorSecondPtrConstMap) {
  typedef const std::map<int, int*> ConstMap;
  ConstMap empty_map;

  iterator_second_ptr<ConstMap::const_iterator> it(empty_map.begin());
  ASSERT_TRUE(it == make_iterator_second_ptr(empty_map.end()));
  if ((false)) {
    // Just checking syntax/compilation/type-checking.
    // iterator_second_ptr<ConstMap::const_iterator>::value_type* v1 = &*it;
    iterator_second_ptr<ConstMap::const_iterator>::pointer v1 = &*it;
    iterator_second_ptr<ConstMap::const_iterator>::pointer v2 =
        &*it.operator->();
    if (&v1 != &v2) v1 = v2;
  }
}

TEST_F(IteratorAdaptorTest, IteratorPtrConst) {
  // This is a regression test for a const-related bug that bit CL 47984515,
  // where a client created an iterator whose value type was "T* const".
  std::map<int*, int> m;
  make_iterator_ptr(make_iterator_first(m.begin()));
}

TEST_F(IteratorAdaptorTest, IteratorSecondPtrConstEqNonConst) {
  // verify that const and non-const iterators return the same reference.
  typedef std::vector<std::pair<int, int*>> my_container;
  typedef iterator_second_ptr<my_container::iterator> my_iterator;
  typedef iterator_second_ptr<my_container::const_iterator> my_const_iterator;
  my_container values;
  int ivalues[kCount];
  for (int i = 0; i < kCount; ++i) {
    ivalues[i] = i;
    values.push_back(std::make_pair(i, &ivalues[i]));
  }
  my_iterator iter1 = values.begin();
  const my_iterator iter2 = iter1;
  my_const_iterator c_iter1 = iter1;
  const my_const_iterator c_iter2 = c_iter1;
  for (int i = 0; i < kCount; ++i) {
    int& v1 = iter1[i];
    int& v2 = iter2[i];
    EXPECT_EQ(&v1, &ivalues[i]);
    EXPECT_EQ(&v1, &v2);
    const int& cv1 = c_iter1[i];
    const int& cv2 = c_iter2[i];
    EXPECT_EQ(&cv1, &ivalues[i]);
    EXPECT_EQ(&cv1, &cv2);
  }
}

TEST_F(IteratorAdaptorTest, HashMapFirstConst) {
  // Adapts an iterator to return the first value of a
  // unordered_map::const_iterator.
  typedef unordered_map<std::string, int> my_container;
  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values[kFirst[i]] = kSecond[i];
  }
  const unordered_map<std::string, int>* cvalues = &values;
  for (iterator_first<my_container::const_iterator> it = cvalues->begin();
       it != cvalues->end(); ++it) {
    ASSERT_GT(it->length(), 0u);
  }
}

TEST_F(IteratorAdaptorTest, ListFirst) {
  // Adapts an iterator to return the first value of a list::iterator.
  typedef std::pair<std::string, int> my_pair;
  typedef std::list<my_pair> my_list;
  my_list values;
  for (int i = 0; i < kCount; ++i) {
    values.push_back(my_pair(kFirst[i], kSecond[i]));
  }
  int i = 0;
  for (iterator_first<my_list::iterator> it = values.begin();
       it != values.end(); ++it) {
    ASSERT_EQ(*it, kFirst[i++]);
  }
}

TEST_F(IteratorAdaptorTest, ListSecondConst) {
  // Adapts an iterator to return the second value from a list::const_iterator.
  typedef std::pair<std::string, int> my_pair;
  typedef std::list<my_pair> my_list;
  my_list values;
  for (int i = 0; i < kCount; ++i) {
    values.push_back(my_pair(kFirst[i], kSecond[i]));
  }
  int i = 0;
  const my_list* cvalues = &values;
  for (iterator_second<my_list::const_iterator> it = cvalues->begin();
       it != cvalues->end(); ++it) {
    ASSERT_EQ(*it, kSecond[i++]);
  }
}

TEST_F(IteratorAdaptorTest, VectorSecond) {
  // Adapts an iterator to return the second value of a vector::iterator.
  std::vector<std::pair<std::string, int>> values;
  for (int i = 0; i < kCount; ++i) {
    values.push_back(std::pair<std::string, int>(kFirst[i], kSecond[i]));
  }
  int i = 0;
  for (iterator_second<std::vector<std::pair<std::string, int>>::iterator> it =
           values.begin();
       it != values.end(); ++it) {
    ASSERT_EQ(*it, kSecond[i++]);
  }
}

// Tests iterator_second_ptr with a map where values are regular pointers.
TEST_F(IteratorAdaptorTest, HashMapSecondPtr) {
  typedef unordered_map<std::string, int*> my_container;
  typedef iterator_second_ptr<my_container::iterator> my_iterator;
  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values[kFirst[i]] = kSecond + i;
  }
  for (my_iterator it = values.begin(); it != values.end(); ++it) {
    int v = *it;

    // Make sure the iterator reference type is assignable ("int&" and not
    // "const int&").  If it isn't, this becomes a compile-time error.
    *it = v;

    ASSERT_GT(v, 0);
  }
}

// Tests iterator_second_ptr with a map where values are wrapped into
// linked_ptr.
TEST_F(IteratorAdaptorTest, HashMapSecondPtrLinkedPtr) {
  typedef unordered_map<std::string, std::shared_ptr<int>> my_container;
  typedef iterator_second_ptr<my_container::iterator> my_iterator;
  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values[kFirst[i]].reset(new int(kSecond[i]));
  }
  for (my_iterator it = values.begin(); it != values.end(); ++it) {
    ASSERT_EQ(&*it, it.operator->());
    int v = *it;
    *it = v;
    ASSERT_GT(v, 0);
  }
}

// Tests iterator_ptr with a vector where values are regular pointers.
TEST_F(IteratorAdaptorTest, IteratorPtrPtr) {
  typedef std::vector<int*> my_container;
  typedef iterator_ptr<my_container::iterator> my_iterator;
  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values.push_back(kSecond + i);
  }
  int i = 0;
  for (my_iterator it = values.begin(); it != values.end(); ++it, ++i) {
    int v = *it;
    *it = v;
    ASSERT_EQ(v, kSecond[i]);
  }
}

TEST_F(IteratorAdaptorTest, IteratorPtrExplicitPtrType) {
  struct A {};
  struct B : A {};
  std::vector<B*> v;
  const std::vector<B*>& cv = v;
  iterator_ptr<std::vector<B*>::iterator, A*> ip(v.begin());
  iterator_ptr<std::vector<B*>::const_iterator, A*> cip(cv.begin());
}

TEST_F(IteratorAdaptorTest, IteratorPtrtConstEqNonConst) {
  // verify that const and non-const iterators return the same reference.
  typedef std::vector<int*> my_container;
  typedef iterator_ptr<my_container::iterator> my_iterator;
  typedef iterator_ptr<my_container::const_iterator> my_const_iterator;
  my_container values;

  for (int i = 0; i < kCount; ++i) {
    values.push_back(kSecond + i);
  }
  my_iterator iter1 = values.begin();
  const my_iterator iter2 = iter1;
  my_const_iterator c_iter1 = iter1;
  const my_const_iterator c_iter2 = iter1;
  for (int i = 0; i < kCount; ++i) {
    int& v1 = iter1[i];
    int& v2 = iter2[i];
    EXPECT_EQ(&v1, kSecond + i);
    EXPECT_EQ(&v1, &v2);
    const int& cv1 = c_iter1[i];
    const int& cv2 = c_iter2[i];
    EXPECT_EQ(&cv1, kSecond + i);
    EXPECT_EQ(&cv1, &cv2);
  }
}

// Tests iterator_ptr with a vector where values are wrapped into
// std::shared_ptr.
TEST_F(IteratorAdaptorTest, IteratorPtrLinkedPtr) {
  typedef std::vector<std::shared_ptr<int>> my_container;
  typedef iterator_ptr<my_container::iterator> my_iterator;
  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values.push_back(std::make_shared<int>(kSecond[i]));
  }
  int i = 0;
  for (my_iterator it = values.begin(); it != values.end(); ++it, ++i) {
    ASSERT_EQ(&*it, it.operator->());
    int v = *it;
    *it = v;
    ASSERT_EQ(v, kSecond[i]);
  }
}

TEST_F(IteratorAdaptorTest, IteratorPtrConvertsToConst) {
  int value = 1;
  std::vector<int*> values;
  values.push_back(&value);
  iterator_ptr<std::vector<int*>::iterator> iter = values.begin();
  iterator_ptr<std::vector<int*>::const_iterator> c_iter = iter;
  EXPECT_EQ(1, *c_iter);
}

TEST_F(IteratorAdaptorTest, IteratorFirstHasRandomAccessMethods) {
  typedef std::vector<std::pair<std::string, int>> my_container;
  typedef iterator_first<my_container::iterator> my_iterator;

  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values.push_back(std::pair<std::string, int>(kFirst[i], kSecond[i]));
  }

  my_iterator it1 = values.begin(), it2 = values.end();

  EXPECT_EQ(kCount, it2 - it1);
  EXPECT_TRUE(it1 < it2);
  it1 += kCount;
  EXPECT_TRUE(it1 == it2);
  it1 -= kCount;
  EXPECT_EQ(kFirst[0], *it1);
  EXPECT_EQ(kFirst[1], *(it1 + 1));
  EXPECT_TRUE(it1 == it2 - kCount);
  EXPECT_TRUE(kCount + it1 == it2);
  EXPECT_EQ(kFirst[1], it1[1]);
  it2[-1] = "baz";
  EXPECT_EQ("baz", values[kCount - 1].first);
}

TEST_F(IteratorAdaptorTest, IteratorSecondHasRandomAccessMethods) {
  typedef std::vector<std::pair<std::string, int>> my_container;
  typedef iterator_second<my_container::iterator> my_iterator;

  my_container values;
  for (int i = 0; i < kCount; ++i) {
    values.push_back(std::pair<std::string, int>(kFirst[i], kSecond[i]));
  }

  my_iterator it1 = values.begin(), it2 = values.end();

  EXPECT_EQ(kCount, it2 - it1);
  EXPECT_TRUE(it1 < it2);
  it1 += kCount;
  EXPECT_TRUE(it1 == it2);
  it1 -= kCount;
  EXPECT_EQ(kSecond[0], *it1);
  EXPECT_EQ(kSecond[1], *(it1 + 1));
  EXPECT_TRUE(it1 == it2 - kCount);
  EXPECT_TRUE(kCount + it1 == it2);
  EXPECT_EQ(kSecond[1], it1[1]);
  it2[-1] = 99;
  EXPECT_EQ(99, values[kCount - 1].second);
}

TEST_F(IteratorAdaptorTest, IteratorSecondPtrHasRandomAccessMethods) {
  typedef std::vector<std::pair<std::string, int*>> my_container;
  typedef iterator_second_ptr<my_container::iterator> my_iterator;

  ASSERT_GE(kCount, 2);
  int value1 = 17;
  int value2 = 99;
  my_container values;
  values.push_back(std::pair<std::string, int*>(kFirst[0], &value1));
  values.push_back(std::pair<std::string, int*>(kFirst[1], &value2));

  my_iterator it1 = values.begin(), it2 = values.end();

  EXPECT_EQ(2, it2 - it1);
  EXPECT_TRUE(it1 < it2);
  it1 += 2;
  EXPECT_TRUE(it1 == it2);
  it1 -= 2;
  EXPECT_EQ(17, *it1);
  EXPECT_EQ(99, *(it1 + 1));
  EXPECT_TRUE(it1 == it2 - 2);
  EXPECT_TRUE(2 + it1 == it2);
  EXPECT_EQ(99, it1[1]);
  it2[-1] = 88;
  EXPECT_EQ(88, value2);
}

TEST_F(IteratorAdaptorTest, IteratorPtrHasRandomAccessMethods) {
  typedef std::vector<int*> my_container;
  typedef iterator_ptr<my_container::iterator> my_iterator;

  int value1 = 17;
  int value2 = 99;
  my_container values;
  values.push_back(&value1);
  values.push_back(&value2);

  my_iterator it1 = values.begin(), it2 = values.end();

  EXPECT_EQ(2, it2 - it1);
  EXPECT_TRUE(it1 < it2);
  it1 += 2;
  EXPECT_TRUE(it1 == it2);
  it1 -= 2;
  EXPECT_EQ(17, *it1);
  EXPECT_EQ(99, *(it1 + 1));
  EXPECT_TRUE(it1 == it2 - 2);
  EXPECT_TRUE(2 + it1 == it2);
  EXPECT_EQ(99, it1[1]);
  it2[-1] = 88;
  EXPECT_EQ(88, value2);
}

class MyInputIterator
    : public std::iterator<std::input_iterator_tag, const int*> {
 public:
  explicit MyInputIterator(int* x) : x_(x) {
  }
  const int* operator*() const {
    return x_;
  }
  MyInputIterator& operator++() {
    ++*x_;
    return *this;
  }

 private:
  int* x_;
};

TEST_F(IteratorAdaptorTest, IteratorPtrCanWrapInputIterator) {
  int x = 0;
  MyInputIterator it(&x);
  iterator_ptr<MyInputIterator> it1(it);

  EXPECT_EQ(0, *it1);
  ++it1;
  EXPECT_EQ(1, *it1);
  ++it1;
  EXPECT_EQ(2, *it1);
  ++it1;
}

// Tests that a default-constructed adaptor is equal to an adaptor explicitly
// constructed with a default underlying iterator.
TEST_F(IteratorAdaptorTest, DefaultAdaptorConstructorUsesDefaultValue) {
  iterator_first<std::pair<int, int>*> first_default;
  iterator_first<std::pair<int, int>*> first_null(nullptr);
  ASSERT_TRUE(first_default == first_null);

  iterator_second<std::pair<int, int>*> second_default;
  iterator_second<std::pair<int, int>*> second_null(nullptr);
  ASSERT_TRUE(second_default == second_null);

  iterator_second_ptr<std::pair<int, int*>*> second_ptr_default;
  iterator_second_ptr<std::pair<int, int*>*> second_ptr_null(nullptr);
  ASSERT_TRUE(second_ptr_default == second_ptr_null);

  iterator_ptr<int**> ptr_default;
  iterator_ptr<int**> ptr_null(nullptr);
  ASSERT_TRUE(ptr_default == ptr_null);
}

// Non C++11 test.
TEST_F(IteratorAdaptorTest, ValueView) {
  typedef unordered_map<int, std::string> MapType;
  MapType my_map;
  my_map[0] = "a";
  my_map[1] = "b";
  my_map[2] = "c";
  const MapType c_map(my_map);

  std::set<std::string> vals;
  auto view = value_view(c_map);
  std::copy(view.begin(), view.end(), inserter(vals, vals.end()));

  EXPECT_THAT(vals, ElementsAre("a", "b", "c"));
}

TEST_F(IteratorAdaptorTest, ValueView_Modify) {
  typedef std::map<int, int> MapType;
  MapType my_map;
  my_map[0] = 0;
  my_map[1] = 1;
  my_map[2] = 2;
  EXPECT_THAT(my_map, ElementsAre(Pair(0, 0), Pair(1, 1), Pair(2, 2)));

  value_view_type<MapType>::type vv = value_view(my_map);
  std::replace(vv.begin(), vv.end(), 2, 3);
  std::replace(vv.begin(), vv.end(), 1, 2);

  EXPECT_THAT(my_map, ElementsAre(Pair(0, 0), Pair(1, 2), Pair(2, 3)));
}

TEST_F(IteratorAdaptorTest, ValueViewOfValueView) {
  typedef std::pair<int, std::string> pair_int_str;
  typedef std::map<int, pair_int_str> map_int_pair_int_str;
  map_int_pair_int_str my_map;
  my_map[0] = std::make_pair(1, std::string("a"));
  my_map[2] = std::make_pair(3, std::string("b"));
  my_map[4] = std::make_pair(5, std::string("c"));

  // This is basically typechecking of the generated views. So we generate the
  // types and have the compiler verify the generated template instantiation.
  typedef value_view_type<map_int_pair_int_str>::type
      value_view_map_int_pair_int_str_type;

  static_assert(
      (std::is_same<pair_int_str,
                    value_view_map_int_pair_int_str_type::value_type>::value),
      "value_view_value_type_");

  typedef value_view_type<value_view_map_int_pair_int_str_type>::type
      view_view_type;

  static_assert((std::is_same<std::string, view_view_type::value_type>::value),
                "view_view_type_");

  value_view_map_int_pair_int_str_type vv = value_view(my_map);
  view_view_type helper = value_view(vv);

  EXPECT_THAT(std::set<std::string>(helper.begin(), helper.end()),
              ElementsAre("a", "b", "c"));
}

TEST_F(IteratorAdaptorTest, ValueViewAndKeyViewCopy) {
  std::map<int, std::string> my_map;
  my_map[0] = "0";
  my_map[1] = "1";
  my_map[2] = "2";
  std::set<int> keys;
  std::set<std::string> vals;

  auto kv = key_view(my_map);
  std::copy(kv.begin(), kv.end(), inserter(keys, keys.end()));

  auto vv = value_view(my_map);
  std::copy(vv.begin(), vv.end(), inserter(vals, vals.end()));
  EXPECT_THAT(keys, ElementsAre(0, 1, 2));
  EXPECT_THAT(vals, ElementsAre("0", "1", "2"));
}

TEST_F(IteratorAdaptorTest, ValueViewAndKeyViewRangeBasedLoop) {
  std::map<int, std::string> my_map;
  my_map[0] = "0";
  my_map[1] = "1";
  my_map[2] = "2";
  std::set<int> keys;
  std::set<std::string> vals;
  for (auto key : key_view(my_map)) {
    keys.insert(key);
  }
  for (auto val : value_view(my_map)) {
    vals.insert(val);
  }
  EXPECT_THAT(keys, ElementsAre(0, 1, 2));
  EXPECT_THAT(vals, ElementsAre("0", "1", "2"));
}

template <int N, typename Value, typename Key>
class FixedSizeContainer {
 public:
  // NOTE: the container does on purpose not define:
  // reference, const_reference, pointer, const_pointer, size_type,
  // difference_type, empty().
  typedef std::pair<Value, Key> value_type;
  typedef value_type* iterator;
  typedef const value_type* const_iterator;

  FixedSizeContainer() {
  }
  const_iterator begin() const {
    return &values[0];
  }
  iterator begin() {
    return &values[0];
  }
  const_iterator end() const {
    return &values[N];
  }
  iterator end() {
    return &values[N];
  }
  value_type at(int n) const {
    return values[n];
  }
  value_type& operator[](int n) {
    return values[n];
  }
  int size() const {
    return N;
  }

 private:
  static constexpr int kAllocatedSize = N ? N : 1;
  value_type values[kAllocatedSize];
  // NOTE: the container does on purpose not define:
  // reference, const_reference, pointer, const_pointer, size_type,
  // difference_type, empty().
};

TEST_F(IteratorAdaptorTest, ProvidesEmpty) {
  {
    FixedSizeContainer<0, int, int> container0;
    EXPECT_TRUE(value_view(container0).empty());
    FixedSizeContainer<1, int, int> container1;
    EXPECT_FALSE(value_view(container1).empty());
  }
  {
    std::map<int, int> container;
    EXPECT_TRUE(value_view(container).empty());
    container.insert(std::make_pair(0, 0));
    EXPECT_FALSE(value_view(container).empty());
  }
}

TEST_F(IteratorAdaptorTest, ValueViewWithPoorlyTypedHomeGrownContainer) {
  FixedSizeContainer<3, int, std::string> container;
  container[0] = std::make_pair(0, std::string("0"));
  container[1] = std::make_pair(1, std::string("1"));
  container[2] = std::make_pair(2, std::string("2"));
  EXPECT_EQ(3, container.size());
  EXPECT_EQ(container.at(0), std::make_pair(0, std::string("0")));
  EXPECT_EQ(container.at(1), std::make_pair(1, std::string("1")));
  EXPECT_EQ(container.at(2), std::make_pair(2, std::string("2")));
  std::vector<int> keys;
  std::vector<std::string> vals;

  auto kv = key_view(container);
  std::copy(kv.begin(), kv.end(), back_inserter(keys));
  auto vv = value_view(container);
  std::copy(vv.begin(), vv.end(), back_inserter(vals));
  EXPECT_THAT(keys, ElementsAre(0, 1, 2));
  EXPECT_THAT(vals, ElementsAre("0", "1", "2"));
}

TEST_F(IteratorAdaptorTest, ValueViewConstIterators) {
  unordered_map<int, std::string> my_map;
  my_map[0] = "a";
  my_map[1] = "b";
  my_map[2] = "c";

  std::set<std::string> vals;
  // iterator_view_helper defines cbegin() and cend(); we're not invoking the
  // C++11 functions of the same name.
  for (iterator_second<unordered_map<int, std::string>::const_iterator> it =
           value_view(my_map).cbegin();
       it != value_view(my_map).cend(); ++it) {
    vals.insert(*it);
  }

  EXPECT_TRUE(vals.find("a") != vals.end());
  EXPECT_TRUE(vals.find("b") != vals.end());
  EXPECT_TRUE(vals.find("c") != vals.end());
}

TEST_F(IteratorAdaptorTest, ValueViewInConstContext) {
  using firebase::firestore::util::internal::iterator_view_helper;
  unordered_map<int, std::string> my_map;
  my_map[0] = "a";
  my_map[1] = "b";
  my_map[2] = "c";

  std::set<std::string> vals;
  const iterator_view_helper<
      unordered_map<int, std::string>,
      iterator_second<unordered_map<int, std::string>::iterator>,
      iterator_second<unordered_map<int, std::string>::const_iterator>>
      const_view = value_view(my_map);
  for (iterator_second<unordered_map<int, std::string>::const_iterator> it =
           const_view.begin();
       it != const_view.end(); ++it) {
    vals.insert(*it);
  }

  EXPECT_TRUE(vals.find("a") != vals.end());
  EXPECT_TRUE(vals.find("b") != vals.end());
  EXPECT_TRUE(vals.find("c") != vals.end());
}

TEST_F(IteratorAdaptorTest, ConstValueView) {
  unordered_map<int, std::string> my_map;
  my_map[0] = "a";
  my_map[1] = "b";
  my_map[2] = "c";

  const unordered_map<int, std::string>& const_map = my_map;

  std::set<std::string> vals;
  for (iterator_second<unordered_map<int, std::string>::const_iterator> it =
           value_view(const_map).begin();
       it != value_view(const_map).end(); ++it) {
    vals.insert(*it);
  }

  EXPECT_TRUE(vals.find("a") != vals.end());
  EXPECT_TRUE(vals.find("b") != vals.end());
  EXPECT_TRUE(vals.find("c") != vals.end());
}

TEST_F(IteratorAdaptorTest, ConstValueViewConstIterators) {
  unordered_map<int, std::string> my_map;
  my_map[0] = "a";
  my_map[1] = "b";
  my_map[2] = "c";

  const unordered_map<int, std::string>& const_map = my_map;

  std::set<std::string> vals;
  // iterator_view_helper defines cbegin() and cend(); we're not invoking the
  // C++11 functions of the same name.
  for (iterator_second<unordered_map<int, std::string>::const_iterator> it =
           value_view(const_map).cbegin();
       it != value_view(const_map).cend(); ++it) {
    vals.insert(*it);
  }

  EXPECT_TRUE(vals.find("a") != vals.end());
  EXPECT_TRUE(vals.find("b") != vals.end());
  EXPECT_TRUE(vals.find("c") != vals.end());
}

TEST_F(IteratorAdaptorTest, ConstValueViewInConstContext) {
  unordered_map<int, std::string> my_map;
  my_map[0] = "a";
  my_map[1] = "b";
  my_map[2] = "c";

  const unordered_map<int, std::string>& const_map = my_map;

  std::set<std::string> vals;
  const value_view_type<const unordered_map<int, std::string>>::type
      const_view = value_view(const_map);
  for (iterator_second<unordered_map<int, std::string>::const_iterator> it =
           const_view.begin();
       it != const_view.end(); ++it) {
    vals.insert(*it);
  }

  EXPECT_TRUE(vals.find("a") != vals.end());
  EXPECT_TRUE(vals.find("b") != vals.end());
  EXPECT_TRUE(vals.find("c") != vals.end());
}

TEST_F(IteratorAdaptorTest, KeyView) {
  unordered_map<int, std::string> my_map;
  my_map[0] = "a";
  my_map[1] = "b";
  my_map[2] = "c";

  std::set<int> vals;
  for (iterator_first<unordered_map<int, std::string>::iterator> it =
           key_view(my_map).begin();
       it != key_view(my_map).end(); ++it) {
    vals.insert(*it);
  }

  EXPECT_TRUE(vals.find(0) != vals.end());
  EXPECT_TRUE(vals.find(1) != vals.end());
  EXPECT_TRUE(vals.find(2) != vals.end());
}

TEST_F(IteratorAdaptorTest, KeyViewConstIterators) {
  unordered_map<int, std::string> my_map;
  my_map[0] = "a";
  my_map[1] = "b";
  my_map[2] = "c";

  std::set<int> vals;
  // iterator_view_helper defines cbegin() and cend(); we're not invoking the
  // C++11 functions of the same name.
  for (iterator_first<unordered_map<int, std::string>::const_iterator> it =
           key_view(my_map).cbegin();
       it != key_view(my_map).cend(); ++it) {
    vals.insert(*it);
  }

  EXPECT_TRUE(vals.find(0) != vals.end());
  EXPECT_TRUE(vals.find(1) != vals.end());
  EXPECT_TRUE(vals.find(2) != vals.end());
}

TEST_F(IteratorAdaptorTest, KeyViewInConstContext) {
  unordered_map<int, std::string> my_map;
  my_map[0] = "a";
  my_map[1] = "b";
  my_map[2] = "c";

  std::set<int> vals;
  const key_view_type<unordered_map<int, std::string>>::type const_view =
      key_view(my_map);
  for (iterator_first<unordered_map<int, std::string>::const_iterator> it =
           const_view.begin();
       it != const_view.end(); ++it) {
    vals.insert(*it);
  }

  EXPECT_TRUE(vals.find(0) != vals.end());
  EXPECT_TRUE(vals.find(1) != vals.end());
  EXPECT_TRUE(vals.find(2) != vals.end());
}

TEST_F(IteratorAdaptorTest, ConstKeyView) {
  unordered_map<int, std::string> my_map;
  my_map[0] = "a";
  my_map[1] = "b";
  my_map[2] = "c";

  const unordered_map<int, std::string>& const_map = my_map;

  std::set<int> vals;
  for (iterator_first<unordered_map<int, std::string>::const_iterator> it =
           key_view(const_map).begin();
       it != key_view(const_map).end(); ++it) {
    vals.insert(*it);
  }

  EXPECT_TRUE(vals.find(0) != vals.end());
  EXPECT_TRUE(vals.find(1) != vals.end());
  EXPECT_TRUE(vals.find(2) != vals.end());
}

TEST_F(IteratorAdaptorTest, ConstKeyViewConstIterators) {
  unordered_map<int, std::string> my_map;
  my_map[0] = "a";
  my_map[1] = "b";
  my_map[2] = "c";

  const unordered_map<int, std::string>& const_map = my_map;

  std::set<int> vals;
  // iterator_view_helper defines cbegin() and cend(); we're not invoking the
  // C++11 functions of the same name.
  for (iterator_first<unordered_map<int, std::string>::const_iterator> it =
           key_view(const_map).cbegin();
       it != key_view(const_map).cend(); ++it) {
    vals.insert(*it);
  }

  EXPECT_TRUE(vals.find(0) != vals.end());
  EXPECT_TRUE(vals.find(1) != vals.end());
  EXPECT_TRUE(vals.find(2) != vals.end());
}

TEST_F(IteratorAdaptorTest, ConstKeyViewInConstContext) {
  unordered_map<int, std::string> my_map;
  my_map[0] = "a";
  my_map[1] = "b";
  my_map[2] = "c";

  const unordered_map<int, std::string>& const_map = my_map;

  std::set<int> vals;
  const key_view_type<const unordered_map<int, std::string>>::type const_view =
      key_view(const_map);
  for (iterator_first<unordered_map<int, std::string>::const_iterator> it =
           const_view.begin();
       it != const_view.end(); ++it) {
    vals.insert(*it);
  }

  EXPECT_TRUE(vals.find(0) != vals.end());
  EXPECT_TRUE(vals.find(1) != vals.end());
  EXPECT_TRUE(vals.find(2) != vals.end());
}

TEST_F(IteratorAdaptorTest, IteratorViewHelperDefinesIterator) {
  using firebase::firestore::util::internal::iterator_view_helper;
  unordered_set<int> my_set;
  my_set.insert(1);
  my_set.insert(0);
  my_set.insert(2);

  typedef iterator_view_helper<unordered_set<int>, unordered_set<int>::iterator,
                               unordered_set<int>::const_iterator>
      SetView;
  SetView set_view(my_set);
  unordered_set<int> vals;
  for (SetView::iterator it = set_view.begin(); it != set_view.end(); ++it) {
    vals.insert(*it);
  }

  EXPECT_TRUE(vals.find(0) != vals.end());
  EXPECT_TRUE(vals.find(1) != vals.end());
  EXPECT_TRUE(vals.find(2) != vals.end());
}

TEST_F(IteratorAdaptorTest, IteratorViewHelperDefinesConstIterator) {
  using firebase::firestore::util::internal::iterator_view_helper;
  unordered_set<int> my_set;
  my_set.insert(1);
  my_set.insert(0);
  my_set.insert(2);

  typedef iterator_view_helper<unordered_set<int>, unordered_set<int>::iterator,
                               unordered_set<int>::const_iterator>
      SetView;
  SetView set_view(my_set);
  unordered_set<int> vals;
  for (SetView::const_iterator it = set_view.begin(); it != set_view.end();
       ++it) {
    vals.insert(*it);
  }

  EXPECT_TRUE(vals.find(0) != vals.end());
  EXPECT_TRUE(vals.find(1) != vals.end());
  EXPECT_TRUE(vals.find(2) != vals.end());
}

TEST_F(IteratorAdaptorTest, ViewTypeParameterConstVsNonConst) {
  typedef unordered_map<int, int> M;
  M m;
  const M& cm = m;

  typedef key_view_type<M>::type KV;
  typedef key_view_type<const M>::type KVC;
  typedef value_view_type<M>::type VV;
  typedef value_view_type<const M>::type VVC;

  // key_view:
  KV ABSL_ATTRIBUTE_UNUSED kv1 = key_view(m);     // lvalue
  KVC ABSL_ATTRIBUTE_UNUSED kv2 = key_view(m);    // conversion to const
  KVC ABSL_ATTRIBUTE_UNUSED kv3 = key_view(cm);   // const from const lvalue
  KVC ABSL_ATTRIBUTE_UNUSED kv4 = key_view(M());  // const from rvalue
  // Direct initialization (without key_view function)
  KV ABSL_ATTRIBUTE_UNUSED kv5(m);
  KVC ABSL_ATTRIBUTE_UNUSED kv6(m);
  KVC ABSL_ATTRIBUTE_UNUSED kv7(cm);
  KVC ABSL_ATTRIBUTE_UNUSED kv8((M()));

  // value_view:
  VV ABSL_ATTRIBUTE_UNUSED vv1 = value_view(m);     // lvalue
  VVC ABSL_ATTRIBUTE_UNUSED vv2 = value_view(m);    // conversion to const
  VVC ABSL_ATTRIBUTE_UNUSED vv3 = value_view(cm);   // const from const lvalue
  VVC ABSL_ATTRIBUTE_UNUSED vv4 = value_view(M());  // const from rvalue
  // Direct initialization (without value_view function)
  VV ABSL_ATTRIBUTE_UNUSED vv5(m);
  VVC ABSL_ATTRIBUTE_UNUSED vv6(m);
  VVC ABSL_ATTRIBUTE_UNUSED vv7(cm);
  VVC ABSL_ATTRIBUTE_UNUSED vv8((M()));
}

TEST_F(IteratorAdaptorTest, EmptyAndSize) {
  {
    FixedSizeContainer<0, int, std::string*> container;
    EXPECT_TRUE(key_view(container).empty());
    EXPECT_TRUE(value_view(container).empty());
    EXPECT_EQ(0u, key_view(container).size());
    EXPECT_EQ(0u, value_view(container).size());
  }
  {
    FixedSizeContainer<2, int, std::string*> container;
    EXPECT_FALSE(key_view(container).empty());
    EXPECT_FALSE(value_view(container).empty());
    EXPECT_EQ(2u, key_view(container).size());
    EXPECT_EQ(2u, value_view(container).size());
  }
  {
    std::map<std::string, std::string*> container;
    EXPECT_TRUE(key_view(container).empty());
    EXPECT_TRUE(value_view(container).empty());
    EXPECT_EQ(0u, key_view(container).size());
    EXPECT_EQ(0u, value_view(container).size());
    std::string s0 = "s0";
    std::string s1 = "s1";
    container.insert(std::make_pair("0", &s0));
    container.insert(std::make_pair("1", &s0));
    EXPECT_FALSE(key_view(container).empty());
    EXPECT_FALSE(value_view(container).empty());
    EXPECT_EQ(2u, key_view(container).size());
    EXPECT_EQ(2u, value_view(container).size());
  }
}

TEST_F(IteratorAdaptorTest, View_IsEmpty) {
  EXPECT_THAT(key_view(std::map<int, int>()), IsEmpty());
  EXPECT_THAT(key_view(FixedSizeContainer<2, int, int>()), Not(IsEmpty()));
}

TEST_F(IteratorAdaptorTest, View_SizeIs) {
  EXPECT_THAT(key_view(std::map<int, int>()), SizeIs(0));
  EXPECT_THAT(key_view(FixedSizeContainer<2, int, int>()), SizeIs(2));
}

TEST_F(IteratorAdaptorTest, View_Pointwise) {
  typedef std::map<int, std::string> MapType;
  MapType my_map;
  my_map[0] = "a";
  my_map[1] = "b";
  my_map[2] = "c";

  std::vector<std::string> expected;
  expected.push_back("a");
  expected.push_back("b");
  expected.push_back("c");

  EXPECT_THAT(value_view(my_map), Pointwise(Eq(), expected));
}

TEST_F(IteratorAdaptorTest, DerefView) {
  typedef std::vector<int*> ContainerType;
  int v0 = 0;
  int v1 = 1;
  ContainerType c;
  c.push_back(&v0);
  c.push_back(&v1);
  EXPECT_THAT(deref_view(c), ElementsAre(0, 1));
  *deref_view(c).begin() = 2;
  EXPECT_THAT(v0, 2);
  EXPECT_THAT(deref_view(c), ElementsAre(2, 1));
  const std::vector<int*> cc(c);
  EXPECT_THAT(deref_view(cc), ElementsAre(2, 1));
}

TEST_F(IteratorAdaptorTest, ConstDerefView) {
  typedef std::vector<const std::string*> ContainerType;
  const std::string s0 = "0";
  const std::string s1 = "1";
  ContainerType c;
  c.push_back(&s0);
  c.push_back(&s1);
  EXPECT_THAT(deref_view(c), ElementsAre("0", "1"));
}

TEST_F(IteratorAdaptorTest, DerefSecondView) {
  typedef std::map<int, int*> ContainerType;
  int v0 = 0;
  int v1 = 1;
  ContainerType c;
  c.insert({10, &v0});
  c.insert({11, &v1});
  EXPECT_THAT(deref_second_view(c), ElementsAre(0, 1));
  *deref_second_view(c).begin() = 2;
  EXPECT_THAT(v0, 2);
  EXPECT_THAT(deref_second_view(c), ElementsAre(2, 1));
  const std::map<int, int*> cc(c);
  EXPECT_THAT(deref_second_view(cc), ElementsAre(2, 1));
}

TEST_F(IteratorAdaptorTest, ConstDerefSecondView) {
  typedef std::map<int, const std::string*> ContainerType;
  const std::string s0 = "0";
  const std::string s1 = "1";
  ContainerType c;
  c.insert({10, &s0});
  c.insert({11, &s1});
  EXPECT_THAT(deref_second_view(c), ElementsAre("0", "1"));
}

namespace {
template <class T>
std::vector<int> ToVec(const T& t) {
  return std::vector<int>(t.begin(), t.end());
}
}  // namespace

TEST_F(IteratorAdaptorTest, ReverseView) {
  using firebase::firestore::util::reversed_view;

  int arr[] = {0, 1, 2, 3, 4, 5, 6};
  int* arr_end = arr + sizeof(arr) / sizeof(arr[0]);
  std::vector<int> vec(arr, arr_end);
  const std::vector<int> cvec(arr, arr_end);

  EXPECT_THAT(ToVec(reversed_view(vec)), ElementsAre(6, 5, 4, 3, 2, 1, 0));
  EXPECT_THAT(ToVec(reversed_view(cvec)), ElementsAre(6, 5, 4, 3, 2, 1, 0));
}

TEST_F(IteratorAdaptorTest, IteratorPtrConstConversions) {
  // Users depend on this. It has to keep working.
  std::vector<int*> v;
  const std::vector<int*>& cv = v;
  EXPECT_TRUE(make_iterator_ptr(cv.end()) == make_iterator_ptr(v.end()));
  EXPECT_FALSE(make_iterator_ptr(cv.end()) != make_iterator_ptr(v.end()));
  // EXPECT_TRUE(make_iterator_ptr(v.end()) == make_iterator_ptr(cv.end()));
  // EXPECT_FALSE(make_iterator_ptr(v.end()) != make_iterator_ptr(cv.end()));
}

TEST_F(IteratorAdaptorTest, IteratorPtrDeepConst) {
  typedef std::vector<int*> PtrsToMutable;
  typedef iterator_ptr<PtrsToMutable::const_iterator> ConstIter;
  EXPECT_TRUE((std::is_same<ConstIter::reference, const int&>::value));
  EXPECT_TRUE(IsConst<ConstIter::reference>::value);

  typedef iterator_ptr<PtrsToMutable::iterator> Iter;
  EXPECT_TRUE((std::is_same<Iter::reference, int&>::value));
  EXPECT_FALSE(IsConst<Iter::reference>::value);
}

TEST_F(IteratorAdaptorTest, ReverseViewCxx11) {
  using firebase::firestore::util::reversed_view;

  int arr[] = {0, 1, 2, 3, 4, 5, 6};
  int* arr_end = arr + sizeof(arr) / sizeof(arr[0]);
  std::vector<int> vec(arr, arr_end);

  // Try updates and demonstrate this work with C++11 for loops.
  for (auto& i : reversed_view(vec)) ++i;
  EXPECT_THAT(vec, ElementsAre(1, 2, 3, 4, 5, 6, 7));
}

TEST_F(IteratorAdaptorTest, BaseIterDanglingRefFirst) {
  // Some iterators will hold 'on-board storage' for a synthesized value.
  // We must take care not to pull our adapted reference from
  // a temporary copy of the base iterator. See b/15113033.
  typedef std::pair<X, int> Val;
  InlineStorageIter<Val> iter;
  iterator_first<InlineStorageIter<Val>> iter2(iter);
  EXPECT_EQ(&iter2.base()->first, &*iter2);
  EXPECT_EQ(&iter2.base()->first.d, &iter2->d);
}

TEST_F(IteratorAdaptorTest, BaseIterDanglingRefSecond) {
  typedef std::pair<int, X> Val;
  InlineStorageIter<Val> iter;
  iterator_second<InlineStorageIter<Val>> iter2(iter);
  EXPECT_EQ(&iter2.base()->second, &*iter2);
  EXPECT_EQ(&iter2.base()->second.d, &iter2->d);
}

}  // namespace
