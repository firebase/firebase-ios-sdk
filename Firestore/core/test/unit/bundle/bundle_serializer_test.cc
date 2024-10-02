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

#include "Firestore/core/src/bundle/bundle_serializer.h"

#include "Firestore/Protos/cpp/firestore/bundle.pb.h"
#include "Firestore/Protos/cpp/firestore/local/maybe_document.pb.h"
#include "Firestore/Protos/cpp/google/firestore/v1/document.pb.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/core/target.h"
#include "Firestore/core/src/local/local_serializer.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/test/unit/nanopb/nanopb_testing.h"
#include "Firestore/core/test/unit/testutil/status_testing.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "google/protobuf/util/json_util.h"
#include "google/protobuf/util/message_differencer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace bundle {
namespace {

using google::protobuf::Message;
using google::protobuf::util::MessageDifferencer;
using nlohmann::json;
using ProtoBundledDocumentMetadata = ::firestore::BundledDocumentMetadata;
using ProtoBundleMetadata = ::firestore::BundleMetadata;
using ProtoDocument = ::google::firestore::v1::Document;
using ProtoMaybeDocument = ::firestore::client::MaybeDocument;
using ProtoNamedQuery = ::firestore::NamedQuery;
using ProtoValue = ::google::firestore::v1::Value;
using core::Query;
using core::Target;
using local::LocalSerializer;
using model::DatabaseId;
using nanopb::ByteString;
using nanopb::MakeByteString;
using nanopb::MakeSharedMessage;
using nanopb::ProtobufParse;
using remote::Serializer;
using std::numeric_limits;
using testutil::Array;
using testutil::Filter;
using testutil::Map;
using testutil::OrderBy;
using testutil::Value;
using util::JsonReader;

json Parse(const std::string& s) {
  return json::parse(s, /*callback=*/nullptr, /*allow_exception=*/false);
}

void MessageToJsonString(const Message& message, std::string* output) {
  auto status = google::protobuf::util::MessageToJsonString(message, output);
  HARD_ASSERT(status.ok());
}

class BundleSerializerTest : public ::testing::Test {
 public:
  BundleSerializerTest()
      : remote_serializer(DatabaseId("p", "default")),
        local_serializer(remote_serializer),
        bundle_serializer(remote_serializer) {
    msg_diff_.ReportDifferencesToString(&message_differences);
  }

  remote::Serializer remote_serializer;
  local::LocalSerializer local_serializer;
  bundle::BundleSerializer bundle_serializer;

  static std::string FullPath(const std::string& path) {
    return "projects/p/databases/default/documents/" + path;
  }

  static ProtoDocument TestDocument(ProtoValue value) {
    ProtoDocument document;
    document.set_name(FullPath("bundle/test_doc"));
    auto now = Timestamp::Now();
    document.mutable_update_time()->set_nanos(now.nanoseconds());
    document.mutable_update_time()->set_seconds(now.seconds());
    document.mutable_fields()->insert({"foo", value});

    return document;
  }

  // 1. Take the value, put it in a libprotobuf Document message and print it
  // into a JSON string.
  // 2. Use BundleSerializer to parse the string, then encode the parsed
  // document into nanopb bytes.
  // 3. Parse the nanopb bytes to libprotobuf Document message, then compare
  // with the original.
  void VerifyFieldValueRoundtrip(ProtoValue value) {
    ProtoDocument document = TestDocument(value);

    std::string json_string;
    MessageToJsonString(document, &json_string);

    auto actual = VerifyJsonStringDecodes(json_string);

    VerifyDecodedDocumentEncodesToOriginal(actual.document(), document);
  }

  void VerifyDecodedDocumentEncodesToOriginal(
      const model::MutableDocument& decoded, const ProtoDocument& original) {
    ByteString bytes =
        nanopb::MakeByteString(local_serializer.EncodeMaybeDocument(decoded));
    ProtoMaybeDocument maybe_document;
    *maybe_document.mutable_document() = original;
    EXPECT_TRUE(msg_diff_.Compare(maybe_document,
                                  ProtobufParse<ProtoMaybeDocument>(bytes)))
        << message_differences;
    message_differences.clear();
  }

  void VerifyFieldValueDecodeFails(ProtoValue value) {
    ProtoDocument document = TestDocument(value);

    std::string json_string;
    MessageToJsonString(document, &json_string);
    VerifyJsonStringDecodeFails(std::move(json_string));
  }

  BundleDocument VerifyJsonStringDecodes(std::string json_string) {
    JsonReader reader;
    BundleDocument actual =
        bundle_serializer.DecodeDocument(reader, Parse(json_string));
    EXPECT_OK(reader.status());
    return actual;
  }

  void VerifyJsonStringDecodeFails(std::string json_string) {
    JsonReader reader;
    BundleDocument actual =
        bundle_serializer.DecodeDocument(reader, Parse(json_string));
    EXPECT_NOT_OK(reader.status());
  }

