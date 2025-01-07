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

#include "Firestore/core/src/remote/serializer.h"

#include <pb.h>
#include <pb_encode.h>

#include <functional>
#include <limits>
#include <utility>
#include <vector>

#include "Firestore/Protos/cpp/google/firestore/v1/document.pb.h"
#include "Firestore/Protos/cpp/google/firestore/v1/firestore.pb.h"
#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/include/firebase/firestore/geo_point.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/core/bound.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/filter.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/local/target_data.h"
#include "Firestore/core/src/model/delete_mutation.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/model/verify_mutation.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/reader.h"
#include "Firestore/core/src/nanopb/writer.h"
#include "Firestore/core/src/timestamp_internal.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/test/unit/nanopb/nanopb_testing.h"
#include "Firestore/core/test/unit/testutil/status_testing.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/strings/string_view.h"
#include "absl/types/optional.h"
#include "google/protobuf/stubs/common.h"
#include "google/protobuf/util/message_differencer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

namespace {

namespace v1 = google::firestore::v1;
using core::Bound;
using google::protobuf::Int32Value;
using google::protobuf::util::MessageDifferencer;
using local::QueryPurpose;
using local::TargetData;
using model::ArrayTransform;
using model::DatabaseId;
using model::DeleteMutation;
using model::DocumentKey;
using model::FieldPath;
using model::GetTypeOrder;
using model::MutableDocument;
using model::Mutation;
using model::MutationResult;
using model::ObjectValue;
using model::PatchMutation;
using model::Precondition;
using model::RefValue;
using model::ServerTimestampTransform;
using model::SetMutation;
using model::SnapshotVersion;
using model::SortFields;
using model::TransformOperation;
using model::TypeOrder;
using model::VerifyMutation;
using nanopb::ByteString;
using nanopb::ByteStringWriter;
using nanopb::FreeNanopbMessage;
using nanopb::MakeSharedMessage;
using nanopb::Message;
using nanopb::ProtobufParse;
using nanopb::ProtobufSerialize;
using nanopb::StringReader;
using nanopb::Writer;
using remote::Serializer;
using testutil::AndFilters;
using testutil::Array;
using testutil::Bytes;
using testutil::DeletedDoc;
using testutil::Doc;
using testutil::Filter;
using testutil::Key;
using testutil::Map;
using testutil::OrderBy;
using testutil::OrFilters;
using testutil::Query;
using testutil::Ref;
using testutil::Value;
using testutil::Version;
using util::Status;
using util::StatusOr;

const char* const kProjectId = "p";
const char* const kDatabaseId = "d";

// These helper functions are just shorter aliases to reduce verbosity.
ByteString ToBytes(const std::string& str) {
  return ByteString::Take(Serializer::EncodeString(str));
}

std::string FromBytes(pb_bytes_array_t*&& ptr) {
  auto byte_string = ByteString::Take(ptr);
  return Serializer::DecodeString(byte_string.get());
}

TargetData CreateTargetData(core::Query query) {
  return TargetData(query.ToTarget(), 1, 0, QueryPurpose::Listen);
}

TargetData CreateTargetData(absl::string_view str) {
  return CreateTargetData(Query(str));
}

// Returns the full key path, including the database name, as a string.
std::string ResourceName(const std::string& key) {
  std::string prefix = "projects/p/databases/d/documents";
  if (key.empty()) {
    return prefix;
  }
  return prefix + "/" + key;
}

}  // namespace

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
  SerializerTest() : serializer(DatabaseId(kProjectId, kDatabaseId)) {
    msg_diff.ReportDifferencesToString(&message_differences);
  }

  Serializer serializer;

  template <typename... Args>
  void ExpectRoundTrip(Args&&... args) {
    // First, serialize model with our (nanopb based) serializer, then
    // deserialize the resulting bytes with libprotobuf and ensure the result is
    // the same as the expected proto.
    ExpectSerializationRoundTrip(std::forward<Args>(args)...);

    // Next, serialize proto with libprotobuf, then deserialize the resulting
    // bytes with our (nanopb based) deserializer and ensure the result is the
    // same as the expected model.
    ExpectDeserializationRoundTrip(std::forward<Args>(args)...);
  }

  void ExpectNoDocumentDeserializationRoundTrip(
      const DocumentKey& key,
      const SnapshotVersion& read_time,
      const v1::BatchGetDocumentsResponse& proto) {
    ExpectDeserializationRoundTrip(key, absl::nullopt, read_time, proto);
  }

  void ExpectDeserializationRoundTrip(const WatchChange& model,
                                      const v1::ListenResponse& proto) {
    auto actual_model = Decode<google_firestore_v1_ListenResponse>(
        std::mem_fn(&Serializer::DecodeWatchChange), proto);

    EXPECT_EQ(model, *actual_model);
  }

  void ExpectDeserializationRoundTrip(const MutationResult& model,
                                      const v1::WriteResult& proto,
                                      const SnapshotVersion& commit_version) {
    auto actual_model = Decode<google_firestore_v1_WriteResult>(
        std::mem_fn(&Serializer::DecodeMutationResult), proto, commit_version);

    EXPECT_EQ(model, actual_model);
  }

  void ExpectDeserializationRoundTrip(const SnapshotVersion& model,
                                      const v1::ListenResponse& proto) {
    auto actual_model = Decode<google_firestore_v1_ListenResponse>(
        std::mem_fn(&Serializer::DecodeVersionFromListenResponse), proto);

    EXPECT_EQ(model, actual_model);
  }

  /**
   * Ensures that decoding fails with the given status.
   *
   * @param status the expected (failed) status. Only the code() is verified.
   */
  void ExpectFailedStatusDuringFieldValueDecode(
      Status status, const std::vector<uint8_t>& bytes) {
    StringReader reader(bytes);

    auto message = Message<google_firestore_v1_Value>::TryParse(&reader);

    ASSERT_NOT_OK(reader.status());
    EXPECT_EQ(status.code(), reader.status().code());
  }

  void ExpectFailedStatusDuringMaybeDocumentDecode(Status status,
                                                   const ByteString& bytes) {
    StringReader reader(bytes);

    auto message =
        Message<google_firestore_v1_BatchGetDocumentsResponse>::TryParse(
            &reader);
    serializer.DecodeMaybeDocument(reader.context(), *message);

    ASSERT_NOT_OK(reader.status());
    EXPECT_EQ(status.code(), reader.status().code());
  }

  ByteString EncodeFieldValue(const Message<google_firestore_v1_Value>& fv) {
    ByteStringWriter writer;
    writer.Write(google_firestore_v1_Value_fields, fv.get());
    return writer.Release();
  }

  ByteString EncodeDocument(const DocumentKey& key, const ObjectValue& value) {
    ByteStringWriter writer;
    google_firestore_v1_Document proto = serializer.EncodeDocument(key, value);
    writer.Write(google_firestore_v1_Document_fields, &proto);
    FreeNanopbMessage(google_firestore_v1_Document_fields, &proto);
    return writer.Release();
  }

  void Mutate(pb_bytes_array_t* bytes,
              size_t offset,
              uint8_t expected_initial_value,
              uint8_t new_value) {
    ASSERT_EQ(bytes->bytes[offset], expected_initial_value);
    bytes->bytes[offset] = new_value;
  }

  void Mutate(uint8_t* byte,
              uint8_t expected_initial_value,
              uint8_t new_value) {
    ASSERT_EQ(*byte, expected_initial_value);
    *byte = new_value;
  }

  v1::Value ValueProto(std::nullptr_t) {
    ByteString bytes = EncodeFieldValue(Value(nullptr));
    return ProtobufParse<v1::Value>(bytes);
  }

  v1::Value ValueProto(bool b) {
    ByteString bytes = EncodeFieldValue(Value(b));
    return ProtobufParse<v1::Value>(bytes);
  }

  v1::Value ValueProto(int64_t i) {
    ByteString bytes = EncodeFieldValue(Value(i));
    return ProtobufParse<v1::Value>(bytes);
  }

  v1::Value ValueProto(double d) {
    ByteString bytes = EncodeFieldValue(Value(d));
    return ProtobufParse<v1::Value>(bytes);
  }

  // int64_t and double are equally good overloads for integer literals so this
  // avoids ambiguity
  v1::Value ValueProto(int i) {
    return ValueProto(static_cast<int64_t>(i));
  }

  v1::Value ValueProto(const char* s) {
    return ValueProto(std::string(s));
  }

  v1::Value ValueProto(const std::string& s) {
    ByteString bytes = EncodeFieldValue(Value(s));
    return ProtobufParse<v1::Value>(bytes);
  }

  v1::Value ValueProto(const Timestamp& ts) {
    ByteString bytes = EncodeFieldValue(Value(ts));
    return ProtobufParse<v1::Value>(bytes);
  }

  v1::Value ValueProto(const ByteString& blob) {
    ByteString bytes = EncodeFieldValue(Value(blob));
    return ProtobufParse<v1::Value>(bytes);
  }

  v1::Value ValueProto(const DatabaseId& database_id,
                       const DocumentKey& document_key) {
    ByteString bytes = EncodeFieldValue(RefValue(database_id, document_key));
    return ProtobufParse<v1::Value>(bytes);
  }

  v1::Value ValueProto(const GeoPoint& geo_point) {
    ByteString bytes = EncodeFieldValue(Value(geo_point));
    return ProtobufParse<v1::Value>(bytes);
  }

  v1::Value ValueProto(const Message<google_firestore_v1_Value>& value) {
    ByteString bytes = EncodeFieldValue(value);
    return ProtobufParse<v1::Value>(bytes);
  }

  v1::Value ValueProto(const Message<google_firestore_v1_ArrayValue>& value) {
    Message<google_firestore_v1_Value> message;
    message->which_value_type = google_firestore_v1_Value_array_value_tag;
    message->array_value = *value;
    ByteString bytes = EncodeFieldValue(message);
    message.release();
    return ProtobufParse<v1::Value>(bytes);
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
      v1::BatchGetDocumentsResponse* proto) {
    proto->set_transaction("random bytes");

    // TODO(rsgowman): This method currently assumes that this is a 'found'
    // document. We (probably) will need to adjust this to work with NoDocuments
    // too.
    v1::Document* doc_proto = proto->mutable_found();
    google::protobuf::Timestamp* create_time_proto =
        doc_proto->mutable_create_time();
    create_time_proto->set_seconds(8765);
    create_time_proto->set_nanos(4321);
  }

  void ExpectUnaryOperator(std::string op_str,
                           Message<google_firestore_v1_Value> value,
                           v1::StructuredQuery::UnaryFilter::Operator op) {
    core::Query q =
        Query("docs").AddingFilter(Filter("prop", op_str, std::move(value)));
    TargetData model = CreateTargetData(std::move(q));

    v1::Target proto;
    proto.mutable_query()->set_parent(ResourceName(""));
    proto.set_target_id(1);

    v1::StructuredQuery::CollectionSelector from;
    from.set_collection_id("docs");
    *proto.mutable_query()->mutable_structured_query()->add_from() =
        std::move(from);

    // Add extra ORDER_BY field for '!=' since it is an inequality.
    if (op_str == "!=") {
      v1::StructuredQuery::Order order1;
      order1.mutable_field()->set_field_path("prop");
      order1.set_direction(v1::StructuredQuery::ASCENDING);
      *proto.mutable_query()->mutable_structured_query()->add_order_by() =
          std::move(order1);
    }

    v1::StructuredQuery::Order order;
    order.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
    order.set_direction(v1::StructuredQuery::ASCENDING);
    *proto.mutable_query()->mutable_structured_query()->add_order_by() =
        std::move(order);

    v1::StructuredQuery::UnaryFilter& filter = *proto.mutable_query()
                                                    ->mutable_structured_query()
                                                    ->mutable_where()
                                                    ->mutable_unary_filter();

    filter.mutable_field()->set_field_path("prop");
    filter.set_op(op);

    ExpectRoundTrip(model, proto);
  }

 private:
  void ExpectSerializationRoundTrip(
      const Message<google_firestore_v1_Value>& model,
      const v1::Value& proto,
      TypeOrder type) {
    EXPECT_EQ(type, GetTypeOrder(*model));
    ByteString bytes = EncodeFieldValue(std::move(model));
    auto actual_proto = ProtobufParse<v1::Value>(bytes);

    EXPECT_TRUE(msg_diff.Compare(proto, actual_proto)) << message_differences;
  }

  void ExpectDeserializationRoundTrip(
      const Message<google_firestore_v1_Value>& model,
      const v1::Value& proto,
      TypeOrder type) {
    ByteString bytes = ProtobufSerialize(proto);
    StringReader reader(bytes);

    auto message = Message<google_firestore_v1_Value>::TryParse(&reader);
    EXPECT_OK(reader.status());
    EXPECT_EQ(type, GetTypeOrder(*message));
    // libprotobuf does not retain map ordering. We need to restore the
    // ordering.
    Message<google_firestore_v1_Value> expected = model::DeepClone(*model);
    SortFields(*expected);
    SortFields(*message);
    EXPECT_EQ(*expected, *message);
  }

  void ExpectSerializationRoundTrip(
      const DocumentKey& key,
      const ObjectValue& value,
      const SnapshotVersion& update_time,
      const v1::BatchGetDocumentsResponse& proto) {
    ByteString bytes = EncodeDocument(key, value);
    auto actual_proto = ProtobufParse<v1::Document>(bytes);

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
    v1::BatchGetDocumentsResponse proto_copy{proto};
    proto_copy.mutable_found()->clear_update_time();
    proto_copy.mutable_found()->clear_create_time();

    EXPECT_TRUE(msg_diff.Compare(proto_copy.found(), actual_proto))
        << message_differences;
  }

  void ExpectDeserializationRoundTrip(
      const DocumentKey& key,
      const absl::optional<ObjectValue> value,
      const SnapshotVersion& version,  // either update_time or read_time
      const v1::BatchGetDocumentsResponse& proto) {
    ByteString bytes = ProtobufSerialize(proto);
    StringReader reader(bytes);

    auto message =
        Message<google_firestore_v1_BatchGetDocumentsResponse>::TryParse(
            &reader);

    MutableDocument actual_model =
        serializer.DecodeMaybeDocument(reader.context(), *message);

    EXPECT_EQ(key, actual_model.key());
    EXPECT_EQ(version, actual_model.version());
    if (actual_model.is_found_document()) {
      EXPECT_EQ(value, actual_model.data());
    } else if (actual_model.is_no_document()) {
      EXPECT_EQ(ObjectValue{}, actual_model.data());
    } else if (actual_model.is_unknown_document()) {
      // TODO(rsgowman): implement.
      // In particular, since this statement isn't hit, it implies a missing
      // test for UnknownDocument. However, we'll defer that until after
      // nanopb-master is merged to master.
      abort();
    } else {
      FAIL() << "We somehow created an invalid model object";
    }
  }

  void ExpectSerializationRoundTrip(const TargetData& model,
                                    const v1::Target& proto) {
    ByteString bytes = Encode(google_firestore_v1_Target_fields,
                              serializer.EncodeTarget(model));
    auto actual_proto = ProtobufParse<v1::Target>(bytes);

    EXPECT_TRUE(msg_diff.Compare(proto, actual_proto)) << message_differences;
  }

  void ExpectDeserializationRoundTrip(const TargetData& model,
                                      const v1::Target& proto) {
    core::Target actual_model;
    if (proto.has_documents()) {
      actual_model = Decode<google_firestore_v1_Target_DocumentsTarget>(
          std::mem_fn(&Serializer::DecodeDocumentsTarget), proto.documents());

    } else {
      actual_model = Decode<google_firestore_v1_Target_QueryTarget>(
          std::mem_fn(&Serializer::DecodeQueryTarget), proto.query());
    }

    EXPECT_EQ(model.target(), actual_model);
  }

  void ExpectSerializationRoundTrip(const Mutation& model,
                                    const v1::Write& proto) {
    ByteString bytes = Encode(google_firestore_v1_Write_fields,
                              serializer.EncodeMutation(model));
    auto actual_proto = ProtobufParse<v1::Write>(bytes);

    EXPECT_TRUE(msg_diff.Compare(proto, actual_proto)) << message_differences;
  }

  void ExpectDeserializationRoundTrip(const Mutation& model,
                                      const v1::Write& proto) {
    Mutation actual_model = Decode<google_firestore_v1_Write>(
        std::mem_fn(&Serializer::DecodeMutation), proto);

    EXPECT_EQ(model, actual_model);
  }

  void ExpectSerializationRoundTrip(const core::Filter& model,
                                    const v1::StructuredQuery::Filter& proto) {
    ByteString bytes = Encode(google_firestore_v1_StructuredQuery_Filter_fields,
                              serializer.EncodeFilters({model}));
    auto actual_proto = ProtobufParse<v1::StructuredQuery::Filter>(bytes);

    EXPECT_TRUE(msg_diff.Compare(proto, actual_proto)) << message_differences;
  }

  void ExpectDeserializationRoundTrip(
      const core::Filter& model, const v1::StructuredQuery::Filter& proto) {
    std::vector<core::Filter> actual_model =
        Decode<google_firestore_v1_StructuredQuery_Filter>(
            std::mem_fn(&Serializer::DecodeFilters), proto);

    EXPECT_EQ(std::vector<core::Filter>{model}, actual_model);
  }

  template <typename T>
  ByteString Encode(const pb_field_t* fields, T&& nanopb_proto) {
    ByteStringWriter writer;
    writer.Write(fields, &nanopb_proto);
    FreeNanopbMessage(fields, &nanopb_proto);
    return writer.Release();
  }

  template <typename T, typename F, typename P, typename... Args>
  auto Decode(F decode_func, const P& proto, const Args&... args) ->
      typename F::result_type {
    ByteString bytes = ProtobufSerialize(proto);
    StringReader reader{bytes};

    auto message = Message<T>::TryParse(&reader);
    auto model = decode_func(serializer, reader.context(), *message, args...);

    EXPECT_OK(reader.status());
    return model;
  }

  std::string message_differences;
  MessageDifferencer msg_diff;
};

