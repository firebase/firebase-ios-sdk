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

#include "Firestore/core/src/model/field_mask.h"

#include <set>

#include "Firestore/core/src/model/field_path.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

TEST(FieldMask, ConstructorAndEqual) {
  FieldMask mask_a{FieldPath::FromDotSeparatedString("foo"),
                   FieldPath::FromDotSeparatedString("bar")};
  std::set<FieldPath> field_path_set{FieldPath::FromDotSeparatedString("foo"),
                                     FieldPath::FromDotSeparatedString("bar")};
  FieldMask mask_b{field_path_set};
  FieldMask mask_c{
      std::set<FieldPath>{FieldPath::FromDotSeparatedString("foo"),
                          FieldPath::FromDotSeparatedString("bar")}};
  FieldMask mask_d{field_path_set.begin(), field_path_set.end()};

  EXPECT_EQ(mask_a, mask_b);
  EXPECT_EQ(mask_b, mask_c);
  EXPECT_EQ(mask_c, mask_d);
}

TEST(FieldMask, Getter) {
  FieldMask mask{FieldPath::FromDotSeparatedString("foo"),
                 FieldPath::FromDotSeparatedString("bar")};
  EXPECT_EQ(std::set<FieldPath>({FieldPath::FromDotSeparatedString("foo"),
                                 FieldPath::FromDotSeparatedString("bar")}),
            std::set<FieldPath>(mask.begin(), mask.end()));
}

TEST(FieldMask, ToString) {
  FieldMask mask{FieldPath::FromDotSeparatedString("foo"),
                 FieldPath::FromDotSeparatedString("bar")};
  EXPECT_EQ("{ bar foo }", mask.ToString());
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
