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

#include "Firestore/core/src/firebase/firestore/model/field_mask.h"

#include <vector>

#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

TEST(FieldMask, ConstructorAndEqual) {
  FieldMask mask_a{FieldPath::FromServerFormat("foo"),
                   FieldPath::FromServerFormat("bar")};
  std::vector<FieldPath> field_path_vector{FieldPath::FromServerFormat("foo"),
                                           FieldPath::FromServerFormat("bar")};
  FieldMask mask_b{field_path_vector};
  FieldMask mask_c{std::vector<FieldPath>{FieldPath::FromServerFormat("foo"),
                                          FieldPath::FromServerFormat("bar")}};
  EXPECT_EQ(mask_a, mask_b);
  EXPECT_EQ(mask_b, mask_c);
}

TEST(FieldMask, Getter) {
  FieldMask mask{FieldPath::FromServerFormat("foo"),
                 FieldPath::FromServerFormat("bar")};
  EXPECT_EQ(std::vector<FieldPath>({FieldPath::FromServerFormat("foo"),
                                    FieldPath::FromServerFormat("bar")}),
            std::vector<FieldPath>(mask.begin(), mask.end()));
}

TEST(FieldMask, ToString) {
  FieldMask mask{FieldPath::FromServerFormat("foo"),
                 FieldPath::FromServerFormat("bar")};
  EXPECT_EQ("{ foo bar }", mask.ToString());
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