TEST_F(SerializerTest, EncodesNull) {
  Message<google_firestore_v1_Value> model = Value(nullptr);
  ExpectRoundTrip(model, ValueProto(nullptr), TypeOrder::kNull);
}

TEST_F(SerializerTest, EncodesBool) {
  for (bool bool_value : {true, false}) {
    Message<google_firestore_v1_Value> model = Value(bool_value);
    ExpectRoundTrip(model, ValueProto(bool_value), TypeOrder::kBoolean);
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
    Message<google_firestore_v1_Value> model = Value(int_value);
    ExpectRoundTrip(model, ValueProto(int_value), TypeOrder::kNumber);
  }
}

TEST_F(SerializerTest, EncodesDoubles) {
  // Not technically required at all. But if we run into a platform where this
  // is false, then we'll have to eliminate a few of our test cases in this
  // test.
  static_assert(std::numeric_limits<double>::is_iec559,
                "IEC559/IEEE764 floating point required");

  std::vector<double> cases{
      -std::numeric_limits<double>::infinity(),
      std::numeric_limits<double>::lowest(),
      std::numeric_limits<int64_t>::min() - 1.0,
      -2.0,
      -1.1,
      -1.0,
      -std::numeric_limits<double>::epsilon(),
      -std::numeric_limits<double>::min(),
      -std::numeric_limits<double>::denorm_min(),
      -0.0,
      0.0,
      std::numeric_limits<double>::denorm_min(),
      std::numeric_limits<double>::min(),
      std::numeric_limits<double>::epsilon(),
      1.0,
      1.1,
      2.0,
      // Static cast silences warning about the conversion changing the value.
      static_cast<double>(std::numeric_limits<int64_t>::max()) - 1.0,
      static_cast<double>(std::numeric_limits<int64_t>::max()),
      static_cast<double>(std::numeric_limits<int64_t>::max()) + 1.0,
      std::numeric_limits<double>::max(),
      std::numeric_limits<double>::infinity(),
  };

  for (double double_value : cases) {
    Message<google_firestore_v1_Value> model = Value(double_value);
    ExpectRoundTrip(model, ValueProto(double_value), TypeOrder::kNumber);
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
    Message<google_firestore_v1_Value> model = Value(string_value);
    ExpectRoundTrip(model, ValueProto(string_value), TypeOrder::kString);
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
    Message<google_firestore_v1_Value> model = Value(ts_value);
    ExpectRoundTrip(model, ValueProto(ts_value), TypeOrder::kTimestamp);
  }
}

