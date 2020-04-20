/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/util/string_format.h"

#import <Foundation/NSString.h>

#include "gtest/gtest.h"

@interface FSTDescribable : NSObject
@end

@implementation FSTDescribable

- (NSString*)description {
  return @"description";
}

@end

namespace firebase {
namespace firestore {
namespace util {

TEST(StringFormatTest, NSString) {
  EXPECT_EQ("Hello World", StringFormat("Hello %s", @"World"));

  NSString* hello = [NSString stringWithUTF8String:"Hello"];
  EXPECT_EQ("Hello World", StringFormat("%s World", hello));

  // NOLINTNEXTLINE false positive on "string"
  NSMutableString* world = [NSMutableString string];
  [world appendString:@"World"];
  EXPECT_EQ("Hello World", StringFormat("Hello %s", world));
}

TEST(StringFormatTest, FSTDescribable) {
  FSTDescribable* desc = [[FSTDescribable alloc] init];
  EXPECT_EQ("Hello description", StringFormat("Hello %s", desc));

  id desc_id = desc;
  EXPECT_EQ("Hello description", StringFormat("Hello %s", desc_id));
}

}  //  namespace util
}  //  namespace firestore
}  //  namespace firebase