  // 1. Take a `Query` object, put it in a `NamedQuery` and encode it to byte
  // array via nanopb.
  // 2. Parse the byte array to libprotobuf named query
  // 3. Get Json presentation of the protobuf named query
  // 4. Parse the json back to `NamedQuery` object, then compare.
  void VerifyNamedQueryRoundtrip(const Query& original) const {
    // `First` and `None` will be encoded as BundledQuery.limit_type = `First`,
    // as not all SDKs have a `None`.
    auto limit_type = original.limit_type() == core::LimitType::Last
                          ? core::LimitType::Last
                          : core::LimitType::First;
    BundledQuery bundled_query(original.ToTarget(), limit_type);
    NamedQuery named_query("query-1", bundled_query, testutil::Version(1000));
    ByteString bytes =
        nanopb::MakeByteString(local_serializer.EncodeNamedQuery(named_query));
    ProtoNamedQuery proto_named_query = ProtobufParse<ProtoNamedQuery>(bytes);

    std::string json_string;
    MessageToJsonString(proto_named_query, &json_string);

    JsonReader reader;
    NamedQuery actual =
        bundle_serializer.DecodeNamedQuery(reader, Parse(json_string));
    EXPECT_OK(reader.status());

    EXPECT_EQ(actual.bundled_query().limit_type(),
              named_query.bundled_query().limit_type());
    EXPECT_EQ(actual.read_time(), named_query.read_time());
    EXPECT_EQ(actual.query_name(), named_query.query_name());
    EXPECT_EQ(actual.bundled_query().target(),
              named_query.bundled_query().target());
  }

  std::string NamedQueryJsonString(const Query& original) const {
    // `First` and `None` will be encoded as BundledQuery.limit_type = `First`,
    // as not all SDKs have a `None`.
    auto limit_type = original.limit_type() == core::LimitType::Last
                          ? core::LimitType::Last
                          : core::LimitType::First;
    BundledQuery bundled_query(original.ToTarget(), limit_type);
    NamedQuery named_query("query-1", bundled_query,
                           model::SnapshotVersion(Timestamp::Now()));
    ByteString bytes =
        nanopb::MakeByteString(local_serializer.EncodeNamedQuery(named_query));
    ProtoNamedQuery proto_named_query = ProtobufParse<ProtoNamedQuery>(bytes);

    std::string json_string;
    MessageToJsonString(proto_named_query, &json_string);

    return json_string;
  }