TEST_F(SerializerTest, EncodesBlobs) {
  std::vector<ByteString> cases{
      {},
      {0, 1, 2, 3},
      {0xff, 0x00, 0xff, 0x00},
  };

  for (const ByteString& blob_value : cases) {
    Message<google_firestore_v1_Value> model = Value(blob_value);
    ExpectRoundTrip(model, ValueProto(blob_value), TypeOrder::kBlob);
  }
}

TEST_F(SerializerTest, EncodesNullBlobs) {
  ByteString blob;
  ASSERT_EQ(blob.get(), nullptr);  // Empty blobs are backed by a null buffer.
  Message<google_firestore_v1_Value> model = Value(blob);

  // Avoid calling SerializerTest::EncodeFieldValue here because the Serializer
  // could be allocating an empty byte array. These assertions show that the
  // null blob really does materialize in the proto as null.
  ASSERT_EQ(model->which_value_type, google_firestore_v1_Value_bytes_value_tag);
  ASSERT_EQ(model->bytes_value, nullptr);

  // Encoding a Value message containing a blob_value of null bytes results
  // in a non-empty message.
  ByteStringWriter writer;
  writer.Write(google_firestore_v1_Value_fields, model.get());
  ByteString bytes = writer.Release();
  ASSERT_GT(bytes.size(), 0);

  // When parsed by protobuf, this should be indistinguishable from having sent
  // the empty string.
  auto parsed_proto = ProtobufParse<v1::Value>(bytes);
  std::string actual = parsed_proto.bytes_value();
  EXPECT_EQ(actual, "");
}

TEST_F(SerializerTest, EncodesReferences) {
  Message<google_firestore_v1_Value> ref_value =
      RefValue(DatabaseId{kProjectId, kDatabaseId},
               DocumentKey::FromPathString("baz/a"));
  ExpectRoundTrip(ref_value, ValueProto(ref_value), TypeOrder::kReference);
}

TEST_F(SerializerTest, EncodesGeoPoint) {
  std::vector<GeoPoint> cases{
      {1.23, 4.56},
  };

  for (const GeoPoint& geo_value : cases) {
    Message<google_firestore_v1_Value> model = Value(geo_value);
    ExpectRoundTrip(model, ValueProto(geo_value), TypeOrder::kGeoPoint);
  }
}

TEST_F(SerializerTest, EncodesArray) {
  std::vector<Message<google_firestore_v1_ArrayValue>> cases;

  // Empty Array.
  cases.push_back(Array());
  // Typical Array.
  cases.push_back(Array(true, "foo"));
  // Nested Array. NB: the protos explicitly state that directly nested
  // arrays are not allowed, however arrays *can* contain a map which
  // contains another array.
  cases.push_back(Array("foo",
                        Map("nested array", Array("nested array value 1",
                                                  "nested array value 2")),
                        "bar"));

  for (Message<google_firestore_v1_ArrayValue>& array_value : cases) {
    Message<google_firestore_v1_Value> model = Value(std::move(array_value));
    ExpectRoundTrip(model, ValueProto(model), TypeOrder::kArray);
  }
}

TEST_F(SerializerTest, EncodesEmptyMap) {
  Message<google_firestore_v1_Value> model = Map();

  v1::Value proto;
  proto.mutable_map_value();

  ExpectRoundTrip(model, proto, TypeOrder::kMap);
}

TEST_F(SerializerTest, EncodesNestedObjects) {
  Message<google_firestore_v1_Value> model = Map(
      "b", true, "d", std::numeric_limits<double>::max(), "i", 1, "n", nullptr,
      "s", "foo", "a", Array(2, "bar", Map("b", false)), "o",
      Map("d", 100, "nested", Map("e", std::numeric_limits<int64_t>::max())));

  v1::Value inner_proto;
  google::protobuf::Map<std::string, v1::Value>* inner_fields =
      inner_proto.mutable_map_value()->mutable_fields();
  (*inner_fields)["e"] = ValueProto(std::numeric_limits<int64_t>::max());

  v1::Value middle_proto;
  google::protobuf::Map<std::string, v1::Value>* middle_fields =
      middle_proto.mutable_map_value()->mutable_fields();
  (*middle_fields)["d"] = ValueProto(int64_t{100});
  (*middle_fields)["nested"] = inner_proto;

  v1::Value array_proto;
  *array_proto.mutable_array_value()->add_values() = ValueProto(int64_t{2});
  *array_proto.mutable_array_value()->add_values() = ValueProto("bar");
  v1::Value array_inner_proto;
  google::protobuf::Map<std::string, v1::Value>* array_inner_fields =
      array_inner_proto.mutable_map_value()->mutable_fields();
  (*array_inner_fields)["b"] = ValueProto(false);
  *array_proto.mutable_array_value()->add_values() = array_inner_proto;

  v1::Value proto;
  google::protobuf::Map<std::string, v1::Value>* fields =
      proto.mutable_map_value()->mutable_fields();
  (*fields)["b"] = ValueProto(true);
  (*fields)["d"] = ValueProto(std::numeric_limits<double>::max());
  (*fields)["i"] = ValueProto(int64_t{1});
  (*fields)["n"] = ValueProto(nullptr);
  (*fields)["s"] = ValueProto("foo");
  (*fields)["a"] = array_proto;
  (*fields)["o"] = middle_proto;

  ExpectRoundTrip(model, proto, TypeOrder::kMap);
}

TEST_F(SerializerTest, EncodesVectorValue) {
  Message<google_firestore_v1_Value> model =
      Map("__type__", "__vector__", "value", Array(1.0, 2.0, 3.0));

  v1::Value array_proto;
  *array_proto.mutable_array_value()->add_values() = ValueProto(1.0);
  *array_proto.mutable_array_value()->add_values() = ValueProto(2.0);
  *array_proto.mutable_array_value()->add_values() = ValueProto(3.0);

  v1::Value proto;
  google::protobuf::Map<std::string, v1::Value>* fields =
      proto.mutable_map_value()->mutable_fields();
  (*fields)["__type__"] = ValueProto("__vector__");
  (*fields)["value"] = array_proto;

  ExpectRoundTrip(model, proto, TypeOrder::kVector);
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
  // google_firestore_v1_Value, and then populate and serialize it using
  // the normal nanopb mechanisms. This should give us a wire-compatible Value
  // message, but with multiple values set.

  // Copy of the real one (from the nanopb generated document.pb.h), but with
  // only boolean_value and integer_value.
  struct google_firestore_v1_Value_Fake {
    bool boolean_value;
    int64_t integer_value;
  };

  // Copy of the real one (from the nanopb generated document.pb.c), but with
  // only boolean_value and integer_value.
  const pb_field_t google_firestore_v1_Value_fields_Fake[3] = {
      PB_FIELD(1, BOOL, SINGULAR, STATIC, FIRST, google_firestore_v1_Value_Fake,
               boolean_value, boolean_value, 0),
      PB_FIELD(2, INT64, SINGULAR, STATIC, OTHER,
               google_firestore_v1_Value_Fake, integer_value, boolean_value, 0),
      PB_LAST_FIELD,
  };

  // Craft the bytes. boolean_value has a smaller tag, so it'll get encoded
  // first. Implying integer_value should "win".
  google_firestore_v1_Value_Fake crafty_value{false, int64_t{42}};
  std::vector<uint8_t> bytes(128);
  pb_ostream_t stream = pb_ostream_from_buffer(bytes.data(), bytes.size());
  pb_encode(&stream, google_firestore_v1_Value_fields_Fake, &crafty_value);
  bytes.resize(stream.bytes_written);

  // Decode the bytes into the model
  StringReader reader(bytes);

  auto actual_model = Message<google_firestore_v1_Value>::TryParse(&reader);
  EXPECT_OK(reader.status());

  // Ensure the decoded model is as expected.
  Message<google_firestore_v1_Value> expected_model = Value(42);
  EXPECT_EQ(TypeOrder::kNumber, GetTypeOrder(*actual_model));
  EXPECT_EQ(*expected_model, *actual_model);
}

