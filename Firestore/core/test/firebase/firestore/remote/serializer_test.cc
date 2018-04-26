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
#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "google/protobuf/stubs/common.h"
#include "google/protobuf/util/message_differencer.h"
#include "gtest/gtest.h"

using firebase::firestore::FirestoreErrorCode;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::remote::Serializer;
using firebase::firestore::util::Status;
using firebase::firestore::util::StatusOr;
using google::protobuf::util::MessageDifferencer;

#define ASSERT_OK(status) ASSERT_TRUE(StatusOk(status))
#define ASSERT_NOT_OK(status) ASSERT_FALSE(StatusOk(status))
#define EXPECT_OK(status) EXPECT_TRUE(StatusOk(status))
#define EXPECT_NOT_OK(status) EXPECT_FALSE(StatusOk(status))

TEST(Serializer, CanLinkToNanopb) {
  // This test doesn't actually do anything interesting as far as actually using
  // nanopb is concerned but that it can run at all is proof that all the
  // libraries required for nanopb to work are actually linked correctly into
  // the test.
  pb_ostream_from_buffer(nullptr, 0);
}

// Fixture for running serializer tests.
class SerializerTest : public ::testing::Test {
 public:
  SerializerTest() : serializer(/*DatabaseId("p", "d")*/) {
  }
  Serializer serializer;

  void ExpectRoundTrip(const FieldValue& model,
                       const google::firestore::v1beta1::Value& proto,
                       FieldValue::Type type) {
    // First, serialize model with our (nanopb based) serializer, then
    // deserialize the resulting bytes with libprotobuf and ensure the result is
    // the same as the expected proto.
    ExpectSerializationRoundTrip(model, proto, type);

    // Next, serialize proto with libprotobuf, then deserialize the resulting
    // bytes with our (nanopb based) deserializer and ensure the result is the
    // same as the expected model.
    ExpectDeserializationRoundTrip(model, proto, type);
  }

  /**
   * Checks the status. Don't use directly; use one of the relevant macros
   * instead. eg:
   *
   *   Status good_status = ...;
   *   ASSERT_OK(good_status);
   *
   *   Status bad_status = ...;
   *   EXPECT_NOT_OK(bad_status);
   */
  testing::AssertionResult StatusOk(const Status& status) {
    if (!status.ok()) {
      return testing::AssertionFailure()
             << "Status should have been ok, but instead contained "
             << status.ToString();
    }
    return testing::AssertionSuccess();
  }

  template <typename T>
  testing::AssertionResult StatusOk(const StatusOr<T>& status) {
    return StatusOk(status.status());
  }

  /**
   * Ensures that decoding fails with the given status.
   *
   * @param status the expected (failed) status. Only the code() is verified.
   */
  void ExpectFailedStatusDuringDecode(Status status,
                                      const std::vector<uint8_t>& bytes) {
    StatusOr<FieldValue> bad_status = serializer.DecodeFieldValue(bytes);
    ASSERT_NOT_OK(bad_status);
    EXPECT_EQ(status.code(), bad_status.status().code());
  }

  google::firestore::v1beta1::Value ValueProto(nullptr_t) {
    std::vector<uint8_t> bytes;
    Status status =
        serializer.EncodeFieldValue(FieldValue::NullValue(), &bytes);
    EXPECT_OK(status);
    google::firestore::v1beta1::Value proto;
    bool ok = proto.ParseFromArray(bytes.data(), bytes.size());
    EXPECT_TRUE(ok);
    return proto;
  }

  std::vector<uint8_t> ExpectSuccessfullyEncodedFieldValue(
      Serializer& serializer, const FieldValue& fv) {
    std::vector<uint8_t> bytes;
    Status status = serializer.EncodeFieldValue(fv, &bytes);
    EXPECT_OK(status);
    return bytes;
  }

  void Mutate(uint8_t* byte,
              uint8_t expected_initial_value,
              uint8_t new_value) {
    ASSERT_EQ(*byte, expected_initial_value);
    *byte = new_value;
  }

  google::firestore::v1beta1::Value ValueProto(bool b) {
    std::vector<uint8_t> bytes;
    Status status =
        serializer.EncodeFieldValue(FieldValue::BooleanValue(b), &bytes);
    EXPECT_OK(status);
    google::firestore::v1beta1::Value proto;
    bool ok = proto.ParseFromArray(bytes.data(), bytes.size());
    EXPECT_TRUE(ok);
    return proto;
  }