 protected:
  MessageDifferencer msg_diff_;
  std::string message_differences;
};

ProtoBundleMetadata TestBundleMetadata() {
  ProtoBundleMetadata proto_metadata{};
  *proto_metadata.mutable_id() = "bundle-1";
  proto_metadata.mutable_create_time()->set_seconds(2);
  proto_metadata.mutable_create_time()->set_nanos(3);
  proto_metadata.set_version(1);
  proto_metadata.set_total_bytes(123456789987654321L);
  proto_metadata.set_total_documents(9999);
  return proto_metadata;
}

std::string ReplacedCopy(const std::string& source,
                         const std::string& pattern,
                         const std::string& value) {
  std::string result{source};
  auto start = result.find(pattern);
  if (start == std::string::npos) {
    return result;
  }

  result.replace(start, pattern.size(), value);
  return result;
}

// MARK: Tests for BundleMetadata decoding

TEST_F(BundleSerializerTest, DecodesBundleMetadata) {
  auto proto_metadata = TestBundleMetadata();

  std::string json_string;
  MessageToJsonString(proto_metadata, &json_string);

  JsonReader reader;
  BundleMetadata actual =
      bundle_serializer.DecodeBundleMetadata(reader, Parse(json_string));

  EXPECT_OK(reader.status());
  EXPECT_EQ(proto_metadata.id(), actual.bundle_id());
  EXPECT_EQ(proto_metadata.create_time().seconds(),
            actual.create_time().timestamp().seconds());
  EXPECT_EQ(proto_metadata.create_time().nanos(),
            actual.create_time().timestamp().nanoseconds());
  EXPECT_EQ(proto_metadata.version(), actual.version());
  EXPECT_EQ(proto_metadata.total_bytes(), actual.total_bytes());
  EXPECT_EQ(proto_metadata.total_documents(), actual.total_documents());
}

TEST_F(BundleSerializerTest, DecodesInvalidBundleMetadataReportsError) {
  auto proto_metadata = TestBundleMetadata();

  std::string json_string;
  MessageToJsonString(proto_metadata, &json_string);

  {
    auto invalid = "123" + json_string;
    JsonReader reader;
    bundle_serializer.DecodeBundleMetadata(reader, invalid);

    EXPECT_NOT_OK(reader.status());
  }

  // Replace total_bytes to a string unparseable to integer.
  {
    std::string json_copy =
        ReplacedCopy(json_string, "123456789987654321", "xxxyyyzzz");
    JsonReader reader;
    bundle_serializer.DecodeBundleMetadata(reader, Parse(json_copy));

    EXPECT_NOT_OK(reader.status());
  }

  // Replace total_documents to an integer that is too large.
  {
    auto json_copy =
        ReplacedCopy(json_string, "9999", "\"123456789987654321\"");
    JsonReader reader;
    bundle_serializer.DecodeBundleMetadata(reader, Parse(json_copy));

    EXPECT_NOT_OK(reader.status());
  }

  // Replace total_documents to a string unparseable to integer.
  {
    auto json_copy = ReplacedCopy(json_string, "9999", "\"xxxyyyzzz\"");
    JsonReader reader;
    bundle_serializer.DecodeBundleMetadata(reader, Parse(json_copy));

    EXPECT_NOT_OK(reader.status());
  }

  // Replace bundle_id to a integer.
  {
    auto json_copy = ReplacedCopy(json_string, "\"bundle-1\"", "1");
    JsonReader reader;
    bundle_serializer.DecodeBundleMetadata(reader, Parse(json_copy));

    EXPECT_NOT_OK(reader.status());
  }
}

// MARK: Tests for Value/Document decoding

TEST_F(BundleSerializerTest, DecodesUninitiatedValueFails) {
  ProtoValue value;

  VerifyFieldValueDecodeFails(value);
}

TEST_F(BundleSerializerTest, DecodesInvalidJsonFails) {
  ProtoValue value;
  value.set_integer_value(12345);
  ProtoDocument document = TestDocument(value);

  std::string json_string;
  MessageToJsonString(document, &json_string);

  auto json_copy = ReplacedCopy(json_string, "12345", "{:hH{");
  VerifyJsonStringDecodeFails(json_copy);
}

TEST_F(BundleSerializerTest, DecodesNullValue) {
  ProtoValue value;
  value.set_null_value(google::protobuf::NULL_VALUE);

  VerifyFieldValueRoundtrip(value);
}

TEST_F(BundleSerializerTest, DecodesUnrecognizableTypeFails) {
  ProtoValue value;
  value.set_null_value(google::protobuf::NULL_VALUE);
  ProtoDocument document = TestDocument(value);

  std::string json_string;
  MessageToJsonString(document, &json_string);

  auto json_copy = ReplacedCopy(json_string, "nullValue", "NullValue");
  VerifyJsonStringDecodeFails(json_copy);
}

TEST_F(BundleSerializerTest, DecodesBooleanValues) {
  for (bool v : {true, false}) {
    ProtoValue value;
    value.set_boolean_value(v);

    VerifyFieldValueRoundtrip(value);
  }
}

TEST_F(BundleSerializerTest, DecodesInvalidBooleanValueFails) {
  ProtoValue value;
  value.set_boolean_value(false);
  ProtoDocument document = TestDocument(value);

  std::string json_string;
  MessageToJsonString(document, &json_string);

  auto json_copy = ReplacedCopy(json_string, "false", "truthy");
  VerifyJsonStringDecodeFails(json_copy);
}

TEST_F(BundleSerializerTest, DecodesStringEncodedIntegerValues) {
  for (int64_t v : {LONG_MIN, -100L, -1L, 0L, 1L, 100L, LONG_MAX}) {
    ProtoValue value;
    value.set_integer_value(v);

    VerifyFieldValueRoundtrip(value);
  }
}

TEST_F(BundleSerializerTest, DecodesIntegerValues) {
  ProtoValue value;
  value.set_integer_value(999888);
  ProtoDocument document = TestDocument(value);

  std::string json_string;
  MessageToJsonString(document, &json_string);
  // Forcing a integerValue encoded as integer itself, not a string.
  // Protobuf.js encodes this way with 32-bit integers.
  auto json_copy = ReplacedCopy(json_string, "\"999888\"", "999888");

  JsonReader reader;
  BundleDocument actual =
      bundle_serializer.DecodeDocument(reader, Parse(json_copy));
  EXPECT_OK(reader.status());

  VerifyDecodedDocumentEncodesToOriginal(actual.document(), document);
}

TEST_F(BundleSerializerTest, DecodesInvalidIntegerValueFails) {
  ProtoValue value;
  value.set_integer_value(22222);
  ProtoDocument document = TestDocument(value);

  std::string json_string;
  MessageToJsonString(document, &json_string);

  auto json_copy = ReplacedCopy(json_string, "22222", "XXXXX");
  VerifyJsonStringDecodeFails(json_copy);
}

TEST_F(BundleSerializerTest, DecodesDoubleValues) {
  for (double_t v :
       {-std::numeric_limits<double>::infinity(),
        std::numeric_limits<double>::lowest(),
        std::numeric_limits<int64_t>::min() - 1.0, -2.0, -1.1, -1.0,
        -std::numeric_limits<double>::epsilon(),
        -std::numeric_limits<double>::min(),
        -std::numeric_limits<double>::denorm_min(), -0.0, 0.0,
        std::numeric_limits<double>::denorm_min(),
        std::numeric_limits<double>::min(),
        std::numeric_limits<double>::epsilon(), 1.0, 1.1, 2.0,
        // Static cast silences warning about the conversion changing the value.
        static_cast<double>(std::numeric_limits<int64_t>::max()) - 1.0,
        static_cast<double>(std::numeric_limits<int64_t>::max()),
        static_cast<double>(std::numeric_limits<int64_t>::max()) + 1.0,
        std::numeric_limits<double>::max(),
        std::numeric_limits<double>::infinity()}) {
    ProtoValue value;
    value.set_double_value(v);

    VerifyFieldValueRoundtrip(value);
  }
}

TEST_F(BundleSerializerTest, DecodesInvalidDoubleValueFails) {
  ProtoValue value;
  value.set_double_value(22222);
  ProtoDocument document = TestDocument(value);

  std::string json_string;
  MessageToJsonString(document, &json_string);

  auto json_copy = ReplacedCopy(json_string, "22222", "XXXXX");
  VerifyJsonStringDecodeFails(json_copy);
}

TEST_F(BundleSerializerTest, DecodesNanDoubleValues) {
  ProtoValue value;
  value.set_double_value(absl::bit_cast<double>(testutil::kCanonicalNanBits));
  ProtoDocument document = TestDocument(value);

  std::string json_string;
  MessageToJsonString(document, &json_string);

  JsonReader reader;
  BundleDocument actual =
      bundle_serializer.DecodeDocument(reader, Parse(json_string));
  EXPECT_OK(reader.status());
  auto actual_value =
      actual.document().field(model::FieldPath::FromDotSeparatedString("foo"));
  EXPECT_TRUE(model::IsNaNValue(*actual_value));
}

TEST_F(BundleSerializerTest, DecodesStrings) {
  for (const auto& v :
       {"", "a", "abc def", "æ", "\0\ud7ff\ue000\uffff", "(╯°□°）╯︵ ┻━┻"}) {
    ProtoValue value;
    value.set_string_value(v);

    VerifyFieldValueRoundtrip(value);
  }
}

TEST_F(BundleSerializerTest, DecodesTimestamps) {
  google::protobuf::Timestamp t1;
  t1.set_seconds(0);
  t1.set_nanos(0);
  google::protobuf::Timestamp t2;
  t2.set_seconds(1577840400);
  t2.set_nanos(1000000);
  google::protobuf::Timestamp t3;
  t3.set_seconds(1577840520);
  t3.set_nanos(1002000);
  google::protobuf::Timestamp t4;
  t4.set_seconds(1577840523);
  t4.set_nanos(1002003);
  google::protobuf::Timestamp t5;
  t5.set_seconds(-3);
  t5.set_nanos(750);
  for (const auto& v : {t1, t2, t3, t4, t5}) {
    ProtoValue value;
    *value.mutable_timestamp_value() = v;

    VerifyFieldValueRoundtrip(value);
  }
}

TEST_F(BundleSerializerTest, DecodesTimestampsEncodedAsObjects) {
  google::protobuf::Timestamp t1;
  t1.set_seconds(0);
  t1.set_nanos(0);
  google::protobuf::Timestamp t2;
  t2.set_seconds(1577840523);
  t2.set_nanos(674224853);
  google::protobuf::Timestamp t3;
  t3.set_seconds(-3);
  t3.set_nanos(750);

  for (const auto& test_pair : {
           std::make_pair(t1, "\"1970-01-01T00:00:00Z\""),
           std::make_pair(t2, "\"2020-01-01T01:02:03.674224853Z\""),
           std::make_pair(t3, "\"1969-12-31T23:59:57.000000750Z\""),
       }) {
    ProtoValue value;
    *value.mutable_timestamp_value() = test_pair.first;
    ProtoDocument document = TestDocument(value);

    std::string json_string;
    MessageToJsonString(document, &json_string);
    // Forcing a timestampValue to be encoded as an object.
    auto replacement =
        "{ \"seconds\": \"" + std::to_string(test_pair.first.seconds()) +
        "\", \"nanos\": " + std::to_string(test_pair.first.nanos()) + "}";
    auto json_copy = ReplacedCopy(json_string, test_pair.second, replacement);

    JsonReader reader;
    BundleDocument actual =
        bundle_serializer.DecodeDocument(reader, Parse(json_copy));
    EXPECT_OK(reader.status());

    VerifyDecodedDocumentEncodesToOriginal(actual.document(), document);
  }
}

TEST_F(BundleSerializerTest, DecodesInvalidTimestampValueFails) {
  google::protobuf::Timestamp t1;
  t1.set_seconds(0);
  t1.set_nanos(0);
  ProtoValue value;
  *value.mutable_timestamp_value() = t1;
  ProtoDocument document = TestDocument(value);

  std::string json_string;
  MessageToJsonString(document, &json_string);

  auto json_copy =
      ReplacedCopy(json_string, "1970-01-01T00:00:00Z", "1970-01-01T00:00:99Z");
  VerifyJsonStringDecodeFails(json_copy);

  // To verify this way of testing actually works
  json_copy = ReplacedCopy(json_string, "\"1970-01-01T00:00:00Z\"",
                           R"({"seconds": "0", "nanos": 0})");
  VerifyJsonStringDecodes(json_copy);

  // Actual test
  json_copy = ReplacedCopy(json_string, "\"1970-01-01T00:00:00Z\"",
                           R"({"seconds": "A", "nanos": 0})");
  VerifyJsonStringDecodeFails(json_copy);
}

TEST_F(BundleSerializerTest, DecodesGeoPointValues) {
  google::type::LatLng g1;
  g1.set_latitude(1.23);
  google::type::LatLng g2;
  g2.set_longitude(-54.32);
  google::type::LatLng g3;
  g3.set_longitude(-54);
  g3.set_longitude(9.2);
  for (const auto& v : {g1, g2, g3}) {
    ProtoValue value;
    *value.mutable_geo_point_value() = v;

    VerifyFieldValueRoundtrip(value);
  }
}

TEST_F(BundleSerializerTest, DecodesBlobValues) {
  ProtoValue value;
  uint8_t array[]{0, 1, 2, 3};
  value.set_bytes_value(array, 4);

  VerifyFieldValueRoundtrip(value);
}

TEST_F(BundleSerializerTest, DecodesInvalidBlobValuesFails) {
  ProtoValue value;
  uint8_t array[]{0, 1, 2, 3};  // Base64: AAECAw==
  value.set_bytes_value(array, 4);
  ProtoDocument document = TestDocument(value);

  std::string json_string;
  MessageToJsonString(document, &json_string);

  auto json_copy = ReplacedCopy(json_string, "AAECAw==", "\\o//");
  VerifyJsonStringDecodeFails(json_copy);
}

TEST_F(BundleSerializerTest, DecodesReferenceValues) {
  ProtoValue value;
  value.set_reference_value(FullPath("bundle/test_doc"));
  VerifyFieldValueRoundtrip(value);
}

TEST_F(BundleSerializerTest, DecodesArrayValues) {
  ProtoValue elem1;
  elem1.set_string_value("testing");
  ProtoValue elem2;
  elem2.set_integer_value(1234L);
  ProtoValue elem3;
  elem3.set_null_value(google::protobuf::NULL_VALUE);

  ProtoValue value;
  value.mutable_array_value()->mutable_values()->Add(std::move(elem1));
  value.mutable_array_value()->mutable_values()->Add(std::move(elem2));
  value.mutable_array_value()->mutable_values()->Add(std::move(elem3));

  VerifyFieldValueRoundtrip(value);
}

TEST_F(BundleSerializerTest, DecodesNestedObjectValues) {
  ProtoValue b;
  b.set_boolean_value(true);
  ProtoValue d;
  d.set_double_value(std::numeric_limits<double>::max());
  ProtoValue i;
  i.set_integer_value(1);
  ProtoValue n;
  n.set_null_value(google::protobuf::NULL_VALUE);
  ProtoValue s;
  s.set_string_value("foo");

  ProtoValue i_in_array;
  i_in_array.set_integer_value(2);
  ProtoValue s_in_array;
  s_in_array.set_string_value("bar");
  ProtoValue b_in_map_in_array;
  b_in_map_in_array.set_boolean_value(false);
  ProtoValue m_in_array;
  m_in_array.mutable_map_value()->mutable_fields()->insert(
      {"b", b_in_map_in_array});
  ProtoValue array;
  array.mutable_array_value()->mutable_values()->Add(std::move(i_in_array));
  array.mutable_array_value()->mutable_values()->Add(std::move(s_in_array));
  array.mutable_array_value()->mutable_values()->Add(
      std::move(b_in_map_in_array));

  ProtoValue i_in_nested_in_object;
  i_in_nested_in_object.set_integer_value(numeric_limits<int64_t>::min());
  ProtoValue nested_in_object;
  nested_in_object.mutable_map_value()->mutable_fields()->insert(
      {"e", i_in_nested_in_object});
  ProtoValue d_in_object;
  d_in_object.set_integer_value(100);
  ProtoValue object;
  object.mutable_map_value()->mutable_fields()->insert({"d", d_in_object});
  object.mutable_map_value()->mutable_fields()->insert(
      {"nested", nested_in_object});

  ProtoValue value;
  auto* fields = value.mutable_map_value()->mutable_fields();
  fields->insert({"b", b});
  fields->insert({"d", d});
  fields->insert({"i", i});
  fields->insert({"n", n});
  fields->insert({"s", s});
  fields->insert({"a", array});
  fields->insert({"o", object});

  VerifyFieldValueRoundtrip(value);
}

// MARK: Tests for Query decoding

TEST_F(BundleSerializerTest, DecodesCollectionQuery) {
  core::Query original = testutil::Query("bundles/docs/colls");
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodeQueriesFromOtherProjectsFails) {
  std::string json_string = NamedQueryJsonString(testutil::Query("colls"));
  {
    auto json_copy = ReplacedCopy(json_string, "/p/", "/p_diff/");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }

  {
    auto json_copy = ReplacedCopy(json_string, "/default/", "/default_diff/");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }
}

TEST_F(BundleSerializerTest, DecodesCollectionGroupQuery) {
  core::Query original = testutil::CollectionGroupQuery("bundles/docs/colls");
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesNullFilter) {
  core::Query original =
      testutil::Query("colls").AddingFilter(Filter("f1", "==", nullptr));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesNotNullFilter) {
  core::Query original = testutil::CollectionGroupQuery("colls").AddingFilter(
      Filter("f1", "!=", nullptr));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesNanFilter) {
  core::Query original =
      testutil::Query("colls").AddingFilter(Filter("f1", "==", NAN));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesNotNanFilter) {
  core::Query original = testutil::CollectionGroupQuery("colls").AddingFilter(
      Filter("f1", "!=", NAN));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodeInvalidUnaryOperatorFails) {
  std::string json_string = NamedQueryJsonString(
      testutil::Query("colls").AddingFilter(Filter("f1", "==", nullptr)));
  {
    auto json_copy = ReplacedCopy(json_string, "IS_NULL", "Is_Null");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }

  {
    auto json_copy =
        ReplacedCopy(json_string, "\"unaryFilter\"", "\"fieldFilter\"");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }

  {
    auto json_copy = ReplacedCopy(json_string, "\"op\"", "\"Op\"");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }

  {
    auto json_copy = ReplacedCopy(json_string, "\"fieldPath\"", "\"\"");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }
}

TEST_F(BundleSerializerTest, DecodesLessThanFilter) {
  core::Query original =
      testutil::Query("colls").AddingFilter(Filter("f1", "<", 9999));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesLessThanOrEqualFilter) {
  core::Query original = testutil::CollectionGroupQuery("colls").AddingFilter(
      Filter("f1", "<=", "9999"));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesGreaterThanFilter) {
  core::Query original =
      testutil::Query("colls").AddingFilter(Filter("f1", ">", 9999.0));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesGreaterThanOrEqualFilter) {
  core::Query original = testutil::CollectionGroupQuery("colls").AddingFilter(
      Filter("f1", ">=", -9999));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesEqualFilter) {
  core::Query original =
      testutil::Query("colls").AddingFilter(Filter("f1", "==", "XXX"));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesNotEqualFilter) {
  core::Query original = testutil::CollectionGroupQuery("colls").AddingFilter(
      Filter("f1", "!=", false));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesArrayContainsFilter) {
  core::Query original =
      testutil::Query("colls").AddingFilter(Filter("f1", "array-contains", 3));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesInFilter) {
  core::Query original = testutil::CollectionGroupQuery("colls").AddingFilter(
      Filter("f1", "in", Value(Array("f", "h"))));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesArrayContainsAnyFilter) {
  core::Query original = testutil::Query("colls").AddingFilter(
      Filter("f1", "array-contains-any", Array(Map("a", Array(42)))));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesNotInFilter) {
  core::Query original = testutil::CollectionGroupQuery("colls").AddingFilter(
      Filter("f1", "not-in", Array(1, "2", 3.0)));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodeInvalidFieldFilterOperatorFails) {
  std::string json_string =
      NamedQueryJsonString(testutil::Query("colls").AddingFilter(
          Filter("f1", "not-in", Array(1, "2", 3.0))));

  {
    auto json_copy = ReplacedCopy(json_string, "NOT_IN", "NO_IN");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }

  {
    auto json_copy = ReplacedCopy(json_string, "\"op\"", "\"Op\"");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }

  {
    auto json_copy = ReplacedCopy(json_string, "\"fieldPath\"", "\"\"");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }
}

TEST_F(BundleSerializerTest, DecodesCompositeFilter) {
  core::Query original = testutil::Query("colls")
                             .AddingFilter(Filter("f1", "==", nullptr))
                             .AddingFilter(Filter("f2", "==", true))
                             .AddingFilter(Filter("f3", "==", 50.3));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesCompositeNotNullFilter) {
  core::Query original =
      testutil::Query("colls")
          .AddingFilter(Filter("f1", "not-in", Array(1, "2", 3.0)))
          .AddingFilter(Filter("f1", "!=", false))
          .AddingFilter(Filter("f1", "<=", 1000.0));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesCompositeNullFilter) {
  core::Query original = testutil::Query("colls")
                             .AddingFilter(Filter("f1", "==", nullptr))
                             .AddingFilter(Filter("f2", "==", nullptr));
  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodeInvalidCompositeFilterOperatorFails) {
  std::string json_string = NamedQueryJsonString(
      testutil::Query("colls")
          .AddingFilter(Filter("f1", "not-in", Array(1, "2", 3.0)))
          .AddingFilter(Filter("f1", "!=", false))
          .AddingFilter(Filter("f1", "<=", 1000.0)));

  {
    auto json_copy = ReplacedCopy(json_string, "\"AND\"", "\"OR\"");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }

  {
    auto json_copy =
        ReplacedCopy(json_string, "\"compositeFilter\"", "\"unaryFilter\"");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }

  {
    auto json_copy =
        ReplacedCopy(json_string, "\"LESS_THAN_OR_EQUAL\"", "\"garbage\"");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }

  {
    auto json_copy = ReplacedCopy(json_string, "\"fieldPath\"", "\"whoops\"");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }
}

TEST_F(BundleSerializerTest, DecodesOrderBys) {
  core::Query original = testutil::Query("colls")
                             .AddingOrderBy(OrderBy("f1"))
                             .AddingOrderBy(OrderBy("f2", "asc"))
                             .AddingOrderBy(OrderBy("f3", "desc"));

  VerifyNamedQueryRoundtrip(original);
}

// By default, the queries used for testing in this file always have default
// OrderBy ("__name__") generated. We need to explicitly remove that for this
// test.
TEST_F(BundleSerializerTest, DecodeMissingOrderBysWorks) {
  // This is `NamedQueryToJson(testutil::Query("bundles/docs/colls"))` with
  // orderBy field manually removed.
  auto json_string = R"|(
{
  "name":"query-1",
  "bundledQuery":{
    "parent":"projects/p/databases/default/documents/bundles/docs",
    "structuredQuery":{"from":[{"collectionId":"colls"}]}
  },
  "readTime":"2021-03-17T14:04:20.166729927Z"
}
)|";
  JsonReader reader;
  auto named_query =
      bundle_serializer.DecodeNamedQuery(reader, Parse(json_string));