TEST_F(SerializerTest, BadBoolValueInterpretedAsTrue) {
  std::vector<uint8_t> bytes = MakeVector(EncodeFieldValue(Value(true)));

  // Alter the bool value from 1 to 2. (Value values are 0,1)
  Mutate(&bytes[1], /*expected_initial_value=*/1, /*new_value=*/2);

  StringReader reader(bytes);
  auto actual_model = Message<google_firestore_v1_Value>::TryParse(&reader);

  ASSERT_OK(reader.status());
  EXPECT_TRUE(actual_model->boolean_value);
}

TEST_F(SerializerTest, BadIntegerValue) {
  // Encode 'maxint'. This should result in 9 0xff bytes, followed by a 1.
  auto max_int = Value(std::numeric_limits<uint64_t>::max());
  std::vector<uint8_t> bytes = MakeVector(EncodeFieldValue(max_int));
  ASSERT_EQ(11u, bytes.size());
  for (size_t i = 1; i < bytes.size() - 1; i++) {
    ASSERT_EQ(0xff, bytes[i]);
  }

  // make the number a bit bigger
  Mutate(&bytes[10], /*expected_initial_value=*/1, /*new_value=*/0xff);
  bytes.resize(12);
  bytes[11] = 0x7f;

  ExpectFailedStatusDuringFieldValueDecode(
      Status(Error::kErrorDataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadStringValue) {
  std::vector<uint8_t> bytes = MakeVector(EncodeFieldValue(Value("a")));

  // Claim that the string length is 5 instead of 1. (The first two bytes are
  // used by the encoded tag.)
  Mutate(&bytes[2], /*expected_initial_value=*/1, /*new_value=*/5);

  ExpectFailedStatusDuringFieldValueDecode(
      Status(Error::kErrorDataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadFieldValueTagAndNoOtherTagPresent) {
  // A bad tag should be ignored. But if there are *no* valid tags, then we
  // don't know the type of the FieldValue. Although it might be reasonable to
  // assume some sort of default type in this situation, we've decided to fail
  // the deserialization process in this case instead.

  std::vector<uint8_t> bytes = MakeVector(EncodeFieldValue(Value(nullptr)));

  // The v1::Value value_type oneof currently has tags up to 18. For this test,
  // we'll pick a tag that's unlikely to be added in the near term but still
  // fits within a uint8_t even when encoded.  Specifically 31. 0xf8 represents
  // field number 31 encoded as a varint.
  Mutate(&bytes[0], /*expected_initial_value=*/0x58, /*new_value=*/0xf8);

  ExpectFailedStatusDuringFieldValueDecode(
      Status(Error::kErrorDataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, BadFieldValueTagWithOtherValidTagsPresent) {
  // A bad tag should be ignored, in which case, we should successfully
  // deserialize the rest of the bytes as if it wasn't there. To craft these
  // bytes, we'll use the same technique as
  // EncodesFieldValuesWithRepeatedEntries (so go read the comments there
  // first).

  // Copy of the real one (from the nanopb generated document.pb.h), but with
  // only boolean_value and integer_value.
  struct google_firestore_v1_Value_Fake {
    bool boolean_value;
    int64_t integer_value;
  };

  // Copy of the real one (from the nanopb generated document.pb.c), but with
  // only boolean_value and integer_value. Also modified such that integer_value
  // now has an invalid tag (instead of 2).
  const int invalid_tag = 31;
  const pb_field_t google_firestore_v1_Value_fields_Fake[3] = {
      PB_FIELD(1, BOOL, SINGULAR, STATIC, FIRST, google_firestore_v1_Value_Fake,
               boolean_value, boolean_value, 0),
      PB_FIELD(invalid_tag, INT64, SINGULAR, STATIC, OTHER,
               google_firestore_v1_Value_Fake, integer_value, boolean_value, 0),
      PB_LAST_FIELD,
  };

  // Craft the bytes. boolean_value has a smaller tag, so it'll get encoded
  // first, normally implying integer_value should "win". Except that
  // integer_value isn't a valid tag, so it should be ignored here.
  google_firestore_v1_Value_Fake crafty_value{true, int64_t{42}};
  std::vector<uint8_t> bytes(128);
  pb_ostream_t stream = pb_ostream_from_buffer(bytes.data(), bytes.size());
  pb_encode(&stream, google_firestore_v1_Value_fields_Fake, &crafty_value);
  bytes.resize(stream.bytes_written);

  // Decode the bytes into the model
  StringReader reader(bytes);
  auto actual_model = Message<google_firestore_v1_Value>::TryParse(&reader);
  EXPECT_OK(reader.status());

  // Ensure the decoded model is as expected.
  Message<google_firestore_v1_Value> expected_model = Value(true);
  EXPECT_EQ(TypeOrder::kBoolean, GetTypeOrder(*actual_model));
  EXPECT_EQ(*expected_model, *actual_model);
}

TEST_F(SerializerTest, IncompleteFieldValue) {
  std::vector<uint8_t> bytes = MakeVector(EncodeFieldValue(Value(nullptr)));
  ASSERT_EQ(2u, bytes.size());

  // Remove the (null) payload
  ASSERT_EQ(0x00, bytes[1]);
  bytes.pop_back();

  ExpectFailedStatusDuringFieldValueDecode(
      Status(Error::kErrorDataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, EncodesKey) {
  EXPECT_EQ(ResourceName(""), FromBytes(serializer.EncodeKey(Key(""))));
  EXPECT_EQ(ResourceName("one/two/three/four"),
            FromBytes(serializer.EncodeKey(Key("one/two/three/four"))));
}

TEST_F(SerializerTest, DecodesKey) {
  StringReader reader(nullptr, 0);
  EXPECT_EQ(Key(""), serializer.DecodeKey(reader.context(),
                                          ToBytes(ResourceName("")).get()));
  EXPECT_EQ(
      Key("one/two/three/four"),
      serializer.DecodeKey(reader.context(),
                           ToBytes(ResourceName("one/two/three/four")).get()));
  // Same, but with a leading slash
  EXPECT_EQ(
      Key("one/two/three/four"),
      serializer.DecodeKey(reader.context(),
                           ToBytes(ResourceName("one/two/three/four")).get()));
  EXPECT_OK(reader.status());
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
    StringReader reader(nullptr, 0);
    serializer.DecodeKey(reader.context(), ToBytes(bad_key).get());
    EXPECT_NOT_OK(reader.status());
  }
}

TEST_F(SerializerTest, EncodesEmptyDocument) {
  DocumentKey key = DocumentKey::FromPathString("path/to/the/doc");
  ObjectValue empty_value{};
  SnapshotVersion update_time = SnapshotVersion{{1234, 5678}};

  v1::BatchGetDocumentsResponse proto;
  v1::Document* doc_proto = proto.mutable_found();
  doc_proto->set_name(FromBytes(serializer.EncodeKey(key)));
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
  ObjectValue fields{
      Map("foo", "bar", "two", 2, "nested", Map("forty-two", 42))};
  SnapshotVersion update_time = SnapshotVersion{{1234, 5678}};

  v1::Value inner_proto;
  google::protobuf::Map<std::string, v1::Value>& inner_fields =
      *inner_proto.mutable_map_value()->mutable_fields();
  inner_fields["forty-two"] = ValueProto(int64_t{42});

  v1::BatchGetDocumentsResponse proto;
  v1::Document* doc_proto = proto.mutable_found();
  doc_proto->set_name(FromBytes(serializer.EncodeKey(key)));
  google::protobuf::Map<std::string, v1::Value>& m =
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

TEST_F(SerializerTest, DecodesNoDocument) {
  // We can't actually *encode* a NoDocument; the method exposed by the
  // serializer requires both the document key and contents (as an ObjectValue,
  // i.e. map.) The contents can be empty, but not missing.  As a result, this
  // test will only verify the ability to decode a NoDocument.

  DocumentKey key = DocumentKey::FromPathString("path/to/the/doc");
  SnapshotVersion read_time =
      SnapshotVersion{{/*seconds=*/1234, /*nanoseconds=*/5678}};

  v1::BatchGetDocumentsResponse proto;
  proto.set_missing(FromBytes(serializer.EncodeKey(key)));
  google::protobuf::Timestamp* read_time_proto = proto.mutable_read_time();
  read_time_proto->set_seconds(read_time.timestamp().seconds());
  read_time_proto->set_nanos(read_time.timestamp().nanoseconds());

  ExpectNoDocumentDeserializationRoundTrip(key, read_time, proto);
}

TEST_F(SerializerTest, DecodeMaybeDocWithoutFoundOrMissingSetShouldFail) {
  v1::BatchGetDocumentsResponse proto;

  ByteString bytes = ProtobufSerialize(proto);
  ExpectFailedStatusDuringMaybeDocumentDecode(
      Status(Error::kErrorDataLoss, "ignored"), bytes);
}

TEST_F(SerializerTest, EncodesFirstLevelKeyQueries) {
  TargetData model = CreateTargetData("docs/1");

  v1::Target proto;
  proto.mutable_documents()->add_documents(ResourceName("docs/1"));
  proto.set_target_id(1);

  SCOPED_TRACE("EncodesFirstLevelKeyQueries");
  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesTargetDataWithExpectedResumeType) {
  TargetData target = CreateTargetData("docs/1");

  {
    SCOPED_TRACE("EncodesTargetDataWithoutResumeType");
    v1::Target proto;
    proto.mutable_documents()->add_documents(ResourceName("docs/1"));
    proto.set_target_id(1);
    ExpectRoundTrip(target, proto);
  }

  {
    SCOPED_TRACE("EncodesTargetDataWithResumeToken");
    v1::Target proto;
    proto.mutable_documents()->add_documents(ResourceName("docs/1"));
    proto.set_target_id(1);
    proto.set_resume_token("resume_token");
    ExpectRoundTrip(target.WithResumeToken(nanopb::ByteString{"resume_token"},
                                           model::SnapshotVersion::None()),
                    proto);
  }

  {
    SCOPED_TRACE("EncodesTargetDataWithResumeByReadTime");
    v1::Target proto;
    proto.mutable_documents()->add_documents(ResourceName("docs/1"));
    proto.set_target_id(1);
    proto.mutable_read_time()->set_seconds(1000);
    proto.mutable_read_time()->set_nanos(42);
    ExpectRoundTrip(
        target.WithResumeToken(nanopb::ByteString{""},
                               model::SnapshotVersion(Timestamp(1000, 42))),
        proto);
  }
}

TEST_F(SerializerTest, EncodesFirstLevelAncestorQueries) {
  TargetData model = CreateTargetData("messages");

  v1::Target proto;
  proto.mutable_query()->set_parent(ResourceName(""));
  proto.set_target_id(1);

  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("messages");
  *proto.mutable_query()->mutable_structured_query()->add_from() =
      std::move(from);

  v1::StructuredQuery::Order order;
  order.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order);

  SCOPED_TRACE("EncodesFirstLevelAncestorQueries");
  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesNestedAncestorQueries) {
  TargetData model = CreateTargetData("rooms/1/messages/10/attachments");

  v1::Target proto;
  proto.mutable_query()->set_parent(ResourceName("rooms/1/messages/10"));
  proto.set_target_id(1);

  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("attachments");
  *proto.mutable_query()->mutable_structured_query()->add_from() =
      std::move(from);

  v1::StructuredQuery::Order order;
  order.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order);

  SCOPED_TRACE("EncodesNestedAncestorQueries");
  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesSingleFiltersAtFirstLevelCollections) {
  core::Query q = Query("docs").AddingFilter(Filter("prop", "<", 42));
  TargetData model = CreateTargetData(std::move(q));

  v1::Target proto;
  proto.mutable_query()->set_parent(ResourceName(""));
  proto.set_target_id(1);

  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("docs");
  *proto.mutable_query()->mutable_structured_query()->add_from() =
      std::move(from);

  v1::StructuredQuery::Order order1;
  order1.mutable_field()->set_field_path("prop");
  order1.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order1);

  v1::StructuredQuery::Order order2;
  order2.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order2.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order2);

  v1::StructuredQuery::FieldFilter& filter = *proto.mutable_query()
                                                  ->mutable_structured_query()
                                                  ->mutable_where()
                                                  ->mutable_field_filter();
  filter.mutable_field()->set_field_path("prop");
  filter.set_op(v1::StructuredQuery::FieldFilter::LESS_THAN);
  filter.mutable_value()->set_integer_value(42);

  SCOPED_TRACE("EncodesSingleFiltersAtFirstLevelCollections");
  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesMultipleFiltersOnDeeperCollections) {
  core::Query q =
      Query("rooms/1/messages/10/attachments")
          .AddingFilter(Filter("prop", ">=", 42))
          .AddingFilter(Filter("author", "==", "dimond"))
          .AddingFilter(Filter("tags", "array_contains", "pending"));
  TargetData model = CreateTargetData(std::move(q));

  v1::Target proto;
  proto.mutable_query()->set_parent(ResourceName("rooms/1/messages/10"));
  proto.set_target_id(1);

  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("attachments");
  *proto.mutable_query()->mutable_structured_query()->add_from() =
      std::move(from);

  v1::StructuredQuery::Filter filter1;
  v1::StructuredQuery::FieldFilter& field1 = *filter1.mutable_field_filter();
  field1.mutable_field()->set_field_path("prop");
  field1.set_op(v1::StructuredQuery::FieldFilter::GREATER_THAN_OR_EQUAL);
  field1.mutable_value()->set_integer_value(42);

  v1::StructuredQuery::Filter filter2;
  v1::StructuredQuery::FieldFilter& field2 = *filter2.mutable_field_filter();
  field2.mutable_field()->set_field_path("author");
  field2.set_op(v1::StructuredQuery::FieldFilter::EQUAL);
  field2.mutable_value()->set_string_value("dimond");

  v1::StructuredQuery::Filter filter3;
  v1::StructuredQuery::FieldFilter& field3 = *filter3.mutable_field_filter();
  field3.mutable_field()->set_field_path("tags");
  field3.set_op(v1::StructuredQuery::FieldFilter::ARRAY_CONTAINS);
  field3.mutable_value()->set_string_value("pending");

  v1::StructuredQuery::CompositeFilter& composite =
      *proto.mutable_query()
           ->mutable_structured_query()
           ->mutable_where()
           ->mutable_composite_filter();
  composite.set_op(v1::StructuredQuery::CompositeFilter::AND);
  *composite.add_filters() = std::move(filter1);
  *composite.add_filters() = std::move(filter2);
  *composite.add_filters() = std::move(filter3);

  v1::StructuredQuery::Order order1;
  order1.mutable_field()->set_field_path("prop");
  order1.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order1);

  v1::StructuredQuery::Order order2;
  order2.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order2.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order2);

  SCOPED_TRACE("EncodesMultipleFiltersOnDeeperCollections");
  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesCompositeFiltersOnDeeperCollections) {
  // (prop < 42) || (author == "cheryllin" && tags array-contains
  // "pending")
  core::Query q =
      Query("rooms/1/messages/10/attachments")
          .AddingFilter(OrFilters(
              {Filter("prop", "<", 42),
               AndFilters({Filter("author", "==", "cheryllin"),
                           Filter("tags", "array-contains", "pending")})}));
  TargetData model = CreateTargetData(std::move(q));

  v1::Target proto;
  proto.mutable_query()->set_parent(ResourceName("rooms/1/messages/10"));
  proto.set_target_id(1);

  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("attachments");
  *proto.mutable_query()->mutable_structured_query()->add_from() =
      std::move(from);

  v1::StructuredQuery::Filter filter1;
  v1::StructuredQuery::FieldFilter& field1 = *filter1.mutable_field_filter();
  field1.mutable_field()->set_field_path("prop");
  field1.set_op(v1::StructuredQuery::FieldFilter::LESS_THAN);
  field1.mutable_value()->set_integer_value(42);

  v1::StructuredQuery::Filter filter2;
  v1::StructuredQuery::FieldFilter& field2 = *filter2.mutable_field_filter();
  field2.mutable_field()->set_field_path("author");
  field2.set_op(v1::StructuredQuery::FieldFilter::EQUAL);
  field2.mutable_value()->set_string_value("cheryllin");

  v1::StructuredQuery::Filter filter3;
  v1::StructuredQuery::FieldFilter& field3 = *filter3.mutable_field_filter();
  field3.mutable_field()->set_field_path("tags");
  field3.set_op(v1::StructuredQuery::FieldFilter::ARRAY_CONTAINS);
  field3.mutable_value()->set_string_value("pending");

  v1::StructuredQuery::Filter filter4;
  v1::StructuredQuery::CompositeFilter& and_composite =
      *filter4.mutable_composite_filter();
  and_composite.set_op(v1::StructuredQuery::CompositeFilter::AND);
  *and_composite.add_filters() = std::move(filter2);
  *and_composite.add_filters() = std::move(filter3);

  v1::StructuredQuery::CompositeFilter& or_composite =
      *proto.mutable_query()
           ->mutable_structured_query()
           ->mutable_where()
           ->mutable_composite_filter();
  or_composite.set_op(v1::StructuredQuery::CompositeFilter::OR);
  *or_composite.add_filters() = std::move(filter1);
  *or_composite.add_filters() = std::move(filter4);

  v1::StructuredQuery::Order order1;
  order1.mutable_field()->set_field_path("prop");
  order1.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order1);

  v1::StructuredQuery::Order order2;
  order2.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order2.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order2);

  SCOPED_TRACE("EncodesCompositeFiltersOnDeeperCollections");
  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesNullFilter) {
  SCOPED_TRACE("EncodesNullFilter");
  ExpectUnaryOperator("==", Value(nullptr),
                      v1::StructuredQuery_UnaryFilter_Operator_IS_NULL);
}

