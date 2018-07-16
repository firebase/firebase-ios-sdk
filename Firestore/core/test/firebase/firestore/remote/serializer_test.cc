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
#include "Firestore/Protos/cpp/google/firestore/v1beta1/firestore.pb.h"
#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/timestamp_internal.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/types/optional.h"
#include "google/protobuf/stubs/common.h"
#include "google/protobuf/util/message_differencer.h"
#include "gtest/gtest.h"

namespace v1beta1 = google::firestore::v1beta1;
using firebase::Timestamp;
using firebase::TimestampInternal;
using firebase::firestore::FirestoreErrorCode;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::MaybeDocument;
using firebase::firestore::model::NoDocument;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::SnapshotVersion;
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
    msg_diff.ReportDifferencesToString(&message_differences);
  }

  const DatabaseId kDatabaseId{"p", "d"};
  Serializer serializer;

  void ExpectRoundTrip(const FieldValue& model,
                       const v1beta1::Value& proto,
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

  void ExpectRoundTrip(const DocumentKey& key,
                       const FieldValue& value,
                       const SnapshotVersion& update_time,
                       const v1beta1::BatchGetDocumentsResponse& proto) {
    ExpectSerializationRoundTrip(key, value, update_time, proto);
    ExpectDeserializationRoundTrip(key, value, update_time, proto);
  }

  void ExpectNoDocumentDeserializationRoundTrip(
      const DocumentKey& key,
      const SnapshotVersion& read_time,
      const v1beta1::BatchGetDocumentsResponse& proto) {
    ExpectDeserializationRoundTrip(key, absl::nullopt, read_time, proto);
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
  void ExpectFailedStatusDuringFieldValueDecode(
      Status status, const std::vector<uint8_t>& bytes) {
    StatusOr<FieldValue> bad_status = serializer.DecodeFieldValue(bytes);
    ASSERT_NOT_OK(bad_status);
    EXPECT_EQ(status.code(), bad_status.status().code());
  }

  void ExpectFailedStatusDuringMaybeDocumentDecode(
      Status status, const std::vector<uint8_t>& bytes) {
    StatusOr<std::unique_ptr<MaybeDocument>> bad_status =
        serializer.DecodeMaybeDocument(bytes);
    ASSERT_NOT_OK(bad_status);
    EXPECT_EQ(status.code(), bad_status.status().code());
  }

  v1beta1::Value ValueProto(std::nullptr_t) {
    std::vector<uint8_t> bytes =
        EncodeFieldValue(&serializer, FieldValue::NullValue());
    v1beta1::Value proto;
    bool ok =
        proto.ParseFromArray(bytes.data(), static_cast<int>(bytes.size()));
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

  std::vector<uint8_t> EncodeDocument(Serializer* serializer,
                                      const DocumentKey& key,
                                      const FieldValue& value) {
    std::vector<uint8_t> bytes;
    Status status =
        serializer->EncodeDocument(key, value.object_value(), &bytes);
    EXPECT_OK(status);
    return bytes;
  }

  void Mutate(uint8_t* byte,
              uint8_t expected_initial_value,
              uint8_t new_value) {
    ASSERT_EQ(*byte, expected_initial_value);
    *byte = new_value;
  }

  v1beta1::Value ValueProto(bool b) {
    std::vector<uint8_t> bytes =
        EncodeFieldValue(&serializer, FieldValue::BooleanValue(b));
    v1beta1::Value proto;
    bool ok =
        proto.ParseFromArray(bytes.data(), static_cast<int>(bytes.size()));
    EXPECT_TRUE(ok);
    return proto;
  }

  v1beta1::Value ValueProto(int64_t i) {
    std::vector<uint8_t> bytes =
        EncodeFieldValue(&serializer, FieldValue::IntegerValue(i));
    v1beta1::Value proto;
    bool ok =
        proto.ParseFromArray(bytes.data(), static_cast<int>(bytes.size()));
    EXPECT_TRUE(ok);
    return proto;
  }

  v1beta1::Value ValueProto(const char* s) {
    return ValueProto(std::string(s));
  }

  v1beta1::Value ValueProto(const std::string& s) {
    std::vector<uint8_t> bytes =
        EncodeFieldValue(&serializer, FieldValue::StringValue(s));
    v1beta1::Value proto;
    bool ok =
        proto.ParseFromArray(bytes.data(), static_cast<int>(bytes.size()));
    EXPECT_TRUE(ok);
    return proto;
  }

  v1beta1::Value ValueProto(const Timestamp& ts) {
    std::vector<uint8_t> bytes =
        EncodeFieldValue(&serializer, FieldValue::TimestampValue(ts));
    v1beta1::Value proto;
    bool ok =
        proto.ParseFromArray(bytes.data(), static_cast<int>(bytes.size()));
    EXPECT_TRUE(ok);
    return proto;
  }

  /**
   * Creates entries in the proto that we don't care about.
   *
   * We ignore certain fields in our serializer. We never set them, and never
   * read them (other than to throw them away). But the server could (and
   * probably does) set them, so we need to be able to discard them properly.
   * The ExpectRoundTrip deals with this asymmetry.
   *
   * This method adds these ignored fields to the proto.
   */
  void TouchIgnoredBatchGetDocumentsResponseFields(
      v1beta1::BatchGetDocumentsResponse* proto) {
    proto->set_transaction("random bytes");

    // TODO(rsgowman): This method currently assumes that this is a 'found'
    // document. We (probably) will need to adjust this to work with NoDocuments
    // too.
    v1beta1::Document* doc_proto = proto->mutable_found();
    google::protobuf::Timestamp* create_time_proto =
        doc_proto->mutable_create_time();
    create_time_proto->set_seconds(8765);
    create_time_proto->set_nanos(4321);
  }

 private:
  void ExpectSerializationRoundTrip(const FieldValue& model,
                                    const v1beta1::Value& proto,
                                    FieldValue::Type type) {
    EXPECT_EQ(type, model.type());
    std::vector<uint8_t> bytes = EncodeFieldValue(&serializer, model);
    v1beta1::Value actual_proto;
    bool ok = actual_proto.ParseFromArray(bytes.data(),
                                          static_cast<int>(bytes.size()));
    EXPECT_TRUE(ok);
    EXPECT_TRUE(msg_diff.Compare(proto, actual_proto)) << message_differences;
  }

  void ExpectDeserializationRoundTrip(const FieldValue& model,
                                      const v1beta1::Value& proto,
                                      FieldValue::Type type) {
    size_t size = proto.ByteSizeLong();
    std::vector<uint8_t> bytes(size);
    bool status = proto.SerializeToArray(bytes.data(), static_cast<int>(size));
    EXPECT_TRUE(status);
    StatusOr<FieldValue> actual_model_status =
        serializer.DecodeFieldValue(bytes);
    EXPECT_OK(actual_model_status);
    FieldValue actual_model = actual_model_status.ValueOrDie();
    EXPECT_EQ(type, actual_model.type());
    EXPECT_EQ(model, actual_model);
  }

  void ExpectSerializationRoundTrip(
      const DocumentKey& key,
      const FieldValue& value,
      const SnapshotVersion& update_time,
      const v1beta1::BatchGetDocumentsResponse& proto) {
    std::vector<uint8_t> bytes = EncodeDocument(&serializer, key, value);
    v1beta1::Document actual_proto;
    bool ok = actual_proto.ParseFromArray(bytes.data(),
                                          static_cast<int>(bytes.size()));
    EXPECT_TRUE(ok);

    // Note that the client can only serialize Documents (and cannot serialize
    // NoDocuments)
    EXPECT_TRUE(proto.has_found());

    // Slight weirdness: When we *encode* a document for sending it to the
    // backend, we don't encode the update_time (or create_time). But when we
    // *decode* a document, we *do* decode the update_time (though we still
    // ignore the create_time). Therefore, we'll verify the update_time
    // independently, and then strip it out before comparing the rest.
    EXPECT_FALSE(actual_proto.has_create_time());
    EXPECT_EQ(update_time.timestamp().seconds(),
              proto.found().update_time().seconds());
    EXPECT_EQ(update_time.timestamp().nanoseconds(),
              proto.found().update_time().nanos());
    v1beta1::BatchGetDocumentsResponse proto_copy{proto};
    proto_copy.mutable_found()->clear_update_time();
    proto_copy.mutable_found()->clear_create_time();

    EXPECT_TRUE(msg_diff.Compare(proto_copy.found(), actual_proto))
        << message_differences;
  }

  void ExpectDeserializationRoundTrip(
      const DocumentKey& key,
      const absl::optional<FieldValue> value,
      const SnapshotVersion& version,  // either update_time or read_time
      const v1beta1::BatchGetDocumentsResponse& proto) {
    size_t size = proto.ByteSizeLong();
    std::vector<uint8_t> bytes(size);
    bool status = proto.SerializeToArray(bytes.data(), static_cast<int>(size));
    EXPECT_TRUE(status);
    StatusOr<std::unique_ptr<MaybeDocument>> actual_model_status =
        serializer.DecodeMaybeDocument(bytes);
    EXPECT_OK(actual_model_status);
    std::unique_ptr<MaybeDocument> actual_model =
        std::move(actual_model_status).ValueOrDie();

    EXPECT_EQ(key, actual_model->key());
    EXPECT_EQ(version, actual_model->version());
    switch (actual_model->type()) {
      case MaybeDocument::Type::Document: {
        Document* actual_doc_model = static_cast<Document*>(actual_model.get());
        EXPECT_EQ(value, actual_doc_model->data());
        break;
      }
      case MaybeDocument::Type::NoDocument:
        EXPECT_FALSE(value.has_value());
        break;
      case MaybeDocument::Type::Unknown:
        FAIL() << "We somehow created an invalid model object";
    }
  }

  std::string message_differences;
  MessageDifferencer msg_diff;
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
      u8"æ",
      // Note: Each one of the three embedded universal character names
      // (\u-escaped) maps to three chars, so the total length of the string
      // literal is 10 (ignoring the terminating null), and the resulting string
      // literal is the same as '\0\xed\x9f\xbf\xee\x80\x80\xef\xbf\xbf'". The
      // size of 10 must be added, or else std::string will see the \0 at the
      // start and assume that's the end of the string.
      {u8"\0\ud7ff\ue000\uffff", 10},
      {"\0\xed\x9f\xbf\xee\x80\x80\xef\xbf\xbf", 10},
      u8"(╯°□°）╯︵ ┻━┻",
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

  v1beta1::Value proto;
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

  v1beta1::Value inner_proto;
  google::protobuf::Map<std::string, v1beta1::Value>* inner_fields =
      inner_proto.mutable_map_value()->mutable_fields();
  (*inner_fields)["e"] = ValueProto(std::numeric_limits<int64_t>::max());

  v1beta1::Value middle_proto;
  google::protobuf::Map<std::string, v1beta1::Value>* middle_fields =
      middle_proto.mutable_map_value()->mutable_fields();
  (*middle_fields)["d"] = ValueProto(int64_t{100});
  (*middle_fields)["nested"] = inner_proto;

  v1beta1::Value proto;
  google::protobuf::Map<std::string, v1beta1::Value>* fields =
      proto.mutable_map_value()->mutable_fields();
  (*fields)["b"] = ValueProto(true);
  (*fields)["i"] = ValueProto(int64_t{1});
  (*fields)["n"] = ValueProto(nullptr);
  (*fields)["s"] = ValueProto("foo");
  (*fields)["o"] = middle_proto;

  ExpectRoundTrip(model, proto, FieldValue::Type::Object);
}

TEST_F(SerializerTest, EncodesFieldValuesWithRepeatedEntries) {
  // Technically, serialized Value protos can contain multiple values. (The last
  // one "wins".) However, well-behaved proto emitters (such as libprotobuf)
  // won't generate that, so to test, we either need to use hand-crafted, raw
  // bytes or use a proto message that's *almost* the same as the real one, such
  // that when it's encoded, you can generate these repeated fields. (This is
  // how libprotobuf tests itself.)
  //
  // Using libprotobuf for this purpose is mildly inconvenient for us, since we
  // don't run protoc as part of the build process, so we'd need to either add
  // these fake messages to our protos tree (Protos/testprotos?) and then check
  // in the results (which isn't great when writing new tests). Fortunately, we
  // have another alternative: nanopb.
  //
  // So we'll create a nanopb struct that *looks* like
  // google_firestore_v1beta1_Value, and then populate and serialize it using
  // the normal nanopb mechanisms. This should give us a wire-compatible Value
  // message, but with multiple values set.

  // Copy of the real one (from the nanopb generated document.pb.h), but with
  // only boolean_value and integer_value.
  struct google_firestore_v1beta1_Value_Fake {
    bool boolean_value;
    int64_t integer_value;
  };

  // Copy of the real one (from the nanopb generated document.pb.c), but with
  // only boolean_value and integer_value.
  const pb_field_t google_firestore_v1beta1_Value_fields_Fake[3] = {
      PB_FIELD(1, BOOL, SINGULAR, STATIC, FIRST,
               google_firestore_v1beta1_Value_Fake, boolean_value,
               boolean_value, 0),
      PB_FIELD(2, INT64, SINGULAR, STATIC, OTHER,
               google_firestore_v1beta1_Value_Fake, integer_value,
               boolean_value, 0),
      PB_LAST_FIELD,
  };

  // Craft the bytes. boolean_value has a smaller tag, so it'll get encoded
  // first. Implying integer_value should "win".
  google_firestore_v1beta1_Value_Fake crafty_value{false, int64_t{42}};
  std::vector<uint8_t> bytes(128);
  pb_ostream_t stream = pb_ostream_from_buffer(bytes.data(), bytes.size());
  pb_encode(&stream, google_firestore_v1beta1_Value_fields_Fake, &crafty_value);
  bytes.resize(stream.bytes_written);

  // Decode the bytes into the model
  StatusOr<FieldValue> actual_model_status = serializer.DecodeFieldValue(bytes);
  EXPECT_OK(actual_model_status);
  FieldValue actual_model = actual_model_status.ValueOrDie();

  // Ensure the decoded model is as expected.
  FieldValue expected_model = FieldValue::IntegerValue(42);
  EXPECT_EQ(FieldValue::Type::Integer, actual_model.type());
  EXPECT_EQ(expected_model, actual_model);
}

TEST_F(SerializerTest, BadNullValue) {
  std::vector<uint8_t> bytes =
      EncodeFieldValue(&serializer, FieldValue::NullValue());

  // Alter the null value from 0 to 1.
  Mutate(&bytes[1], /*expected_initial_value=*/0, /*new_value=*/1);

  ExpectFailedStatusDuringFieldValueDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadBoolValue) {
  std::vector<uint8_t> bytes =
      EncodeFieldValue(&serializer, FieldValue::BooleanValue(true));

  // Alter the bool value from 1 to 2. (Value values are 0,1)
  Mutate(&bytes[1], /*expected_initial_value=*/1, /*new_value=*/2);

  ExpectFailedStatusDuringFieldValueDecode(
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

  ExpectFailedStatusDuringFieldValueDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadStringValue) {
  std::vector<uint8_t> bytes =
      EncodeFieldValue(&serializer, FieldValue::StringValue("a"));

  // Claim that the string length is 5 instead of 1. (The first two bytes are
  // used by the encoded tag.)
  Mutate(&bytes[2], /*expected_initial_value=*/1, /*new_value=*/5);

  ExpectFailedStatusDuringFieldValueDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadTimestampValue_TooLarge) {
  std::vector<uint8_t> bytes = EncodeFieldValue(
      &serializer, FieldValue::TimestampValue(TimestampInternal::Max()));

  // Add some time, which should push us above the maximum allowed timestamp.
  Mutate(&bytes[4], 0x82, 0x83);

  ExpectFailedStatusDuringFieldValueDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadTimestampValue_TooSmall) {
  std::vector<uint8_t> bytes = EncodeFieldValue(
      &serializer, FieldValue::TimestampValue(TimestampInternal::Min()));

  // Remove some time, which should push us below the minimum allowed timestamp.
  Mutate(&bytes[4], 0x92, 0x91);

  ExpectFailedStatusDuringFieldValueDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadFieldValueTagAndNoOtherTagPresent) {
  // A bad tag should be ignored. But if there are *no* valid tags, then we
  // don't know the type of the FieldValue. Although it might be reasonable to
  // assume some sort of default type in this situation, we've decided to fail
  // the deserialization process in this case instead.

  std::vector<uint8_t> bytes =
      EncodeFieldValue(&serializer, FieldValue::NullValue());

  // The v1beta1::Value value_type oneof currently has tags
  // up to 18. For this test, we'll pick a tag that's unlikely to be added in
  // the near term but still fits within a uint8_t even when encoded.
  // Specifically 31. 0xf8 represents field number 31 encoded as a varint.
  Mutate(&bytes[0], /*expected_initial_value=*/0x58, /*new_value=*/0xf8);

  ExpectFailedStatusDuringFieldValueDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadFieldValueTagWithOtherValidTagsPresent) {
  // A bad tag should be ignored, in which case, we should successfully
  // deserialize the rest of the bytes as if it wasn't there. To craft these
  // bytes, we'll use the same technique as
  // EncodesFieldValuesWithRepeatedEntries (so go read the comments there
  // first).

  // Copy of the real one (from the nanopb generated document.pb.h), but with
  // only boolean_value and integer_value.
  struct google_firestore_v1beta1_Value_Fake {
    bool boolean_value;
    int64_t integer_value;
  };

  // Copy of the real one (from the nanopb generated document.pb.c), but with
  // only boolean_value and integer_value. Also modified such that integer_value
  // now has an invalid tag (instead of 2).
  const int invalid_tag = 31;
  const pb_field_t google_firestore_v1beta1_Value_fields_Fake[3] = {
      PB_FIELD(1, BOOL, SINGULAR, STATIC, FIRST,
               google_firestore_v1beta1_Value_Fake, boolean_value,
               boolean_value, 0),
      PB_FIELD(invalid_tag, INT64, SINGULAR, STATIC, OTHER,
               google_firestore_v1beta1_Value_Fake, integer_value,
               boolean_value, 0),
      PB_LAST_FIELD,
  };

  // Craft the bytes. boolean_value has a smaller tag, so it'll get encoded
  // first, normally implying integer_value should "win". Except that
  // integer_value isn't a valid tag, so it should be ignored here.
  google_firestore_v1beta1_Value_Fake crafty_value{true, int64_t{42}};
  std::vector<uint8_t> bytes(128);
  pb_ostream_t stream = pb_ostream_from_buffer(bytes.data(), bytes.size());
  pb_encode(&stream, google_firestore_v1beta1_Value_fields_Fake, &crafty_value);
  bytes.resize(stream.bytes_written);

  // Decode the bytes into the model
  StatusOr<FieldValue> actual_model_status = serializer.DecodeFieldValue(bytes);
  Status s = actual_model_status.status();
  EXPECT_OK(actual_model_status);
  FieldValue actual_model = actual_model_status.ValueOrDie();

  // Ensure the decoded model is as expected.
  FieldValue expected_model = FieldValue::BooleanValue(true);
  EXPECT_EQ(FieldValue::Type::Boolean, actual_model.type());
  EXPECT_EQ(expected_model, actual_model);
}

TEST_F(SerializerTest, TagVarintWiretypeStringMismatch) {
  std::vector<uint8_t> bytes =
      EncodeFieldValue(&serializer, FieldValue::BooleanValue(true));

  // 0x0a represents a bool value encoded as a string. (We're using a
  // boolean_value tag here, but any tag that would be represented by a varint
  // would do.)
  Mutate(&bytes[0], /*expected_initial_value=*/0x08, /*new_value=*/0x0a);

  ExpectFailedStatusDuringFieldValueDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, TagStringWiretypeVarintMismatch) {
  std::vector<uint8_t> bytes =
      EncodeFieldValue(&serializer, FieldValue::StringValue("foo"));

  // 0x88 represents a string value encoded as a varint.
  Mutate(&bytes[0], /*expected_initial_value=*/0x8a, /*new_value=*/0x88);

  ExpectFailedStatusDuringFieldValueDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, IncompleteFieldValue) {
  std::vector<uint8_t> bytes =
      EncodeFieldValue(&serializer, FieldValue::NullValue());
  ASSERT_EQ(2u, bytes.size());

  // Remove the (null) payload
  ASSERT_EQ(0x00, bytes[1]);
  bytes.pop_back();

  ExpectFailedStatusDuringFieldValueDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, IncompleteTag) {
  std::vector<uint8_t> bytes;
  ExpectFailedStatusDuringFieldValueDecode(
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

TEST_F(SerializerTest, EncodesEmptyDocument) {
  DocumentKey key = DocumentKey::FromPathString("path/to/the/doc");
  FieldValue empty_value = FieldValue::ObjectValueFromMap({});
  SnapshotVersion update_time = SnapshotVersion{{1234, 5678}};

  v1beta1::BatchGetDocumentsResponse proto;
  v1beta1::Document* doc_proto = proto.mutable_found();
  doc_proto->set_name(serializer.EncodeKey(key));
  doc_proto->mutable_fields();

  google::protobuf::Timestamp* update_time_proto =
      doc_proto->mutable_update_time();
  update_time_proto->set_seconds(1234);
  update_time_proto->set_nanos(5678);

  TouchIgnoredBatchGetDocumentsResponseFields(&proto);

  ExpectRoundTrip(key, empty_value, update_time, proto);
}

TEST_F(SerializerTest, EncodesNonEmptyDocument) {
  DocumentKey key = DocumentKey::FromPathString("path/to/the/doc");
  FieldValue fields = FieldValue::ObjectValueFromMap({
      {"foo", FieldValue::StringValue("bar")},
      {"two", FieldValue::IntegerValue(2)},
      {"nested", FieldValue::ObjectValueFromMap({
                     {"fourty-two", FieldValue::IntegerValue(42)},
                 })},
  });
  SnapshotVersion update_time = SnapshotVersion{{1234, 5678}};

  v1beta1::Value inner_proto;
  google::protobuf::Map<std::string, v1beta1::Value>& inner_fields =
      *inner_proto.mutable_map_value()->mutable_fields();
  inner_fields["fourty-two"] = ValueProto(int64_t{42});

  v1beta1::BatchGetDocumentsResponse proto;
  v1beta1::Document* doc_proto = proto.mutable_found();
  doc_proto->set_name(serializer.EncodeKey(key));
  google::protobuf::Map<std::string, v1beta1::Value>& m =
      *doc_proto->mutable_fields();
  m["foo"] = ValueProto("bar");
  m["two"] = ValueProto(int64_t{2});
  m["nested"] = inner_proto;

  google::protobuf::Timestamp* update_time_proto =
      doc_proto->mutable_update_time();
  update_time_proto->set_seconds(1234);
  update_time_proto->set_nanos(5678);

  TouchIgnoredBatchGetDocumentsResponseFields(&proto);

  ExpectRoundTrip(key, fields, update_time, proto);
}

TEST_F(SerializerTest,
       BadBatchGetDocumentsResponseTagWithOtherValidTagsPresent) {
  // A bad tag should be ignored, in which case, we should successfully
  // deserialize the rest of the bytes as if it wasn't there. To craft these
  // bytes, we'll use the same technique as
  // EncodesFieldValuesWithRepeatedEntries (so go read the comments there
  // first).

  // Copy of the real one (from the nanopb generated firestore.pb.h), but with
  // only "missing" (a field from the original proto) and an extra_field.
  struct google_firestore_v1beta1_BatchGetDocumentsResponse_Fake {
    pb_callback_t missing;
    int64_t extra_field;
  };

  // Copy of the real one (from the nanopb generated firestore.pb.c), but with
  // only missing and an extra_field. Also modified such that extra_field
  // now has a tag of 31.
  const int invalid_tag = 31;
  const pb_field_t
      google_firestore_v1beta1_BatchGetDocumentsResponse_fields_Fake[3] = {
          PB_FIELD(2, STRING, SINGULAR, CALLBACK, FIRST,
                   google_firestore_v1beta1_BatchGetDocumentsResponse_Fake,
                   missing, missing, 0),
          PB_FIELD(invalid_tag, INT64, SINGULAR, STATIC, OTHER,
                   google_firestore_v1beta1_BatchGetDocumentsResponse_Fake,
                   extra_field, missing, 0),
          PB_LAST_FIELD,
      };

  const char* missing_value = "projects/p/databases/d/documents/one/two";
  google_firestore_v1beta1_BatchGetDocumentsResponse_Fake crafty_value;
  crafty_value.missing.funcs.encode =
      [](pb_ostream_t* stream, const pb_field_t* field, void* const* arg) {
        const char* missing_value = static_cast<const char*>(*arg);
        if (!pb_encode_tag_for_field(stream, field)) return false;
        return pb_encode_string(stream,
                                reinterpret_cast<const uint8_t*>(missing_value),
                                strlen(missing_value));
      };
  crafty_value.missing.arg = const_cast<char*>(missing_value);
  crafty_value.extra_field = 42;

  std::vector<uint8_t> bytes(128);
  pb_ostream_t stream = pb_ostream_from_buffer(bytes.data(), bytes.size());
  pb_encode(&stream,
            google_firestore_v1beta1_BatchGetDocumentsResponse_fields_Fake,
            &crafty_value);
  bytes.resize(stream.bytes_written);

  // Decode the bytes into the model
  StatusOr<std::unique_ptr<MaybeDocument>> actual_model_status =
      serializer.DecodeMaybeDocument(bytes);
  EXPECT_OK(actual_model_status);
  std::unique_ptr<MaybeDocument> actual_model =
      std::move(actual_model_status).ValueOrDie();

  // Ensure the decoded model is as expected.
  NoDocument expected_model =
      NoDocument(Key("one/two"), SnapshotVersion::None());
  EXPECT_EQ(expected_model, *actual_model.get());
}

TEST_F(SerializerTest, DecodesNoDocument) {
  // We can't actually *encode* a NoDocument; the method exposed by the
  // serializer requires both the document key and contents (as an ObjectValue,
  // i.e. map.) The contents can be empty, but not missing.  As a result, this
  // test will only verify the ability to decode a NoDocument.

  DocumentKey key = DocumentKey::FromPathString("path/to/the/doc");
  SnapshotVersion read_time =
      SnapshotVersion{{/*seconds=*/1234, /*nanoseconds=*/5678}};

  v1beta1::BatchGetDocumentsResponse proto;
  proto.set_missing(serializer.EncodeKey(key));
  google::protobuf::Timestamp* read_time_proto = proto.mutable_read_time();
  read_time_proto->set_seconds(read_time.timestamp().seconds());
  read_time_proto->set_nanos(read_time.timestamp().nanoseconds());

  ExpectNoDocumentDeserializationRoundTrip(key, read_time, proto);
}

TEST_F(SerializerTest, DecodeMaybeDocWithoutFoundOrMissingSetShouldFail) {
  v1beta1::BatchGetDocumentsResponse proto;

  std::vector<uint8_t> bytes(proto.ByteSizeLong());
  bool status =
      proto.SerializeToArray(bytes.data(), static_cast<int>(bytes.size()));
  EXPECT_TRUE(status);

  ExpectFailedStatusDuringMaybeDocumentDecode(
      Status(FirestoreErrorCode::DataLoss, "ignored"), bytes);
}

// TODO(rsgowman): Test [en|de]coding multiple protos into the same output
// vector.