  EXPECT_OK(reader.status());
  EXPECT_EQ(named_query.query_name(), "query-1");

  // Reconstruct a core::Query from the deserialized target, this is how
  // eventually the named query is used.
  const Target& target = named_query.bundled_query().target();
  Query query(target.path(), target.collection_group(), target.filters(),
              target.order_bys(), target.limit(),
              named_query.bundled_query().limit_type(), target.start_at(),
              target.end_at());
  EXPECT_EQ(query.ToTarget(), testutil::Query("bundles/docs/colls").ToTarget());
}

TEST_F(BundleSerializerTest, DecodeInvalidOrderBysFails) {
  std::string json_string =
      NamedQueryJsonString(testutil::Query("colls")
                               .AddingOrderBy(OrderBy("f1"))
                               .AddingOrderBy(OrderBy("f2", "asc"))
                               .AddingOrderBy(OrderBy("f3", "desc")));

  {
    auto json_copy = ReplacedCopy(json_string, "\"ASCENDING\"", "\"Asc\"");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }

  {
    auto json_copy = ReplacedCopy(json_string, "\"fieldPath\"", "\"whoops\"");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }
}

TEST_F(BundleSerializerTest, DecodesLimitQueries) {
  core::Query original = testutil::Query("colls").WithLimitToFirst(4);

  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesLimitToLastQueries) {
  core::Query original = testutil::Query("colls")
                             .AddingOrderBy(OrderBy("f1", "asc"))
                             .WithLimitToLast(4);

  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodeLimitEncodedAsObject) {
  core::Query original = testutil::Query("colls")
                             .AddingOrderBy(OrderBy("f1", "asc"))
                             .WithLimitToLast(4);
  std::string json_string = NamedQueryJsonString(original);
  auto json_copy =
      ReplacedCopy(json_string, "\"limit\":4", R"("limit":{"value": 4})");
  JsonReader reader;
  auto decoded = bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
  EXPECT_OK(reader.status());
  EXPECT_EQ(decoded.bundled_query().target(), original.ToTarget());
}