TEST_F(SerializerTest, EncodesNanFilter) {
  SCOPED_TRACE("EncodesNanFilter");
  ExpectUnaryOperator("==", Value(NAN),
                      v1::StructuredQuery_UnaryFilter_Operator_IS_NAN);
}

TEST_F(SerializerTest, EncodesNotNullFilter) {
  SCOPED_TRACE("EncodesNotNullFilter");
  ExpectUnaryOperator("!=", Value(nullptr),
                      v1::StructuredQuery_UnaryFilter_Operator_IS_NOT_NULL);
}

TEST_F(SerializerTest, EncodesNotNanFilter) {
  SCOPED_TRACE("EncodesNotNanFilter");
  ExpectUnaryOperator("!=", Value(NAN),
                      v1::StructuredQuery_UnaryFilter_Operator_IS_NOT_NAN);
}

TEST_F(SerializerTest, EncodesSortOrders) {
  core::Query q = Query("docs").AddingOrderBy(testutil::OrderBy("prop", "asc"));
  TargetData model = CreateTargetData(std::move(q));

  v1::Target proto;
  proto.mutable_query()->set_parent(ResourceName(""));
  proto.set_target_id(1);

  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("docs");
  *proto.mutable_query()->mutable_structured_query()->add_from() =
      std::move(from);

  v1::StructuredQuery::Order order1;
  order1.mutable_field()->set_field_path("prop");
  order1.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order1);

  v1::StructuredQuery::Order order2;
  order2.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order2.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order2);

  SCOPED_TRACE("EncodesSortOrders");
  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesBounds) {
  core::Query q = Query("docs")
                      .StartingAt(Bound::FromValue(Array("prop", 42),
                                                   /*inclusive=*/false))
                      .EndingAt(Bound::FromValue(Array("author", "dimond"),
                                                 /*inclusive=*/false));
  TargetData model = CreateTargetData(std::move(q));

  v1::Target proto;
  proto.mutable_query()->set_parent(ResourceName(""));
  proto.set_target_id(1);

  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("docs");
  *proto.mutable_query()->mutable_structured_query()->add_from() =
      std::move(from);

  v1::StructuredQuery::Order order;
  order.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order);

  v1::Cursor start_at;
  start_at.set_before(false);
  *start_at.add_values() = ValueProto("prop");
  *start_at.add_values() = ValueProto(42);
  *proto.mutable_query()->mutable_structured_query()->mutable_start_at() =
      std::move(start_at);

  v1::Cursor end_at;
  end_at.set_before(true);
  *end_at.add_values() = ValueProto("author");
  *end_at.add_values() = ValueProto("dimond");
  *proto.mutable_query()->mutable_structured_query()->mutable_end_at() =
      std::move(end_at);

  SCOPED_TRACE("EncodesBounds");
  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesSortOrdersDescending) {
  core::Query q = Query("rooms/1/messages/10/attachments")
                      .AddingOrderBy(OrderBy("prop", "desc"));
  TargetData model = CreateTargetData(std::move(q));

  v1::Target proto;
  proto.mutable_query()->set_parent(ResourceName("rooms/1/messages/10"));
  proto.set_target_id(1);

  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("attachments");
  *proto.mutable_query()->mutable_structured_query()->add_from() =
      std::move(from);

  v1::StructuredQuery::Order order1;
  order1.mutable_field()->set_field_path("prop");
  order1.set_direction(v1::StructuredQuery::DESCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order1);

  v1::StructuredQuery::Order order2;
  order2.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order2.set_direction(v1::StructuredQuery::DESCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order2);

  SCOPED_TRACE("EncodesSortOrdersDescending");
  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesLimits) {
  TargetData model = CreateTargetData(Query("docs").WithLimitToFirst(26));

  v1::Target proto;
  proto.mutable_query()->set_parent(ResourceName(""));
  proto.set_target_id(1);

  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("docs");
  *proto.mutable_query()->mutable_structured_query()->add_from() =
      std::move(from);

  v1::StructuredQuery::Order order;
  order.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order);

  proto.mutable_query()->mutable_structured_query()->mutable_limit()->set_value(
      26);

  SCOPED_TRACE("EncodesLimits");
  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesResumeTokens) {
  core::Query q = Query("docs");
  TargetData model(q.ToTarget(), 1, 0, QueryPurpose::Listen,
                   SnapshotVersion::None(), SnapshotVersion::None(),
                   Bytes({1, 2, 3}), /*expected_count=*/absl::nullopt);

  v1::Target proto;
  proto.mutable_query()->set_parent(ResourceName(""));
  proto.set_target_id(1);

  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("docs");
  *proto.mutable_query()->mutable_structured_query()->add_from() =
      std::move(from);

  v1::StructuredQuery::Order order;
  order.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order);

  proto.set_resume_token("\001\002\003");

  SCOPED_TRACE("EncodesResumeTokens");
  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesExpectedCount) {
  core::Query q = Query("docs");
  TargetData model(q.ToTarget(), 1, 0, QueryPurpose::Listen,
                   SnapshotVersion::None(), SnapshotVersion::None(),
                   Bytes({1, 2, 3}), /*expected_count=*/1234);

  v1::Target proto;
  proto.mutable_query()->set_parent(ResourceName(""));
  proto.set_target_id(1);

  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("docs");
  *proto.mutable_query()->mutable_structured_query()->add_from() =
      std::move(from);

  v1::StructuredQuery::Order order;
  order.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order);

  proto.set_resume_token("\001\002\003");

  google::protobuf::Int32Value int32_value;
  google::protobuf::Int32Value* expected_count = int32_value.New();
  expected_count->set_value(1234);
  proto.set_allocated_expected_count(expected_count);

  EXPECT_TRUE(proto.has_expected_count());
  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodeExpectedCountSkippedWithoutResumeToken) {
  core::Query q = Query("docs");
  TargetData model(q.ToTarget(), 1, 0, QueryPurpose::Listen,
                   SnapshotVersion::None(), SnapshotVersion::None(),
                   ByteString(), /*expected_count=*/1234);

  v1::Target proto;
  proto.mutable_query()->set_parent(ResourceName(""));
  proto.set_target_id(1);

  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("docs");
  *proto.mutable_query()->mutable_structured_query()->add_from() =
      std::move(from);

  v1::StructuredQuery::Order order;
  order.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order.set_direction(v1::StructuredQuery::ASCENDING);
  *proto.mutable_query()->mutable_structured_query()->add_order_by() =
      std::move(order);

  EXPECT_FALSE(proto.has_expected_count());
  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesListenRequestLabels) {
  core::Query q = Query("docs");

  std::map<QueryPurpose, std::unordered_map<std::string, std::string>>
      purpose_to_label = {
          {QueryPurpose::Listen, {}},
          {QueryPurpose::LimboResolution,
           {{"goog-listen-tags", "limbo-document"}}},
          {QueryPurpose::ExistenceFilterMismatch,
           {{"goog-listen-tags", "existence-filter-mismatch"}}},
      };

  for (const auto& p : purpose_to_label) {
    TargetData model(q.ToTarget(), 1, 0, p.first);

    auto result = serializer.EncodeListenRequestLabels(model);
    std::unordered_map<std::string, std::string> result_in_map;
    for (auto& label_entry : result) {
      result_in_map[serializer.DecodeString(label_entry.key)] =
          serializer.DecodeString(label_entry.value);
      pb_release(google_firestore_v1_ListenRequest_LabelsEntry_fields,
                 &label_entry);
    }

    EXPECT_EQ(result_in_map, p.second);
  }
}

