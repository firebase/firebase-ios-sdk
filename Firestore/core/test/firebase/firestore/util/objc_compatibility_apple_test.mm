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

#include "Firestore/core/src/firebase/firestore/objc/objc_compatibility.h"

#import <Foundation/Foundation.h>

#include <string>
#include <unordered_map>
#include <vector>

#include "gtest/gtest.h"

// Include this to validate that it does not cause ambiguity.
#include "Firestore/core/src/firebase/firestore/util/equality.h"

namespace firebase {
namespace firestore {
namespace objc {

NSString* MakeString(const char* contents) {
  return [[NSMutableString alloc] initWithCString:contents
                                         encoding:NSUTF8StringEncoding];
}

TEST(ObjCCompatibilityTest, Equals) {
  auto str_1a = MakeString("foo");
  auto str_1b = MakeString("foo");
  auto str_2 = MakeString("bar");

  // Ensure these are distinct instances.
  ASSERT_NE(str_1a, str_1b);

  EXPECT_TRUE(Equals(str_1a, str_1b));
  EXPECT_FALSE(Equals(str_1a, str_2));
  EXPECT_FALSE(Equals(str_1b, str_2));
}

TEST(ObjCCompatibilityTest, ContainerEquals) {
  auto str_1a = MakeString("foo");
  auto str_1b = MakeString("foo");
  auto str_2a = MakeString("bar");
  auto str_2b = MakeString("bar");

  NSArray<NSString*>* v1 = @[ str_1a, str_2a ];
  NSArray<NSString*>* v2 = @[ str_1b, str_2b ];
  NSArray<NSString*>* v3 = @[ str_1a, str_1b ];
  EXPECT_TRUE(Equals(v1, v2));
  EXPECT_FALSE(Equals(v1, v3));
  EXPECT_FALSE(Equals(v2, v3));
}

TEST(ObjCCompatibilityTest, NilEquals) {
  NSString* str_1;
  NSString* str_2;
  EXPECT_FALSE([str_1 isEqual:str_2]);
  EXPECT_TRUE(Equals(str_1, str_2));
}

TEST(ObjCCompatibilityTest, Description) {
  std::vector<std::string> v{"foo", "bar"};
  EXPECT_TRUE([Description(v) isEqual:@"[foo, bar]"]);
}

TEST(ObjCCompatibilityTest, EqualToAndHash) {
  EqualTo<NSString*> equals;
  Hash<NSString*> hash;

  NSMutableString* source = [NSMutableString stringWithUTF8String:"value"];
  NSString* value = [source copy];
  NSString* copy = [source copy];

  EXPECT_TRUE(equals(value, value));
  EXPECT_EQ(hash(value), hash(value));

  // Same type, different instance
  EXPECT_TRUE(equals(value, copy));
  EXPECT_EQ(hash(value), hash(copy));

  // Different type, same value
  EXPECT_TRUE(equals(source, value));
  EXPECT_EQ(hash(source), hash(value));

  NSString* other = @"other";
  EXPECT_FALSE(equals(value, other));
  EXPECT_FALSE(equals(value, nil));
  EXPECT_FALSE(equals(nil, value));
  EXPECT_FALSE(equals(nil, nil));
}

TEST(ObjCCompatibilityTest, UnorderedMap) {
  using MapType = std::unordered_map<NSString*, NSNumber*, Hash<NSString*>,
                                     EqualTo<NSString*>>;
  MapType map;

  auto inserted = map.insert({ @"foo", @1 });
  ASSERT_TRUE(inserted.second);

  inserted = map.insert({ @"bar", @2 });
  ASSERT_TRUE(inserted.second);
  ASSERT_EQ(map.size(), 2);

  auto foo_iter = map.find(@"foo");
  ASSERT_NE(foo_iter, map.end());
  ASSERT_EQ(foo_iter->first, @"foo");

  auto bar_iter = map.find(@"bar");
  ASSERT_NE(bar_iter, map.end());
  ASSERT_EQ(bar_iter->first, @"bar");

  auto result = map.insert({ @"foo", @3 });
  ASSERT_FALSE(result.second);                    // not inserted
  ASSERT_TRUE(Equals(result.first->second, @1));  // old value preserved

  map.erase(@"foo");
  ASSERT_EQ(map.size(), 1);
}

}  // namespace objc
}  // namespace firestore
}  // namespace firebase
