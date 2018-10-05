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

#include "Firestore/core/src/firebase/firestore/model/mutation.h"

#include <utility>

#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

using testutil::Doc;
using testutil::SetMutation;

TEST(Mutation, AppliesSetsToDocuments) {
  Document base_doc = Doc("collection/key", 0,
                          {{"foo", FieldValue::FromString("foo-value")},
                           {"baz", FieldValue::FromString("baz-value")}});

  std::unique_ptr<Mutation> set = SetMutation(
      "collection/key", {{"bar", FieldValue::FromString("bar-value")}});
  std::unique_ptr<MaybeDocument> set_doc =
      set->ApplyToLocalView(&base_doc, &base_doc, Timestamp::Now());
  ASSERT_TRUE(set_doc);
  EXPECT_EQ(
      Doc("collection/key", 0, {{"bar", FieldValue::FromString("bar-value")}},
          /*has_local_mutations=*/true),
      *set_doc.get());
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