TEST_F(SerializerTest, DecodesMutationResult) {
  Message<google_firestore_v1_ArrayValue> transformations =
      Array(true, 1234, "string");
  auto version = Version(123456789);
  MutationResult model(version, std::move(transformations));

  v1::WriteResult proto;

  proto.mutable_update_time()->set_seconds(version.timestamp().seconds());
  proto.mutable_update_time()->set_nanos(version.timestamp().nanoseconds());
  auto transform_results = proto.mutable_transform_results();
  *transform_results->Add() = ValueProto(true);
  *transform_results->Add() = ValueProto(1234);
  *transform_results->Add() = ValueProto("string");

  SCOPED_TRACE("DecodesMutationResult");
  ExpectDeserializationRoundTrip(model, proto, Version(10000000));
}

TEST_F(SerializerTest, DecodesMutationResultWithNoUpdateTime) {
  MutationResult model(Version(10000000), {});

  v1::WriteResult proto;

  SCOPED_TRACE("DecodesMutationResultWithNoUpdateTime");
  ExpectDeserializationRoundTrip(model, proto, Version(10000000));
}

TEST_F(SerializerTest, DecodesListenResponseWithAddedTargetChange) {
  WatchTargetChange model(WatchTargetChangeState::Added, {1, 2},
                          ByteString("resume_token"));

  v1::ListenResponse proto;

  proto.mutable_target_change()->set_target_change_type(
      v1::TargetChange_TargetChangeType::TargetChange_TargetChangeType_ADD);
  proto.mutable_target_change()->add_target_ids(1);
  proto.mutable_target_change()->add_target_ids(2);
  proto.mutable_target_change()->set_resume_token("resume_token");

  SCOPED_TRACE("DecodesListenResponseWithAddedTargetChange");
  ExpectDeserializationRoundTrip(model, proto);
}

