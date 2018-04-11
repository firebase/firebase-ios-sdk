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

/* Most tests use libprotobuf to create the bytes used for testing the
 * serializer. (Previously, protoc was used, but that meant that the bytes were
 * generated ahead of time and just copy+paste'd into the test suite, leading to
 * a lot of magic.) Also note that bytes are no longer compared in any of the
 * tests. Instead, we ensure that encoding with our serializer and decoding with
 * libprotobuf (and vice versa) yield the same results.
 *
 * libprotobuf is only used in the test suite, and should never be present in
 * the production code.
 */

#include "Firestore/core/src/firebase/firestore/remote/serializer.h"

#include <pb.h>
#include <pb_encode.h>
#include <limits>
#include <vector>

#include "Firestore/Protos/cpp/google/firestore/v1beta1/document.pb.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "google/protobuf/stubs/common.h"
#include "google/protobuf/util/message_differencer.h"
#include "gtest/gtest.h"

using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::remote::Serializer;
using firebase::firestore::util::Status;
using google::protobuf::util::MessageDifferencer;

TEST(Serializer, CanLinkToNanopb) {
  // This test doesn't actually do anything interesting as far as actually using
  // nanopb is concerned but that it can run at all is proof that all the
  // libraries required for nanopb to work are actually linked correctly into
  // the test.
  pb_ostream_from_buffer(NULL, 0);
}

// Fixture for running serializer tests.
class SerializerTest : public ::testing::Test {
 public:
  SerializerTest() : serializer(/*DatabaseId("p", "d")*/) {
  }
  Serializer serializer;

  void ExpectRoundTrip(const FieldValue& model, FieldValue::Type type) {
    google::firestore::v1beta1::Value proto = ConvertModelToProto(model);

    // First, serialize model with our (nanopb based) serializer, then
    // deserialize the resulting bytes with libprotobuf and ensure the result is
    // the same as the expected proto.
    ExpectSerializationRoundTrip(model, proto, type);

    // Next, serialize proto with libprotobuf, then deserialize the resulting
    // bytes with our (nanopb based) deserializer and ensure the result is the
    // same as the expected model.
    ExpectDeserializationRoundTrip(model, proto, type);
  }

 private:
  google::firestore::v1beta1::Value ConvertModelToProto(
      const FieldValue& model) {
    google::firestore::v1beta1::Value proto;
    switch (model.type()) {
      case FieldValue::Type::Null:
        proto.set_null_value(google::protobuf::NullValue::NULL_VALUE);
        break;

      case FieldValue::Type::Boolean:
        proto.set_boolean_value(model.boolean_value());
        break;

      case FieldValue::Type::Integer:
        proto.set_integer_value(model.integer_value());
        break;

      case FieldValue::Type::String:
        proto.set_string_value(model.string_value());
        break;

      case FieldValue::Type::Object: {
        google::protobuf::Map<std::string, google::firestore::v1beta1::Value>*
            fields = proto.mutable_map_value()->mutable_fields();
        for (const ObjectValue::Map::value_type& kv :
             model.object_value().internal_value) {
          (*fields)[kv.first] = ConvertModelToProto(kv.second);
        }
        break;
      }

      case FieldValue::Type::Double:
      case FieldValue::Type::Timestamp:
      case FieldValue::Type::ServerTimestamp:
      case FieldValue::Type::Blob:
      case FieldValue::Type::Reference:
      case FieldValue::Type::GeoPoint:
      case FieldValue::Type::Array:
      default:
        // TODO(rsgowman): Implement this type
        abort();
    }
    return proto;
  }

  void ExpectSerializationRoundTrip(
      const FieldValue& model,
      const google::firestore::v1beta1::Value& proto,
      FieldValue::Type type) {
    EXPECT_EQ(type, model.type());
    std::vector<uint8_t> bytes;
    Status status = serializer.EncodeFieldValue(model, &bytes);
    EXPECT_TRUE(status.ok());
    google::firestore::v1beta1::Value actual_proto;
    bool ok = actual_proto.ParseFromArray(bytes.data(), bytes.size());
    EXPECT_TRUE(ok);
    EXPECT_TRUE(MessageDifferencer::Equals(proto, actual_proto));
  }