  google::firestore::v1beta1::Value ValueProto(int64_t i) {
    std::vector<uint8_t> bytes;
    Status status =
        serializer.EncodeFieldValue(FieldValue::IntegerValue(i), &bytes);
    EXPECT_OK(status);
    google::firestore::v1beta1::Value proto;
    bool ok = proto.ParseFromArray(bytes.data(), bytes.size());
    EXPECT_TRUE(ok);
    return proto;
  }

  google::firestore::v1beta1::Value ValueProto(const char* s) {
    return ValueProto(std::string(s));
  }

  google::firestore::v1beta1::Value ValueProto(const std::string& s) {
    std::vector<uint8_t> bytes;
    Status status =
        serializer.EncodeFieldValue(FieldValue::StringValue(s), &bytes);
    EXPECT_OK(status);
    google::firestore::v1beta1::Value proto;
    bool ok = proto.ParseFromArray(bytes.data(), bytes.size());
    EXPECT_TRUE(ok);
    return proto;
  }

 private:
  void ExpectSerializationRoundTrip(
      const FieldValue& model,
      const google::firestore::v1beta1::Value& proto,
      FieldValue::Type type) {
    EXPECT_EQ(type, model.type());
    std::vector<uint8_t> bytes;
    Status status = serializer.EncodeFieldValue(model, &bytes);
    EXPECT_OK(status);
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
    StatusOr<FieldValue> actual_model_status =
        serializer.DecodeFieldValue(bytes);
    EXPECT_OK(actual_model_status);
    FieldValue actual_model = actual_model_status.ValueOrDie();
    EXPECT_EQ(type, actual_model.type());
    EXPECT_EQ(model, actual_model);
  }
};

// TODO(rsgowman): whoops! A previous commit performed approx s/Encodes/Writes/,
// but should not have done so here. Change it back in this file.

TEST_F(SerializerTest, WritesNull) {
  FieldValue model = FieldValue::NullValue();
  ExpectRoundTrip(model, ValueProto(nullptr), FieldValue::Type::Null);
}

TEST_F(SerializerTest, WritesBool) {
  for (bool bool_value : {true, false}) {
    FieldValue model = FieldValue::BooleanValue(bool_value);
    ExpectRoundTrip(model, ValueProto(bool_value), FieldValue::Type::Boolean);
  }
}

TEST_F(SerializerTest, WritesIntegers) {
  std::vector<int64_t> cases{0,
                             1,
                             -1,
                             100,
                             -100,
                             std::numeric_limits<int64_t>::min(),
                             std::numeric_limits<int64_t>::max()};

  for (int64_t int_value : cases) {
    FieldValue model = FieldValue::IntegerValue(int_value);
    ExpectRoundTrip(model, ValueProto(int_value), FieldValue::Type::Integer);
  }
}

TEST_F(SerializerTest, WritesString) {
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
      "(╯°□°）╯︵ ┻━┻",
  };

  for (const std::string& string_value : cases) {
    FieldValue model = FieldValue::StringValue(string_value);
    ExpectRoundTrip(model, ValueProto(string_value), FieldValue::Type::String);
  }
}

TEST_F(SerializerTest, WritesEmptyMap) {
  FieldValue model = FieldValue::ObjectValueFromMap({});

  google::firestore::v1beta1::Value proto;
  proto.mutable_map_value();

  ExpectRoundTrip(model, proto, FieldValue::Type::Object);
}

TEST_F(SerializerTest, WritesNestedObjects) {
  FieldValue model = FieldValue::ObjectValueFromMap({
      {"b", FieldValue::TrueValue()},
      // TODO(rsgowman): add doubles (once they're supported)
      // {"d", FieldValue::DoubleValue(std::numeric_limits<double>::max())},
      {"i", FieldValue::IntegerValue(1)},
      {"n", FieldValue::NullValue()},
      {"s", FieldValue::StringValue("foo")},
      // TODO(rsgowman): add arrays (once they're supported)
      // {"a", [2, "bar", {"b", false}]},
      {"o", FieldValue::ObjectValueFromMap({
                {"d", FieldValue::IntegerValue(100)},
                {"nested", FieldValue::ObjectValueFromMap({
                               {
                                   "e",
                                   FieldValue::IntegerValue(
                                       std::numeric_limits<int64_t>::max()),
                               },
                           })},
            })},
  });

  google::firestore::v1beta1::Value inner_proto;
  google::protobuf::Map<std::string, google::firestore::v1beta1::Value>*
      inner_fields = inner_proto.mutable_map_value()->mutable_fields();
  (*inner_fields)["e"] = ValueProto(std::numeric_limits<int64_t>::max());

  google::firestore::v1beta1::Value middle_proto;
  google::protobuf::Map<std::string, google::firestore::v1beta1::Value>*
      middle_fields = middle_proto.mutable_map_value()->mutable_fields();
  (*middle_fields)["d"] = ValueProto(int64_t{100});
  (*middle_fields)["nested"] = inner_proto;

  google::firestore::v1beta1::Value proto;
  google::protobuf::Map<std::string, google::firestore::v1beta1::Value>*
      fields = proto.mutable_map_value()->mutable_fields();
  (*fields)["b"] = ValueProto(true);
  (*fields)["i"] = ValueProto(int64_t{1});
  (*fields)["n"] = ValueProto(nullptr);
  (*fields)["s"] = ValueProto("foo");
  (*fields)["o"] = middle_proto;

  ExpectRoundTrip(model, proto, FieldValue::Type::Object);
}

