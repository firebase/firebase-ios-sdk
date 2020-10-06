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

#include "Firestore/core/src/util/hashing.h"

#import <Foundation/Foundation.h>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

TEST(HashingAppleTest, ObjectiveCHash) {
  NSString* foo = @"foobar";
  EXPECT_EQ(Hash(foo), static_cast<size_t>([foo hash]));

  NSArray<NSNumber*>* bar = @[ @1, @2, @3 ];
  EXPECT_EQ(Hash(bar), static_cast<size_t>([bar hash]));
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
