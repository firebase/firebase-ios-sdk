/*
 * Copyright 2021 Google LLC
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

#include "Firestore/core/src/model/object_value.h"

#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

const char kFooString[] = "foo";
const char kBarString[] = "bar";

namespace {

using absl::nullopt;
using testutil::DbId;
using testutil::Field;
using testutil::Map;
using testutil::Value;

class ObjectValueTest : public ::testing::Test {
 public:
  template <typename T>
  google_firestore_v1_Value Wrap(T input) {
    model::FieldValue fv = Value(input);
    return serializer.EncodeFieldValue(fv);
  }

  template <typename... Args>
  MutableObjectValue WrapObject(Args... key_value_pairs) {
    FieldValue fv = testutil::WrapObject((key_value_pairs)...);
    return MutableObjectValue{serializer.EncodeFieldValue(fv)};
  }

 private:
  remote::Serializer serializer{DbId()};
};

TEST_F(ObjectValueTest, ExtractsFields) {
  MutableObjectValue value =
      WrapObject("foo", Map("a", 1, "b", true, "c", "string"));

  ASSERT_EQ(google_firestore_v1_Value_map_value_tag,
            value.Get(Field("foo"))->which_value_type);

  EXPECT_TRUE(Wrap(1) == *value.Get(Field("foo.a")));
  EXPECT_TRUE(Wrap(true) == *value.Get(Field("foo.b")));
  EXPECT_TRUE(Wrap("string") == *value.Get(Field("foo.c")));

  EXPECT_TRUE(nullopt == value.Get(Field("foo.a.b")));
  EXPECT_TRUE(nullopt == value.Get(Field("bar")));
  EXPECT_TRUE(nullopt == value.Get(Field("bar.a")));
}

TEST_F(ObjectValueTest, ExtractsFieldMask) {
  MutableObjectValue value =
      WrapObject("a", "b", "Map",
                 Map("a", 1, "b", true, "c", "string", "nested", Map("d", "e")),
                 "emptymap", Map());

  FieldMask expected_mask =
      FieldMask({Field("a"), Field("Map.a"), Field("Map.b"), Field("Map.c"),
                 Field("Map.nested.d"), Field("emptymap")});
  FieldMask actual_mask = value.ToFieldMask();

  EXPECT_EQ(expected_mask, actual_mask);
}

TEST_F(ObjectValueTest, OverwritesExistingFields) {
  MutableObjectValue object_value = WrapObject("a", "object_value");
  EXPECT_EQ(WrapObject("a", "object_value"), object_value);
  object_value.Set(Field("a"), Wrap("object_value"));
  EXPECT_EQ(WrapObject("a", "object_value"), object_value);
}

TEST_F(ObjectValueTest, OverwritesNestedFields) {
  MutableObjectValue object_value =
      WrapObject("a", Map("b", kFooString, "c", Map("d", kFooString)));
  object_value.Set(Field("a.b"), Wrap(kBarString));
  object_value.Set(Field("a.c.d"), Wrap(kBarString));
  EXPECT_EQ(WrapObject("a", Map("b", kBarString, "c", Map("d", kBarString))),
            object_value);
}

TEST_F(ObjectValueTest, OverwritesDeeplyNestedField) {
  MutableObjectValue object_value = WrapObject("a", Map("b", kFooString));
  object_value.Set(Field("a.b.c"), Wrap(kBarString));
  EXPECT_EQ(WrapObject("a", Map("b", Map("c", kBarString))), object_value);
}

TEST_F(ObjectValueTest, OverwritesNestedObject) {
  MutableObjectValue object_value =
      WrapObject("a", Map("b", Map("c", kFooString, "d", kFooString)));
  object_value.Set(Field("a.b"), Wrap(kBarString));
  EXPECT_EQ(WrapObject("a", Map("b", "bar")), object_value);
}

TEST_F(ObjectValueTest, ReplacesNestedObject) {
  MutableObjectValue object_value = WrapObject("a", Map("b", kFooString));
  object_value.Set(Field("a"), Wrap(Map("c", kBarString)));
  EXPECT_EQ(WrapObject("a", Map("c", kBarString)), object_value);
}

    TEST_F(ObjectValueTest, ReplacesFieldWithNestedObject) {
        MutableObjectValue object_value = WrapObject("a", 1);
        object_value.Set(Field("a"), Wrap(Map("b", 2)));
        EXPECT_EQ(WrapObject("a", Map("b", 2)), object_value);
    }

TEST_F(ObjectValueTest, AddsNewFields) {
  MutableObjectValue object_value{};
  EXPECT_EQ(MutableObjectValue{}, object_value);

  object_value.Set(Field("a"), Wrap(1));
  EXPECT_EQ(WrapObject("a", 1), object_value);

  object_value.Set(Field("b"), Wrap(2));
  EXPECT_EQ(WrapObject("a", 1, "b", 2), object_value);
}

TEST_F(ObjectValueTest, AddsMultipleFields) {
  MutableObjectValue object_value{};
  EXPECT_EQ(MutableObjectValue{}, object_value);

  object_value.SetAll(FieldMask({Field("a"), Field("b"), Field("c.d"),
                                 Field("c.e"), Field("c.f")}),
                      WrapObject("a", 1, "b", 2, "c",
                                 Map("d", 3, "e", 4, "f", Map("g", 5),
                                     "ignored", 6)));
  EXPECT_EQ(WrapObject("a", 1, "b", 2, "c",
                       Map("d", 3, "e", 4, "f", Map("g", 5))),
            object_value);
}

TEST_F(ObjectValueTest, AddsNestedField) {
  MutableObjectValue object_value{};
  object_value.Set(Field("a.b"), Wrap(kFooString));
  object_value.Set(Field("c.d.e"), Wrap(kFooString));
  EXPECT_EQ(WrapObject("a", Map("b", kFooString), "c",
                       Map("d", Map("e", kFooString))),
            object_value);
}

TEST_F(ObjectValueTest, AddsFieldInNestedObject) {
  MutableObjectValue object_value{};
  object_value.Set(Field("a"), Wrap(Map("b", kFooString)));
  object_value.Set(Field("a.c"), Wrap(kFooString));
  EXPECT_EQ(WrapObject("a", Map("b", kFooString, "c", kFooString)),
            object_value);
}

TEST_F(ObjectValueTest, AddsTwoFieldsInNestedObject) {
  MutableObjectValue object_value{};
  object_value.Set(Field("a.b"), Wrap(kFooString));
  object_value.Set(Field("a.c"), Wrap(kFooString));
  EXPECT_EQ(WrapObject("a", Map("b", kFooString, "c", kFooString)),
            object_value);
}

TEST_F(ObjectValueTest, AddDeeplyNestedFieldInNestedObject) {
  MutableObjectValue object_value{};
  object_value.Set(Field("a.b.c.d.e.f"), Wrap(kFooString));
  EXPECT_EQ(
      WrapObject("a",
                 Map("b", Map("c", Map("d", Map("e", Map("f", kFooString)))))),
      object_value);
}

TEST_F(ObjectValueTest, AddsSingleFieldInExistingObject) {
  MutableObjectValue object_value = WrapObject("a", kFooString);
  object_value.Set(Field("b"), Wrap(kFooString));
  EXPECT_EQ(WrapObject("a", kFooString, "b", kFooString), object_value);
}

TEST_F(ObjectValueTest, SetsNestedFieldMultipleTimes) {
  MutableObjectValue object_value{};
  object_value.Set(Field("a.c"), Wrap(kFooString));
  object_value.Set(Field("a"), Wrap(Map("b", kFooString)));
  EXPECT_EQ(WrapObject("a", Map("b", kFooString)), object_value);
}

TEST_F(ObjectValueTest, ImplicitlyCreatesObjects) {
  MutableObjectValue object_value = WrapObject("a", "object_value");
  EXPECT_EQ(WrapObject("a", "object_value"), object_value);

  object_value.Set(Field("b.c.d"), Wrap("object_value"));
  EXPECT_EQ(
      WrapObject("a", "object_value", "b", Map("c", Map("d", "object_value"))),
      object_value);
}

TEST_F(ObjectValueTest, CanOverwritePrimitivesWithObjects) {
  MutableObjectValue object_value = WrapObject("a", Map("b", "object_value"));
  EXPECT_EQ(WrapObject("a", Map("b", "object_value")), object_value);

  object_value.Set(Field("a"), Wrap(Map("b", "object_value")));
  EXPECT_EQ(WrapObject("a", Map("b", "object_value")), object_value);
}

TEST_F(ObjectValueTest, AddsToNestedObjects) {
  MutableObjectValue object_value = WrapObject("a", Map("b", "object_value"));
  EXPECT_EQ(WrapObject("a", Map("b", "object_value")), object_value);

  object_value.Set(Field("a.c"), Wrap("object_value"));

  EXPECT_EQ(WrapObject("a", Map("b", "object_value", "c", "object_value")),
            object_value);
}

TEST_F(ObjectValueTest, DeletesKey) {
  MutableObjectValue object_value = WrapObject("a", 1, "b", 2);
  EXPECT_EQ(WrapObject("a", 1, "b", 2), object_value);

  object_value.Delete(Field("a"));

  EXPECT_EQ(WrapObject("b", 2), object_value);

  object_value.Delete(Field("b"));
  EXPECT_EQ(MutableObjectValue(), object_value);
}

TEST_F(ObjectValueTest, DeletesMultipleKeys) {
  MutableObjectValue object_value =
      WrapObject("a", 1, "b", 2, "c", Map("d", 3, "e", 4));

  object_value.SetAll(FieldMask({Field("a"), Field("b"), Field("c.d")}),
                      WrapObject());

  EXPECT_EQ(WrapObject("c", Map("e", 4)), object_value);
}

TEST_F(ObjectValueTest, DeletesHandleMissingKeys) {
  MutableObjectValue object_value = WrapObject("a", Map("b", 1, "c", 2));
  EXPECT_EQ(WrapObject("a", Map("b", 1, "c", 2)), object_value);

  object_value.Delete(Field("b"));
  object_value.Delete(Field("a.d"));
  EXPECT_EQ(WrapObject("a", Map("b", 1, "c", 2)), object_value);

  object_value.Delete(Field("a.b.c"));
  EXPECT_EQ(WrapObject("a", Map("b", 1, "c", 2)), object_value);
}

TEST_F(ObjectValueTest, DeletesNestedKeys) {
  FieldValue::Map orig = Map("a", Map("b", 1, "c", Map("d", 2, "e", 3)));
  MutableObjectValue object_value = WrapObject(orig);
  object_value.Delete(Field("a.c.d"));

  FieldValue::Map second = Map("a", Map("b", 1, "c", Map("e", 3)));
  EXPECT_EQ(WrapObject(second), object_value);

  object_value.Delete(Field("a.c"));

  FieldValue::Map third = Map("a", Map("b", 1));
  EXPECT_EQ(WrapObject(third), object_value);

  object_value.Delete(Field("a"));

  EXPECT_EQ(MutableObjectValue(), object_value);
}

TEST_F(ObjectValueTest, DeletesNestedObject) {
  MutableObjectValue object_value = WrapObject(
      "a", Map("b", Map("c", kFooString, "d", kFooString), "f", kFooString));
  object_value.Delete(Field("a.b"));
  EXPECT_EQ(WrapObject("a", Map("f", kFooString)), object_value);
}

TEST_F(ObjectValueTest, AddsAndDeletesField) {
  MutableObjectValue object_value{};
  object_value.Set(Field(kFooString), Wrap(kFooString));
  object_value.Delete(Field(kFooString));
  EXPECT_EQ(WrapObject(), object_value);
}

TEST_F(ObjectValueTest, AddsAndDeletesMultipleFields) {
  MutableObjectValue object_value = WrapObject("b", 2, "c", 3);
  object_value.SetAll(FieldMask({Field("a"), Field("b")}), WrapObject("a", 1));
  EXPECT_EQ(WrapObject("a", 1, "c", 3), object_value);
}

TEST_F(ObjectValueTest, AddsAndDeletesNestedField) {
  MutableObjectValue object_value{};
  object_value.Set(Field("a.b.c"), Wrap(kFooString));
  object_value.Set(Field("a.b.d"), Wrap(kFooString));
  object_value.Set(Field("f.g"), Wrap(kFooString));
  object_value.Set(Field("h"), Wrap(kFooString));
  object_value.Delete(Field("a.b.c"));
  object_value.Delete(Field("h"));
  EXPECT_EQ(WrapObject("a", Map("b", Map("d", kFooString)), "f",
                       Map("g", kFooString)),
            object_value);
}

TEST_F(ObjectValueTest, MergesExistingObject) {
  MutableObjectValue object_value = WrapObject("a", Map("b", kFooString));
  object_value.Set(Field("a.c"), Wrap(kFooString));
  EXPECT_EQ(WrapObject("a", Map("b", kFooString, "c", kFooString)),
            object_value);
}

}  // namespace

}  // namespace model
}  // namespace firestore
}  // namespace firebase
