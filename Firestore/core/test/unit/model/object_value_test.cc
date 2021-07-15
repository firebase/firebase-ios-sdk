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
using testutil::WrapObject;

class ObjectValueTest : public ::testing::Test {
 private:
  remote::Serializer serializer{DbId()};
};

TEST_F(ObjectValueTest, ExtractsFields) {
  ObjectValue value = WrapObject("foo", Map("a", 1, "b", true, "c", "string"));

  ASSERT_EQ(google_firestore_v1_Value_map_value_tag,
            value.Get(Field("foo"))->which_value_type);

  EXPECT_EQ(*Value(1), *value.Get(Field("foo.a")));
  EXPECT_EQ(*Value(true), *value.Get(Field("foo.b")));
  EXPECT_EQ(*Value("string"), *value.Get(Field("foo.c")));

  EXPECT_EQ(nullopt, value.Get(Field("foo.a.b")));
  EXPECT_EQ(nullopt, value.Get(Field("bar")));
  EXPECT_EQ(nullopt, value.Get(Field("bar.a")));
}

TEST_F(ObjectValueTest, ExtractsFieldMask) {
  ObjectValue value =
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
  ObjectValue object_value = WrapObject("a", "object_value");
  EXPECT_EQ(WrapObject("a", "object_value"), object_value);
  object_value.Set(Field("a"), Value("object_value"));
  EXPECT_EQ(WrapObject("a", "object_value"), object_value);
}

TEST_F(ObjectValueTest, OverwritesNestedFields) {
  ObjectValue object_value =
      WrapObject("a", Map("b", kFooString, "c", Map("d", kFooString)));
  object_value.Set(Field("a.b"), Value(kBarString));
  object_value.Set(Field("a.c.d"), Value(kBarString));
  EXPECT_EQ(WrapObject("a", Map("b", kBarString, "c", Map("d", kBarString))),
            object_value);
}

TEST_F(ObjectValueTest, OverwritesDeeplyNestedField) {
  ObjectValue object_value = WrapObject("a", Map("b", kFooString));
  object_value.Set(Field("a.b.c"), Value(kBarString));
  EXPECT_EQ(WrapObject("a", Map("b", Map("c", kBarString))), object_value);
}

TEST_F(ObjectValueTest, OverwritesNestedObject) {
  ObjectValue object_value =
      WrapObject("a", Map("b", Map("c", kFooString, "d", kFooString)));
  object_value.Set(Field("a.b"), Value(kBarString));
  EXPECT_EQ(WrapObject("a", Map("b", "bar")), object_value);
}

TEST_F(ObjectValueTest, ReplacesNestedObject) {
  ObjectValue object_value = WrapObject("a", Map("b", kFooString));
  object_value.Set(Field("a"), Value(Map("c", kBarString)));
  EXPECT_EQ(WrapObject("a", Map("c", kBarString)), object_value);
}

TEST_F(ObjectValueTest, ReplacesFieldWithNestedObject) {
  ObjectValue object_value = WrapObject("a", 1);
  object_value.Set(Field("a"), Value(Map("b", 2)));
  EXPECT_EQ(WrapObject("a", Map("b", 2)), object_value);
}

TEST_F(ObjectValueTest, AddsNewFields) {
  ObjectValue object_value{};
  EXPECT_EQ(ObjectValue{}, object_value);

  object_value.Set(Field("a"), Value(1));
  EXPECT_EQ(WrapObject("a", 1), object_value);

  object_value.Set(Field("b"), Value(2));
  EXPECT_EQ(WrapObject("a", 1, "b", 2), object_value);
}

TEST_F(ObjectValueTest, AddsMultipleFields) {
  ObjectValue object_value{};
  EXPECT_EQ(ObjectValue{}, object_value);

  TransformMap data;
  data[Field("a")] = Value(1);
  data[Field("b")] = Value(2);
  data[Field("c.d")] = Value(3);
  data[Field("c.e")] = Value(4);
  data[Field("c.f.g")] = Value(5);
  object_value.SetAll(std::move(data));
  EXPECT_EQ(
      WrapObject("a", 1, "b", 2, "c", Map("d", 3, "e", 4, "f", Map("g", 5))),
      object_value);
}

