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

#import <Foundation/NSArray.h>

#include <string>
#include <unordered_map>
#include <vector>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Source/Model/FSTDocument.h"

#include "Firestore/core/src/firebase/firestore/immutable/sorted_map.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace objc {

using model::DocumentState;

TEST(ObjCCompatibilityTest, Equals) {
  FSTDocument* doc1a = FSTTestDoc("a/b", 0, @{}, DocumentState::kSynced);
  FSTDocument* doc1b = FSTTestDoc("a/b", 0, @{}, DocumentState::kSynced);
  FSTDocument* doc2 = FSTTestDoc("b/c", 1, @{}, DocumentState::kSynced);

  EXPECT_TRUE(Equals(doc1a, doc1b));
  EXPECT_FALSE(Equals(doc1a, doc2));
  EXPECT_FALSE(Equals(doc1b, doc2));
}

TEST(ObjCCompatibilityTest, ContainerEquals) {
  FSTDocument* doc1a = FSTTestDoc("a/b", 0, @{}, DocumentState::kSynced);
  FSTDocument* doc2a = FSTTestDoc("b/c", 1, @{}, DocumentState::kSynced);
  FSTDocument* doc1b = FSTTestDoc("a/b", 0, @{}, DocumentState::kSynced);
  FSTDocument* doc2b = FSTTestDoc("b/c", 1, @{}, DocumentState::kSynced);

  std::vector<FSTDocument*> v1{doc1a, doc2a};
  std::vector<FSTDocument*> v2{doc1b, doc2b};
  std::vector<FSTDocument*> v3{doc1a, doc1b};
  EXPECT_TRUE(Equals(v1, v2));
  EXPECT_FALSE(Equals(v1, v3));
  EXPECT_FALSE(Equals(v2, v3));
}

TEST(ObjCCompatibilityTest, NilEquals) {
  FSTDocument* doc1 = nil;
  FSTDocument* doc2 = nil;
  EXPECT_FALSE([doc1 isEqual:doc2]);
  EXPECT_TRUE(Equals(doc1, doc2));
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
