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
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/timestamp_internal.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "google/protobuf/stubs/common.h"
#include "google/protobuf/util/message_differencer.h"
#include "gtest/gtest.h"

using firebase::Timestamp;
using firebase::TimestampInternal;
using firebase::firestore::FirestoreErrorCode;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::remote::Serializer;
using firebase::firestore::testutil::Key;
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
  SerializerTest() : serializer(kDatabaseId) {
  }

  const DatabaseId kDatabaseId{"p", "d"};
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
    std::vector<uint8_t> bytes =
        EncodeFieldValue(&serializer, FieldValue::NullValue());
    google::firestore::v1beta1::Value proto;
    bool ok = proto.ParseFromArray(bytes.data(), bytes.size());
    EXPECT_TRUE(ok);
    return proto;
  }

  std::vector<uint8_t> EncodeFieldValue(Serializer* serializer,
                                        const FieldValue& fv) {
    std::vector<uint8_t> bytes;
    Status status = serializer->EncodeFieldValue(fv, &bytes);
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
    std::vector<uint8_t> bytes =
        EncodeFieldValue(&serializer, FieldValue::BooleanValue(b));
    google::firestore::v1beta1::Value proto;
    bool ok = proto.ParseFromArray(bytes.data(), bytes.size());
    EXPECT_TRUE(ok);
    return proto;
  }

  google::firestore::v1beta1::Value ValueProto(int64_t i) {
    std::vector<uint8_t> bytes =
        EncodeFieldValue(&serializer, FieldValue::IntegerValue(i));
    google::firestore::v1beta1::Value proto;
    bool ok = proto.ParseFromArray(bytes.data(), bytes.size());
    EXPECT_TRUE(ok);
    return proto;
  }

  google::firestore::v1beta1::Value ValueProto(const char* s) {
    return ValueProto(std::string(s));
  }

  google::firestore::v1beta1::Value ValueProto(const std::string& s) {
    std::vector<uint8_t> bytes =
        EncodeFieldValue(&serializer, FieldValue::StringValue(s));
    google::firestore::v1beta1::Value proto;
    bool ok = proto.ParseFromArray(bytes.data(), bytes.size());
    EXPECT_TRUE(ok);
    return proto;
  }

  google::firestore::v1beta1::Value ValueProto(const Timestamp& ts) {
    std::vector<uint8_t> bytes =
        EncodeFieldValue(&serializer, FieldValue::TimestampValue(ts));
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
    std::vector<uint8_t> bytes = EncodeFieldValue(&serializer, model);
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

TEST_F(SerializerTest, EncodesNull) {
  FieldValue model = FieldValue::NullValue();
  ExpectRoundTrip(model, ValueProto(nullptr), FieldValue::Type::Null);
}

TEST_F(SerializerTest, EncodesBool) {
  for (bool bool_value : {true, false}) {
    FieldValue model = FieldValue::BooleanValue(bool_value);
    ExpectRoundTrip(model, ValueProto(bool_value), FieldValue::Type::Boolean);
  }
}

TEST_F(SerializerTest, EncodesIntegers) {
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

TEST_F(SerializerTest, EncodesString) {
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

TEST_F(SerializerTest, EncodesTimestamps) {
  std::vector<Timestamp> cases{
      {},  // epoch
      {1234, 0},
      {1234, 999999999},
      {-1234, 0},
      {-1234, 999999999},
      TimestampInternal::Max(),
      TimestampInternal::Min(),
  };

  for (const Timestamp& ts_value : cases) {
    FieldValue model = FieldValue::TimestampValue(ts_value);
    ExpectRoundTrip(model, ValueProto(ts_value), FieldValue::Type::Timestamp);
  }
}

TEST_F(SerializerTest, EncodesEmptyMap) {
  FieldValue model = FieldValue::ObjectValueFromMap({});

  google::firestore::v1beta1::Value proto;
  proto.mutable_map_value();

  ExpectRoundTrip(model, proto, FieldValue::Type::Object);
}

TEST_F(SerializerTest, EncodesNestedObjects) {
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
  std::vector<uint8_t> bytes =
      EncodeFieldValue(&serializer, FieldValue::NullValue());

  // Alter the null value from 0 to 1.
  Mutate(&bytes[1], /*expected_initial_value=*/0, /*new_value=*/1);

  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadBoolValue) {
  std::vector<uint8_t> bytes =
      EncodeFieldValue(&serializer, FieldValue::BooleanValue(true));

  // Alter the bool value from 1 to 2. (Value values are 0,1)
  Mutate(&bytes[1], /*expected_initial_value=*/1, /*new_value=*/2);

  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadIntegerValue) {
  // Encode 'maxint'. This should result in 9 0xff bytes, followed by a 1.
  std::vector<uint8_t> bytes = EncodeFieldValue(
      &serializer,
      FieldValue::IntegerValue(std::numeric_limits<uint64_t>::max()));
  ASSERT_EQ(11u, bytes.size());
  for (size_t i = 1; i < bytes.size() - 1; i++) {
    ASSERT_EQ(0xff, bytes[i]);
  }

  // make the number a bit bigger
  Mutate(&bytes[10], /*expected_initial_value=*/1, /*new_value=*/0xff);
  bytes.resize(12);
  bytes[11] = 0x7f;

  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadStringValue) {
  std::vector<uint8_t> bytes =
      EncodeFieldValue(&serializer, FieldValue::StringValue("a"));

  // Claim that the string length is 5 instead of 1. (The first two bytes are
  // used by the encoded tag.)
  Mutate(&bytes[2], /*expected_initial_value=*/1, /*new_value=*/5);

  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadTimestampValue_TooLarge) {
  std::vector<uint8_t> bytes = EncodeFieldValue(
      &serializer, FieldValue::TimestampValue(TimestampInternal::Max()));

  // Add some time, which should push us above the maximum allowed timestamp.
  Mutate(&bytes[4], 0x82, 0x83);

  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadTimestampValue_TooSmall) {
  std::vector<uint8_t> bytes = EncodeFieldValue(
      &serializer, FieldValue::TimestampValue(TimestampInternal::Min()));

  // Remove some time, which should push us below the minimum allowed timestamp.
  Mutate(&bytes[4], 0x92, 0x91);

  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadTag) {
  std::vector<uint8_t> bytes =
      EncodeFieldValue(&serializer, FieldValue::NullValue());

  // The google::firestore::v1beta1::Value value_type oneof currently has tags
  // up to 18. For this test, we'll pick a tag that's unlikely to be added in
  // the near term but still fits within a uint8_t even when encoded.
  // Specifically 31. 0xf8 represents field number 31 encoded as a varint.
  Mutate(&bytes[0], /*expected_initial_value=*/0x58, /*new_value=*/0xf8);

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
  std::vector<uint8_t> bytes =
      EncodeFieldValue(&serializer, FieldValue::BooleanValue(true));

  // 0x0a represents a bool value encoded as a string. (We're using a
  // boolean_value tag here, but any tag that would be represented by a varint
  // would do.)
  Mutate(&bytes[0], /*expected_initial_value=*/0x08, /*new_value=*/0x0a);

  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, TagStringWiretypeVarintMismatch) {
  std::vector<uint8_t> bytes =
      EncodeFieldValue(&serializer, FieldValue::StringValue("foo"));

  // 0x88 represents a string value encoded as a varint.
  Mutate(&bytes[0], /*expected_initial_value=*/0x8a, /*new_value=*/0x88);

  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, IncompleteFieldValue) {
  std::vector<uint8_t> bytes =
      EncodeFieldValue(&serializer, FieldValue::NullValue());
  ASSERT_EQ(2u, bytes.size());

  // Remove the (null) payload
  ASSERT_EQ(0x00, bytes[1]);
  bytes.pop_back();

  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, IncompleteTag) {
  std::vector<uint8_t> bytes;
  ExpectFailedStatusDuringDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, EncodesKey) {
  EXPECT_EQ("projects/p/databases/d/documents", serializer.EncodeKey(Key("")));
  EXPECT_EQ("projects/p/databases/d/documents/one/two/three/four",
            serializer.EncodeKey(Key("one/two/three/four")));
}

TEST_F(SerializerTest, DecodesKey) {
  EXPECT_EQ(Key(""), serializer.DecodeKey("projects/p/databases/d/documents"));
  EXPECT_EQ(Key("one/two/three/four"),
            serializer.DecodeKey(
                "projects/p/databases/d/documents/one/two/three/four"));
  // Same, but with a leading slash
  EXPECT_EQ(Key("one/two/three/four"),
            serializer.DecodeKey(
                "/projects/p/databases/d/documents/one/two/three/four"));
}

TEST_F(SerializerTest, BadKey) {
  std::vector<std::string> bad_cases{
      "",                        // empty (and too short)
      "projects/p",              // too short
      "projects/p/databases/d",  // too short
      "projects/p/databases/d/documents/odd_number_of_local_elements",
      "projects_spelled_wrong/p/databases/d/documents",
      "projects/p/databases_spelled_wrong/d/documents",
      "projects/not_project_p/databases/d/documents",
      "projects/p/databases/not_database_d/documents",
      "projects/p/databases/d/not_documents",
  };

  for (const std::string& bad_key : bad_cases) {
    EXPECT_ANY_THROW(serializer.DecodeKey(bad_key));
  }
}

// TODO(rsgowman): Test [en|de]coding multiple protos into the same output
// vector.