TEST_F(BundleSerializerTest, DecodeInvalidLimitQueriesFails) {
  std::string json_string =
      NamedQueryJsonString(testutil::Query("colls")
                               .AddingOrderBy(OrderBy("f1", "asc"))
                               .WithLimitToLast(4));

  {
    auto json_copy = ReplacedCopy(json_string, "\"limit\":4", "\"limit\":true");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }

  {
    auto json_copy = ReplacedCopy(json_string, "\"LAST\"", "\"LLL\"");
    JsonReader reader;
    bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }
}

TEST_F(BundleSerializerTest, DecodesStartAtCursor) {
  core::Query original =
      testutil::Query("colls")
          .AddingOrderBy(OrderBy("f1", "asc"))
          .StartingAt(core::Bound::FromValue(Array("f1", 1000),
                                             /* inclusive= */ true));

  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodesEndAtCursor) {
  core::Query original =
      testutil::Query("colls")
          .AddingOrderBy(OrderBy("f1", "desc"))
          .EndingAt(core::Bound::FromValue(Array("f1", "1000"),
                                           /* inclusive= */ false));

  VerifyNamedQueryRoundtrip(original);
}

TEST_F(BundleSerializerTest, DecodeInvalidCursorQueriesFails) {
  std::string json_string = NamedQueryJsonString(
      testutil::Query("colls")
          .AddingOrderBy(OrderBy("f1", "desc"))
          .EndingAt(core::Bound::FromValue(Array("f1", "1000"),
                                           /* is_before= */ false)));
  auto json_copy = ReplacedCopy(json_string, "\"1000\"", "[]");
  auto reader = JsonReader();
  bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
  EXPECT_NOT_OK(reader.status());
}