  void ExpectDeserializationRoundTrip(
      const FieldValue& model,
      const google::firestore::v1beta1::Value& proto,
      FieldValue::Type type) {
    size_t size = proto.ByteSizeLong();
    std::vector<uint8_t> bytes(size);
    bool status = proto.SerializeToArray(bytes.data(), size);
    EXPECT_TRUE(status);
    FieldValue actual_model = serializer.DecodeFieldValue(bytes);
    EXPECT_EQ(type, actual_model.type());
    EXPECT_EQ(model, actual_model);
  }
};

// TODO(rsgowman): whoops! A previous commit performed approx s/Encodes/Writes/,
// but should not have done so here. Change it back in this file.

TEST_F(SerializerTest, WritesNullModelToBytes) {
  FieldValue model = FieldValue::NullValue();
  ExpectRoundTrip(model, FieldValue::Type::Null);
}

TEST_F(SerializerTest, WritesBoolModelToBytes) {
  for (bool bool_value : {true, false}) {
    FieldValue model = FieldValue::BooleanValue(bool_value);
    ExpectRoundTrip(model, FieldValue::Type::Boolean);
  }
}

TEST_F(SerializerTest, WritesIntegersModelToBytes) {
  std::vector<int64_t> cases{0,
                             1,
                             -1,
                             100,
                             -100,
                             std::numeric_limits<int64_t>::min(),
                             std::numeric_limits<int64_t>::max()};

  for (int64_t int_value : cases) {
    FieldValue model = FieldValue::IntegerValue(int_value);
    ExpectRoundTrip(model, FieldValue::Type::Integer);
  }
}

TEST_F(SerializerTest, WritesStringModelToBytes) {
  std::vector<std::string> cases{
      "",
      "a",
      "abc def",
      "æ",
      // Note: Each one of the three embedded universal character names
      // (\u-escaped) maps to three chars, so the total length of the string
      // literal is 10 (ignoring the terminating null), and the resulting string
      // literal is the same as '\0\xed\x9f\xbf\xee\x80\x80\xef\xbf\xbf'". The
      // size of 10 must be added, or else std::string will see the \0 at the
      // start and assume that's the end of the string.
      {"\0\ud7ff\ue000\uffff", 10},
      {"\0\xed\x9f\xbf\xee\x80\x80\xef\xbf\xbf", 10},
      "(╯°□°）╯︵ ┻━┻"};

  for (const std::string& string_value : cases) {
    FieldValue model = FieldValue::StringValue(string_value);
    ExpectRoundTrip(model, FieldValue::Type::String);
  }
}

TEST_F(SerializerTest, WritesEmptyMapToBytes) {
  FieldValue model = FieldValue::ObjectValueFromMap({});
  ExpectRoundTrip(model, FieldValue::Type::Object);
}

TEST_F(SerializerTest, WritesNestedObjectsToBytes) {
  FieldValue model = FieldValue::ObjectValueFromMap(
      {{"b", FieldValue::TrueValue()},
       // TODO(rsgowman): add doubles (once they're supported)
       // {"d", FieldValue::DoubleValue(std::numeric_limits<double>::max())},
       {"i", FieldValue::IntegerValue(1)},
       {"n", FieldValue::NullValue()},
       {"s", FieldValue::StringValue("foo")},
       // TODO(rsgowman): add arrays (once they're supported)
       // {"a", [2, "bar", {"b", false}]},
       {"o", FieldValue::ObjectValueFromMap(
                 {{"d", FieldValue::IntegerValue(100)},
                  {"nested",
                   FieldValue::ObjectValueFromMap(
                       {{"e", FieldValue::IntegerValue(
                                  std::numeric_limits<int64_t>::max())}})}})}});

  ExpectRoundTrip(model, FieldValue::Type::Object);
}

// TODO(rsgowman): Test [en|de]coding multiple protos into the same output
// vector.

// TODO(rsgowman): Death test for decoding invalid bytes.
