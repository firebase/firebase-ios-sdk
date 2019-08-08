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

#import <FirebaseFirestore/FIRGeoPoint.h>
#import <Foundation/NSArray.h>

#include <string>
#include <unordered_map>
#include <vector>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/immutable/sorted_map.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "gtest/gtest.h"

// Include this to validate that it does not cause ambiguity.
#include "Firestore/core/src/firebase/firestore/util/equality.h"

namespace firebase {
namespace firestore {
namespace objc {

using model::Document;
using model::DocumentState;

using testutil::Doc;
using testutil::Map;

TEST(ObjCCompatibilityTest, Equals) {
  auto point_1a = [[FIRGeoPoint alloc] initWithLatitude:25 longitude:50];
  auto point_1b = [[FIRGeoPoint alloc] initWithLatitude:25 longitude:50];
  auto point_2 = [[FIRGeoPoint alloc] initWithLatitude:25 longitude:40];

  EXPECT_TRUE(Equals(point_1a, point_1b));
  EXPECT_FALSE(Equals(point_1a, point_2));
  EXPECT_FALSE(Equals(point_1b, point_2));
}

TEST(ObjCCompatibilityTest, ContainerEquals) {
  auto point_1a = [[FIRGeoPoint alloc] initWithLatitude:25 longitude:50];
  auto point_1b = [[FIRGeoPoint alloc] initWithLatitude:25 longitude:50];
  auto point_2a = [[FIRGeoPoint alloc] initWithLatitude:40 longitude:20];
  auto point_2b = [[FIRGeoPoint alloc] initWithLatitude:40 longitude:20];

  NSArray<FIRGeoPoint*>* v1 = @[ point_1a, point_2a ];
  NSArray<FIRGeoPoint*>* v2 = @[ point_1b, point_2b ];
  NSArray<FIRGeoPoint*>* v3 = @[ point_1a, point_1b ];
  EXPECT_TRUE(Equals(v1, v2));
  EXPECT_FALSE(Equals(v1, v3));
  EXPECT_FALSE(Equals(v2, v3));
}

TEST(ObjCCompatibilityTest, NilEquals) {
  FIRGeoPoint* point_1;
  FIRGeoPoint* point_2;
  EXPECT_FALSE([point_1 isEqual:point_2]);
  EXPECT_TRUE(Equals(point_1, point_2));
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