TEST_F(ObjectValueTest, AddsNestedField) {
  ObjectValue object_value{};
  object_value.Set(Field("a.b"), Value(kFooString));
  object_value.Set(Field("c.d.e"), Value(kFooString));
  EXPECT_EQ(WrapObject("a", Map("b", kFooString), "c",
                       Map("d", Map("e", kFooString))),
            object_value);
}

TEST_F(ObjectValueTest, AddsFieldInNestedObject) {
  ObjectValue object_value{};
  object_value.Set(Field("a"), Value(Map("b", kFooString)));
  object_value.Set(Field("a.c"), Value(kFooString));
  EXPECT_EQ(WrapObject("a", Map("b", kFooString, "c", kFooString)),
            object_value);
}

TEST_F(ObjectValueTest, AddsTwoFieldsInNestedObject) {
  ObjectValue object_value{};
  object_value.Set(Field("a.b"), Value(kFooString));
  object_value.Set(Field("a.c"), Value(kFooString));
  EXPECT_EQ(WrapObject("a", Map("b", kFooString, "c", kFooString)),
            object_value);
}

TEST_F(ObjectValueTest, AddDeeplyNestedFieldInNestedObject) {
  ObjectValue object_value{};
  object_value.Set(Field("a.b.c.d.e.f"), Value(kFooString));
  EXPECT_EQ(
      WrapObject("a",
                 Map("b", Map("c", Map("d", Map("e", Map("f", kFooString)))))),
      object_value);

  object_value.Set(Field("a.a.b"), Value(kFooString));
  EXPECT_EQ(
      WrapObject("a", Map("a", Map("b", kFooString), "b",
                          Map("c", Map("d", Map("e", Map("f", kFooString)))))),
      object_value);

  object_value.Set(Field("a.c.d"), Value(kFooString));
  EXPECT_EQ(
      WrapObject("a", Map("a", Map("b", kFooString), "b",
                          Map("c", Map("d", Map("e", Map("f", kFooString)))),
                          "c", Map("d", kFooString))),
      object_value);
}

TEST_F(ObjectValueTest, AddsSingleFieldInExistingObject) {
  ObjectValue object_value = WrapObject("a", kFooString);
  object_value.Set(Field("b"), Value(kFooString));
  EXPECT_EQ(WrapObject("a", kFooString, "b", kFooString), object_value);
}

TEST_F(ObjectValueTest, SetsNestedFieldMultipleTimes) {
  ObjectValue object_value{};
  object_value.Set(Field("a.c"), Value(kFooString));
  object_value.Set(Field("a"), Value(Map("b", kFooString)));
  EXPECT_EQ(WrapObject("a", Map("b", kFooString)), object_value);
}

TEST_F(ObjectValueTest, ImplicitlyCreatesObjects) {
  ObjectValue object_value = WrapObject("a", "object_value");
  EXPECT_EQ(WrapObject("a", "object_value"), object_value);

  object_value.Set(Field("b.c.d"), Value("object_value"));
  EXPECT_EQ(
      WrapObject("a", "object_value", "b", Map("c", Map("d", "object_value"))),
      object_value);
}

TEST_F(ObjectValueTest, CanOverwritePrimitivesWithObjects) {
  ObjectValue object_value = WrapObject("a", Map("b", "object_value"));
  EXPECT_EQ(WrapObject("a", Map("b", "object_value")), object_value);

  object_value.Set(Field("a"), Value(Map("b", "object_value")));
  EXPECT_EQ(WrapObject("a", Map("b", "object_value")), object_value);
}

TEST_F(ObjectValueTest, AddsToNestedObjects) {
  ObjectValue object_value = WrapObject("a", Map("b", "object_value"));
  EXPECT_EQ(WrapObject("a", Map("b", "object_value")), object_value);

  object_value.Set(Field("a.c"), Value("object_value"));

  EXPECT_EQ(WrapObject("a", Map("b", "object_value", "c", "object_value")),
            object_value);
}

TEST_F(ObjectValueTest, DeletesKey) {
  ObjectValue object_value = WrapObject("a", 1, "b", 2);
  EXPECT_EQ(WrapObject("a", 1, "b", 2), object_value);

  object_value.Delete(Field("a"));

  EXPECT_EQ(WrapObject("b", 2), object_value);

  object_value.Delete(Field("b"));
  EXPECT_EQ(ObjectValue(), object_value);
}