TEST_F(SerializerTest, DecodesListenResponseWithRemovedTargetChange) {
  WatchTargetChange model(
      WatchTargetChangeState::Removed, {1, 2}, ByteString("resume_token"),
      Status{Error::kErrorPermissionDenied, "Error message"});

  v1::ListenResponse proto;

  auto change = proto.mutable_target_change();
  change->set_target_change_type(
      v1::TargetChange_TargetChangeType::TargetChange_TargetChangeType_REMOVE);
  change->add_target_ids(1);
  change->add_target_ids(2);
  change->set_resume_token("resume_token");
  change->mutable_cause()->set_code(Error::kErrorPermissionDenied);
  change->mutable_cause()->set_message("Error message");

  SCOPED_TRACE("DecodesListenResponseWithRemovedTargetChange");
  ExpectDeserializationRoundTrip(model, proto);
}

TEST_F(SerializerTest, DecodesListenResponseWithNoChangeTargetChange) {
  WatchTargetChange model(WatchTargetChangeState::NoChange, {1, 2},
                          ByteString("resume_token"));

  v1::ListenResponse proto;

  proto.mutable_target_change()->set_target_change_type(
      v1::TargetChange_TargetChangeType::
          TargetChange_TargetChangeType_NO_CHANGE);
  proto.mutable_target_change()->add_target_ids(1);
  proto.mutable_target_change()->add_target_ids(2);
  proto.mutable_target_change()->set_resume_token("resume_token");

  SCOPED_TRACE("DecodesListenResponseWithNoChangeTargetChange");
  ExpectDeserializationRoundTrip(model, proto);
}

TEST_F(SerializerTest, DecodesListenResponseWithDocumentChange) {
  SnapshotVersion version = Version(123456789L);
  DocumentWatchChange model(
      {1, 3}, {2, 4}, Key("one/two/three/four"),
      Doc("one/two/three/four", 123456789L, Map("foo", "bar")));

  v1::ListenResponse proto;

  auto document_change = proto.mutable_document_change();
  document_change->mutable_document()->set_name(
      ResourceName("one/two/three/four"));
  document_change->mutable_document()->mutable_update_time()->set_seconds(
      version.timestamp().seconds());
  document_change->mutable_document()->mutable_update_time()->set_nanos(
      version.timestamp().nanoseconds());
  (*document_change->mutable_document()->mutable_fields())["foo"] =
      ValueProto("bar");

  document_change->add_target_ids(1);
  document_change->add_target_ids(3);
  document_change->add_removed_target_ids(2);
  document_change->add_removed_target_ids(4);

  SCOPED_TRACE("DecodesListenResponseWithDocumentChange");
  ExpectDeserializationRoundTrip(model, proto);
}

TEST_F(SerializerTest, DecodesListenResponseWithDocumentDelete) {
  DocumentWatchChange model({}, {1}, Key("one/two/three/four"),
                            DeletedDoc("one/two/three/four"));

  v1::ListenResponse proto;

  auto document_delete = proto.mutable_document_delete();
  document_delete->set_document(ResourceName("one/two/three/four"));

  document_delete->add_removed_target_ids(1);

  SCOPED_TRACE("DecodesListenResponseWithDocumentDelete");
  ExpectDeserializationRoundTrip(model, proto);
}

TEST_F(SerializerTest, DecodesListenResponseWithDocumentRemove) {
  DocumentWatchChange model({}, {1, 2}, Key("one/two/three/four"),
                            absl::nullopt);

  v1::ListenResponse proto;

  auto document_remove = proto.mutable_document_remove();
  document_remove->set_document(ResourceName("one/two/three/four"));

  document_remove->add_removed_target_ids(1);
  document_remove->add_removed_target_ids(2);

  SCOPED_TRACE("DecodesListenResponseWithDocumentRemove");
  ExpectDeserializationRoundTrip(model, proto);
}

TEST_F(SerializerTest, DecodesListenResponseWithExistenceFilter) {
  ExistenceFilterWatchChange model(
      ExistenceFilter(2, /*bloom_filter=*/absl::nullopt), 100);

  v1::ListenResponse proto;

  proto.mutable_filter()->set_count(2);
  proto.mutable_filter()->set_target_id(100);

  SCOPED_TRACE("DecodesListenResponseWithExistenceFilter");
  ExpectDeserializationRoundTrip(model, proto);
}

TEST_F(SerializerTest,
       DecodesListenResponseWithExistenceFilterWhenBloomFilterNotNull) {
  ExistenceFilterWatchChange model(
      ExistenceFilter(555, BloomFilterParameters{{0x42, 0xFE}, 7, 33}), 999);

  v1::ListenResponse proto;
  proto.mutable_filter()->set_count(555);
  proto.mutable_filter()->set_target_id(999);

  v1::BloomFilter* bloom_filter =
      proto.mutable_filter()->mutable_unchanged_names();
  bloom_filter->set_hash_count(33);
  bloom_filter->mutable_bits()->set_padding(7);
  bloom_filter->mutable_bits()->set_bitmap("\x42\xFE");

  SCOPED_TRACE(
      "DecodesListenResponseWithExistenceFilterWhenBloomFilterNotNull");
  ExpectDeserializationRoundTrip(model, proto);
}

TEST_F(SerializerTest, DecodesVersion) {
  auto version = Version(123456789);
  SnapshotVersion model(version.timestamp());

  v1::ListenResponse proto;
  proto.mutable_target_change()->mutable_read_time()->set_seconds(
      version.timestamp().seconds());
  proto.mutable_target_change()->mutable_read_time()->set_nanos(
      version.timestamp().nanoseconds());

  SCOPED_TRACE("DecodesVersion");
  ExpectDeserializationRoundTrip(model, proto);
}

TEST_F(SerializerTest, DecodesVersionWithNoReadTime) {
  auto model = SnapshotVersion::None();

  v1::ListenResponse proto;

  SCOPED_TRACE("DecodesVersionWithNoReadTime");
  ExpectDeserializationRoundTrip(model, proto);
}

TEST_F(SerializerTest, DecodesVersionWithTargets) {
  auto version = Version(123456789);
  auto model = SnapshotVersion::None();

  v1::ListenResponse proto;
  // proto is decoded to `None()` even with `read_time` set, because
  // `target_ids` is not empty.
  proto.mutable_target_change()->mutable_target_ids()->Add(1);
  proto.mutable_target_change()->mutable_read_time()->set_seconds(
      version.timestamp().seconds());
  proto.mutable_target_change()->mutable_read_time()->set_nanos(
      version.timestamp().nanoseconds());

  SCOPED_TRACE("DecodesVersionWithTargets");
  ExpectDeserializationRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesSetMutation) {
  SetMutation model = testutil::SetMutation("docs/1", Map("a", "b", "num", 1));

  v1::Write proto;
  v1::Document& doc = *proto.mutable_update();
  doc.set_name(ResourceName("docs/1"));
  auto& fields = *doc.mutable_fields();
  fields["a"] = ValueProto("b");
  fields["num"] = ValueProto(1);

  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesPatchMutation) {
  PatchMutation model = testutil::PatchMutation(
      "docs/1", Map("a", "b", "num", 1, R"(some.de\\ep.th\ing')", 2));

  v1::Write proto;

  v1::Document& doc = *proto.mutable_update();
  doc.set_name(ResourceName("docs/1"));
  auto& fields = *doc.mutable_fields();
  fields["a"] = ValueProto("b");
  fields["num"] = ValueProto(1);
  fields["some"] = ValueProto(Map("de\\ep", Map("thing'", Value(2))));

  v1::DocumentMask& mask = *proto.mutable_update_mask();
  mask.add_field_paths("a");
  mask.add_field_paths("num");
  mask.add_field_paths("some.`de\\\\ep`.`thing'`");

  proto.mutable_current_document()->set_exists(true);

  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesDeleteMutation) {
  DeleteMutation model = testutil::DeleteMutation("docs/1");

  v1::Write proto;
  proto.set_delete_(ResourceName("docs/1"));

  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesVerifyMutation) {
  VerifyMutation model = testutil::VerifyMutation("docs/1", 4);

  v1::Write proto;
  proto.set_verify(ResourceName("docs/1"));

  google::protobuf::Timestamp timestamp;
  timestamp.set_nanos(4000);
  *proto.mutable_current_document()->mutable_update_time() = timestamp;

  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesServerTimestampTransform) {
  std::vector<std::pair<std::string, TransformOperation>> transforms = {
      {"a", ServerTimestampTransform()}, {"bar", ServerTimestampTransform()}};

  SetMutation set_model = testutil::SetMutation("docs/1", Map(), transforms);

  v1::Write set_proto;
  v1::Document& doc = *set_proto.mutable_update();
  doc.set_name(ResourceName("docs/1"));

  v1::DocumentTransform::FieldTransform server_proto1;
  server_proto1.set_field_path("a");
  server_proto1.set_set_to_server_value(
      v1::DocumentTransform::FieldTransform::REQUEST_TIME);
  *set_proto.add_update_transforms() = std::move(server_proto1);

  v1::DocumentTransform::FieldTransform set_transform2;
  set_transform2.set_field_path("bar");
  set_transform2.set_set_to_server_value(
      v1::DocumentTransform::FieldTransform::REQUEST_TIME);
  *set_proto.add_update_transforms() = std::move(set_transform2);

  ExpectRoundTrip(set_model, set_proto);

  PatchMutation patch_model =
      testutil::PatchMutation("docs/1", Map(), transforms);

  v1::Write patch_proto;
  v1::Document& doc2 = *patch_proto.mutable_update();
  doc2 = *patch_proto.mutable_update();
  doc2.set_name(ResourceName("docs/1"));

  v1::DocumentTransform::FieldTransform update_transform1;
  update_transform1.set_field_path("a");
  update_transform1.set_set_to_server_value(
      v1::DocumentTransform::FieldTransform::REQUEST_TIME);
  *patch_proto.add_update_transforms() = std::move(update_transform1);

  v1::DocumentTransform::FieldTransform update_transform2;
  update_transform2.set_field_path("bar");
  update_transform2.set_set_to_server_value(
      v1::DocumentTransform::FieldTransform::REQUEST_TIME);
  *patch_proto.add_update_transforms() = std::move(update_transform2);

  v1::DocumentMask mask;
  patch_proto.set_allocated_update_mask(mask.New());
  patch_proto.mutable_current_document()->set_exists(true);

  ExpectRoundTrip(patch_model, patch_proto);
}