TEST_F(SerializerTest, BadNullValue) {
  std::vector<uint8_t> bytes{
      0x58,  // encoded null tag
      0x01,  // invalid null value. (0 is only valid null value)
  };
  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadBoolValue) {
  std::vector<uint8_t> bytes{
      0x08,  // encoded bool tag
      0x02,  // invalid value for a bool. (Valid values are 0,1)
  };
  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadIntegerValue) {
  // clang-format off
  std::vector<uint8_t> bytes{
      0x10,  // encoded int tag
      // These bytes represent a number too large to represent in a 64 bit
      // value.  This should cause an overflow.
      0xff, 0xff, 0xff, 0xff,
      0xff, 0xff, 0xff, 0xff,
      0xff, 0xff, 0x7f,
  };
  // clang-format on
  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadStringValue) {
  // clang-format off
  std::vector<uint8_t> bytes{
      0x8a, 0x01,  // encoded string tag
      0x05,        // length 5
      'a',
  };
  // clang-format on
  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadStringValue2) {
  std::vector<uint8_t> bytes;
  Status status =
      serializer.EncodeFieldValue(FieldValue::StringValue("a"), &bytes);
  ASSERT_OK(status);

  // Claim that the string length is 5 instead of 1. (The first two bytes are
  // used by the encoded tag.)
  Mutate(&bytes[2], /*expected_initial_value=*/1, /*new_value=*/5);

  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadStringValue4) {
  std::vector<uint8_t> bytes = ExpectSuccessfullyEncodedFieldValue(
      serializer, FieldValue::StringValue("a"));

  // Claim that the string length is 5 instead of 1. (The first two bytes are
  // used by the encoded tag.)
  Mutate(&bytes[2], /*expected_initial_value=*/1, /*new_value=*/5);

  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadTag) {
  // The google::firestore::v1beta1::Value value_type oneof currently has tags
  // up to 18. For this test, we'll pick a tag that's unlikely to be added in
  // the near term but still fits within a uint8_t even when encoded.
  // Specifically 31.
  // clang-format off
  std::vector<uint8_t> bytes{
      0xf8, 0x01,  // represents field number 31 encoded as a varint
                   // There's no payload here, which is also invalid, but we
                   // won't get that far.
  };
  // clang-format on

  // TODO(rsgowman): The behaviour is *temporarily* slightly different during
  // development; this will cause a failed assertion rather than a failed
  // status. Remove this EXPECT_ANY_THROW statement (and reenable the
  // following commented out statement) once the corresponding assert has been
  // removed from serializer.cc.
  EXPECT_ANY_THROW(ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes));
  // ExpectFailedStatusDuringDecode(
  //    Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, TagVarintWiretypeStringMismatch) {
  // specifically, the tag is boolean_value, but any tag that would be
  // represented by a varint would do.
  std::vector<uint8_t> bytes{
      0x0a,  // represents a bool value encoded as a string
      0x01,  // true
  };
  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, TagStringWiretypeVarintMismatch) {
  // clang-format off
  std::vector<uint8_t> bytes{
      0x88, 0x01,  // represents a string value field encoded as a varint.
      0x01,        // string length 1
      'a',
  };
  // clang-format on
  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, IncompleteFieldValue) {
  std::vector<uint8_t> bytes{
      0x58,  // encoded null tag
             // Note: Missing '0' for the value
  };
  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, IncompleteTag) {
  std::vector<uint8_t> bytes;
  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

// TODO(rsgowman): Test [en|de]coding multiple protos into the same output
// vector.