TEST_F(ObjectValueTest, DeletesMultipleKeys) {
  ObjectValue object_value =
      WrapObject("a", 1, "b", 2, "c", Map("d", 3, "e", 4));

  TransformMap data;
  data[Field("a")] = absl::nullopt;
  data[Field("b")] = absl::nullopt;
  data[Field("c.d")] = absl::nullopt;
  object_value.SetAll(std::move(data));

  EXPECT_EQ(WrapObject("c", Map("e", 4)), object_value);
}

TEST_F(ObjectValueTest, DeletesHandleMissingKeys) {
  ObjectValue object_value = WrapObject("a", Map("b", 1, "c", 2));
  EXPECT_EQ(WrapObject("a", Map("b", 1, "c", 2)), object_value);

  object_value.Delete(Field("b"));
  object_value.Delete(Field("a.d"));
  EXPECT_EQ(WrapObject("a", Map("b", 1, "c", 2)), object_value);

  object_value.Delete(Field("a.b.c"));
  EXPECT_EQ(WrapObject("a", Map("b", 1, "c", 2)), object_value);
}

TEST_F(ObjectValueTest, DeletesNestedKeys) {
  auto orig = Map("a", Map("b", 1, "c", Map("d", 2, "e", 3)));
  ObjectValue object_value = WrapObject(std::move(orig));
  object_value.Delete(Field("a.c.d"));
  EXPECT_EQ(WrapObject(Map("a", Map("b", 1, "c", Map("e", 3)))), object_value);

  object_value.Delete(Field("a.c"));
  EXPECT_EQ(WrapObject(Map("a", Map("b", 1))), object_value);

  object_value.Delete(Field("a"));
  EXPECT_EQ(ObjectValue(), object_value);
}

TEST_F(ObjectValueTest, DeletesNestedObject) {
  ObjectValue object_value = WrapObject(
      "a", Map("b", Map("c", kFooString, "d", kFooString), "f", kFooString));
  object_value.Delete(Field("a.b"));
  EXPECT_EQ(WrapObject("a", Map("f", kFooString)), object_value);
  object_value.Delete(Field("a.f"));
  EXPECT_EQ(WrapObject("a", Map()), object_value);
}

TEST_F(ObjectValueTest, AddsAndDeletesField) {
  ObjectValue object_value{};
  object_value.Set(Field(kFooString), Value(kFooString));
  object_value.Delete(Field(kFooString));
  EXPECT_EQ(WrapObject(), object_value);
}

TEST_F(ObjectValueTest, AddsAndDeletesMultipleFields) {
  ObjectValue object_value = WrapObject("b", 2, "c", 3);
  TransformMap data;
  data[Field("a")] = Value(1);
  data[Field("b")] = absl::nullopt;
  object_value.SetAll(std::move(data));
  EXPECT_EQ(WrapObject("a", 1, "c", 3), object_value);
}

TEST_F(ObjectValueTest, AddsAndDeletesNestedField) {
  ObjectValue object_value{};
  object_value.Set(Field("a.b.c"), Value(kFooString));
  object_value.Set(Field("a.b.d"), Value(kFooString));
  object_value.Set(Field("f.g"), Value(kFooString));
  object_value.Set(Field("h"), Value(kFooString));
  object_value.Delete(Field("a.b.c"));
  object_value.Delete(Field("h"));
  EXPECT_EQ(WrapObject("a", Map("b", Map("d", kFooString)), "f",
                       Map("g", kFooString)),
            object_value);
}

TEST_F(ObjectValueTest, MergesExistingObject) {
  ObjectValue object_value = WrapObject("a", Map("b", kFooString));
  object_value.Set(Field("a.c"), Value(kFooString));
  EXPECT_EQ(WrapObject("a", Map("b", kFooString, "c", kFooString)),
            object_value);
}

TEST_F(ObjectValueTest, DoesNotRequireSortedValues) {
  ObjectValue object_value = WrapObject("c", 2, "a", 1);
  EXPECT_EQ(*Value(2), *object_value.Get(Field("c")));
}

TEST_F(ObjectValueTest, DoesNotRequireSortedInserts) {
  ObjectValue object_value{};
  object_value.Set(Field("nested"),
                   Map("c", 2, "nested", Map("c", 2, "a", 1), "a", 1));
  EXPECT_EQ(*Value(2), *object_value.Get(Field("nested.c")));
  EXPECT_EQ(*Value(2), *object_value.Get(Field("nested.nested.c")));
}

}  // namespace

}  // namespace model
}  // namespace firestore
}  // namespace firebase