TEST_F(SerializerTest, EncodesArrayTransform) {
  ArrayTransform array_union{TransformOperation::Type::ArrayUnion,
                             {Array("a", 2)}};
  ArrayTransform array_remove{TransformOperation::Type::ArrayRemove,
                              {Array(Map("x", 1))}};
  SetMutation set_model = testutil::SetMutation(
      "docs/1", Map(), {{"a", array_union}, {"bar", array_remove}});

  v1::Write set_proto;
  v1::Document& doc = *set_proto.mutable_update();
  doc.set_name(ResourceName("docs/1"));

  v1::DocumentTransform::FieldTransform union_proto;
  union_proto.set_field_path("a");
  v1::ArrayValue& append = *union_proto.mutable_append_missing_elements();
  *append.add_values() = ValueProto("a");
  *append.add_values() = ValueProto(2);
  *set_proto.add_update_transforms() = std::move(union_proto);

  v1::DocumentTransform::FieldTransform remove_proto;
  remove_proto.set_field_path("bar");
  v1::ArrayValue& remove = *remove_proto.mutable_remove_all_from_array();
  *remove.add_values() = ValueProto(Map("x", 1));
  *set_proto.add_update_transforms() = std::move(remove_proto);

  ExpectRoundTrip(set_model, set_proto);

  PatchMutation patch_model = testutil::PatchMutation(
      "docs/1", Map(), {{"a", array_union}, {"bar", array_remove}});

  v1::Write patch_proto;
  v1::Document& doc2 = *patch_proto.mutable_update();
  doc2 = *patch_proto.mutable_update();
  doc2.set_name(ResourceName("docs/1"));

  v1::DocumentTransform::FieldTransform union_proto2;
  union_proto2.set_field_path("a");
  v1::ArrayValue& append2 = *union_proto2.mutable_append_missing_elements();
  *append2.add_values() = ValueProto("a");
  *append2.add_values() = ValueProto(2);
  *patch_proto.add_update_transforms() = std::move(union_proto2);

  v1::DocumentTransform::FieldTransform remove_proto2;
  remove_proto2.set_field_path("bar");
  v1::ArrayValue& remove2 = *remove_proto2.mutable_remove_all_from_array();
  *remove2.add_values() = ValueProto(Map("x", 1));
  *patch_proto.add_update_transforms() = std::move(remove_proto2);

  v1::DocumentMask mask;
  patch_proto.set_allocated_update_mask(mask.New());
  patch_proto.mutable_current_document()->set_exists(true);

  ExpectRoundTrip(patch_model, patch_proto);
}

TEST_F(SerializerTest, EncodesSetMutationWithPrecondition) {
  SetMutation model{Key("foo/bar"), testutil::WrapObject("a", "b", "num", 1),
                    Precondition::UpdateTime(Version(4))};

  v1::Write proto;
  v1::Document& doc = *proto.mutable_update();
  doc.set_name(ResourceName("foo/bar"));
  auto& fields = *doc.mutable_fields();
  fields["a"] = ValueProto("b");
  fields["num"] = ValueProto(1);

  google::protobuf::Timestamp timestamp;
  timestamp.set_nanos(4000);
  *proto.mutable_current_document()->mutable_update_time() = timestamp;

  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, RoundTripsSpecialFieldNames) {
  SetMutation model = testutil::SetMutation(
      "collection/key",
      Map("field", "field 1", "field.dot", 2, "field\\slash", 3));

  v1::Write proto;
  v1::Document& doc = *proto.mutable_update();
  doc.set_name(ResourceName("collection/key"));
  auto& fields = *doc.mutable_fields();
  fields["field"] = ValueProto("field 1");
  fields["field.dot"] = ValueProto(2);
  fields["field\\slash"] = ValueProto(3);

  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesUnaryFilter) {
  auto model = testutil::Filter("item", "==", nullptr);

  v1::StructuredQuery::Filter proto;
  v1::StructuredQuery::UnaryFilter& unary = *proto.mutable_unary_filter();
  unary.mutable_field()->set_field_path("item");
  unary.set_op(v1::StructuredQuery::UnaryFilter::IS_NULL);

  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesFieldFilter) {
  auto model = testutil::Filter("item.part.top", "==", "food");

  v1::StructuredQuery::Filter proto;
  v1::StructuredQuery::FieldFilter& field = *proto.mutable_field_filter();
  field.mutable_field()->set_field_path("item.part.top");
  field.set_op(v1::StructuredQuery::FieldFilter::EQUAL);
  *field.mutable_value() = ValueProto("food");

  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesNotEqualFilter) {
  auto model = testutil::Filter("item.tags", "!=", "food");

  v1::StructuredQuery::Filter proto;
  v1::StructuredQuery::FieldFilter& field = *proto.mutable_field_filter();
  field.mutable_field()->set_field_path("item.tags");
  field.set_op(v1::StructuredQuery::FieldFilter::NOT_EQUAL);
  *field.mutable_value() = ValueProto("food");

  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesArrayContainsFilter) {
  auto model = testutil::Filter("item.tags", "array_contains", "food");

  v1::StructuredQuery::Filter proto;
  v1::StructuredQuery::FieldFilter& field = *proto.mutable_field_filter();
  field.mutable_field()->set_field_path("item.tags");
  field.set_op(v1::StructuredQuery::FieldFilter::ARRAY_CONTAINS);
  *field.mutable_value() = ValueProto("food");

  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesArrayContainsAnyFilter) {
  auto model =
      testutil::Filter("item.tags", "array-contains-any", Array("food"));

  v1::StructuredQuery::Filter proto;
  v1::StructuredQuery::FieldFilter& field = *proto.mutable_field_filter();
  field.mutable_field()->set_field_path("item.tags");
  field.set_op(v1::StructuredQuery::FieldFilter::ARRAY_CONTAINS_ANY);
  *field.mutable_value() = ValueProto(Array("food"));

  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesInFilter) {
  auto model = testutil::Filter("item.tags", "in", Array("food"));

  v1::StructuredQuery::Filter proto;
  v1::StructuredQuery::FieldFilter& field = *proto.mutable_field_filter();
  field.mutable_field()->set_field_path("item.tags");
  field.set_op(v1::StructuredQuery::FieldFilter::IN_);
  *field.mutable_value() = ValueProto(Array("food"));

  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesNotInFilter) {
  auto model = testutil::Filter("item.tags", "not-in", Array("food"));

  v1::StructuredQuery::Filter proto;
  v1::StructuredQuery::FieldFilter& field = *proto.mutable_field_filter();
  field.mutable_field()->set_field_path("item.tags");
  field.set_op(v1::StructuredQuery::FieldFilter::NOT_IN);
  *field.mutable_value() = ValueProto(Array("food"));

  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesNotInFilterWithNull) {
  auto model = testutil::Filter("item.tags", "not-in", Array(nullptr));

  v1::StructuredQuery::Filter proto;
  v1::StructuredQuery::FieldFilter& field = *proto.mutable_field_filter();
  field.mutable_field()->set_field_path("item.tags");
  field.set_op(v1::StructuredQuery::FieldFilter::NOT_IN);
  *field.mutable_value() = ValueProto(Array(nullptr));

  ExpectRoundTrip(model, proto);
}

TEST_F(SerializerTest, EncodesKeyFieldFilter) {
  auto model = testutil::Filter("__name__", "==", Ref("p/d", "coll/doc"));

  v1::StructuredQuery::Filter proto;
  v1::StructuredQuery::FieldFilter& field = *proto.mutable_field_filter();
  field.mutable_field()->set_field_path("__name__");
  field.set_op(v1::StructuredQuery::FieldFilter::EQUAL);
  *field.mutable_value() = ValueProto(DatabaseId{"p", "d"}, Key("coll/doc"));

  ExpectRoundTrip(model, proto);
}

// TODO(rsgowman): Test [en|de]coding multiple protos into the same output
// vector.

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