TEST_F(BundleSerializerTest, DecodeOffsetFails) {
  std::string json_string = NamedQueryJsonString(testutil::Query("colls"));
  auto json_copy =
      ReplacedCopy(json_string, R"("from":[{"collectionId":"colls"}])",
                   R"("from":[{"collectionId":"colls"}],"offset":5)");

  JsonReader reader;
  bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
  EXPECT_NOT_OK(reader.status());
}

TEST_F(BundleSerializerTest, DecodeSelectFails) {
  std::string json_string = NamedQueryJsonString(testutil::Query("colls"));
  auto json_copy =
      ReplacedCopy(json_string, R"("from":[{"collectionId":"colls"}])",
                   R"("from":[{"collectionId":"colls"}],"select":[])");

  JsonReader reader;
  NamedQuery actual =
      bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
  EXPECT_NOT_OK(reader.status());
}

TEST_F(BundleSerializerTest, DecodeEmptyFromFails) {
  std::string json_string = NamedQueryJsonString(testutil::Query("colls"));
  auto json_copy = ReplacedCopy(
      json_string, R"("from":[{"collectionId":"colls"}])", R"("from":[])");

  JsonReader reader;
  NamedQuery actual =
      bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
  EXPECT_NOT_OK(reader.status());
}

TEST_F(BundleSerializerTest, DecodeMultipleFromFails) {
  std::string json_string = NamedQueryJsonString(testutil::Query("colls"));
  auto json_copy = ReplacedCopy(
      json_string, R"("from":[{"collectionId":"colls"}])",
      R"("from":[{"collectionId":"colls"},{"collectionId":"colls_new"}])");

  JsonReader reader;
  NamedQuery actual =
      bundle_serializer.DecodeNamedQuery(reader, Parse(json_copy));
  EXPECT_NOT_OK(reader.status());
}

