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

#include "Firestore/core/src/firebase/firestore/util/objc_compatibility.h"

#import <Foundation/NSArray.h>

#include <string>
#include <vector>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Source/Model/FSTDocument.h"

#include "Firestore/core/src/firebase/firestore/immutable/sorted_map.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {
namespace objc {

TEST(ObjCCompatibilityTest, Equals) {
  FSTDocument* doc1 = FSTTestDoc("a/b", 0, @{}, FSTDocumentStateSynced);
  FSTDocument* doc2 = FSTTestDoc("a/b", 0, @{}, FSTDocumentStateSynced);
  FSTDocument* doc3 = FSTTestDoc("b/c", 1, @{}, FSTDocumentStateSynced);

  EXPECT_TRUE(Equals(doc1, doc2));
  EXPECT_FALSE(Equals(doc1, doc3));
  EXPECT_FALSE(Equals(doc2, doc3));
}

TEST(ObjCCompatibilityTest, ContainerEquals) {
  FSTDocument* doc1 = FSTTestDoc("a/b", 0, @{}, FSTDocumentStateSynced);
  FSTDocument* doc2 = FSTTestDoc("b/c", 1, @{}, FSTDocumentStateSynced);
  FSTDocument* doc3 = FSTTestDoc("a/b", 0, @{}, FSTDocumentStateSynced);
  FSTDocument* doc4 = FSTTestDoc("b/c", 1, @{}, FSTDocumentStateSynced);

  std::vector<FSTDocument*> v1{doc1, doc2};
  std::vector<FSTDocument*> v2{doc3, doc4};
  std::vector<FSTDocument*> v3{doc1, doc3};
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

}  // namespace objc
}  // namespace util
}  // namespace firestore
}  // namespace firebase