// MARK: Tests for BundledDocumentMetadata decoding

TEST_F(BundleSerializerTest, DecodesBundledDocumentMetadata) {
  ProtoBundledDocumentMetadata metadata;
  metadata.set_name(FullPath("bundle/doc-1"));
  metadata.set_exists(true);
  google::protobuf::Timestamp t1;
  t1.set_seconds(0);
  t1.set_nanos(0);
  *metadata.mutable_read_time() = t1;
  metadata.mutable_queries()->Add("q1");
  metadata.mutable_queries()->Add("q2");
  std::string json_string;
  MessageToJsonString(metadata, &json_string);

  JsonReader reader;
  bundle::BundledDocumentMetadata actual =
      bundle_serializer.DecodeDocumentMetadata(reader, Parse(json_string));

  EXPECT_OK(reader.status());
  EXPECT_EQ(metadata.exists(), actual.exists());
  EXPECT_EQ(metadata.read_time().seconds(),
            actual.read_time().timestamp().seconds());
  EXPECT_EQ(metadata.read_time().nanos(),
            actual.read_time().timestamp().nanoseconds());

  EXPECT_EQ(metadata.name(), FullPath(actual.key().ToString()));
  std::vector<std::string> original_queries(metadata.queries().begin(),
                                            metadata.queries().end());
  EXPECT_EQ(original_queries, actual.queries());
}

TEST_F(BundleSerializerTest, DecodeInvalidBundledDocumentMetadataFails) {
  ProtoBundledDocumentMetadata metadata;
  metadata.set_name(FullPath("bundle/doc-1"));
  metadata.set_exists(true);
  google::protobuf::Timestamp t1;
  t1.set_seconds(0);
  t1.set_nanos(0);
  *metadata.mutable_read_time() = t1;
  metadata.mutable_queries()->Add("q1");
  std::string json_string;
  MessageToJsonString(metadata, &json_string);

  {
    auto json_copy = ReplacedCopy(json_string, "true", "invalid");
    JsonReader reader;
    bundle_serializer.DecodeDocumentMetadata(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }

  {
    auto json_copy = ReplacedCopy(json_string, R"(["q1"])", R"("q1")");
    JsonReader reader;
    bundle_serializer.DecodeDocumentMetadata(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }

  {
    auto json_copy =
        ReplacedCopy(json_string, R"("readTime")", R"("WriteTime")");
    JsonReader reader;
    bundle_serializer.DecodeDocumentMetadata(reader, Parse(json_copy));
    EXPECT_NOT_OK(reader.status());
  }
}

TEST_F(BundleSerializerTest, DecodeTargetWithoutImplicitOrderByOnName) {
  std::string json(
      R"({"name":"myNamedQuery",
"bundledQuery":{"parent":"projects/p/databases/default/documents",
"structuredQuery":{"from":[{"collectionId":"foo"}],
"limit":{"value":10}},"limitType":"FIRST"},
"readTime":{"seconds":"1679674432","nanos":579934000}})");
  JsonReader reader;
  auto named_query = bundle_serializer.DecodeNamedQuery(reader, Parse(json));
  EXPECT_OK(reader.status());
  EXPECT_EQ(testutil::Query("foo").WithLimitToFirst(10).ToTarget(),
            named_query.bundled_query().target());
  EXPECT_EQ(core::LimitType::First, named_query.bundled_query().limit_type());
}

TEST_F(BundleSerializerTest,
       DecodeLimitToLastTargetWithoutImplicitOrderByOnName) {
  std::string json(
      R"({"name":"myNamedQuery",
"bundledQuery":{"parent":"projects/p/databases/default/documents",
"structuredQuery":{"from":[{"collectionId":"foo"}],
"limit":{"value":10}},"limitType":"LAST"},
"readTime":{"seconds":"1679674432","nanos":579934000}})");
  JsonReader reader;
  auto named_query = bundle_serializer.DecodeNamedQuery(reader, Parse(json));
  EXPECT_OK(reader.status());
  // Note `WithLimitToFirst(10)` is expected.
  EXPECT_EQ(testutil::Query("foo").WithLimitToFirst(10).ToTarget(),
            named_query.bundled_query().target());
  EXPECT_EQ(core::LimitType::Last, named_query.bundled_query().limit_type());
}

}  //  namespace
}  //  namespace bundle
}  //  namespace firestore
}  //  namespace firebase
