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

#include "Firestore/core/src/local/local_serializer.h"

#include "Firestore/Protos/cpp/firestore/bundle.pb.h"
#include "Firestore/Protos/cpp/firestore/local/maybe_document.pb.h"
#include "Firestore/Protos/cpp/firestore/local/mutation.pb.h"
#include "Firestore/Protos/cpp/firestore/local/target.pb.h"
#include "Firestore/core/src/bundle/bundled_query.h"
#include "Firestore/core/src/bundle/named_query.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/core/target.h"
#include "Firestore/core/src/local/target_data.h"
#include "Firestore/core/src/model/delete_mutation.h"
#include "Firestore/core/src/model/field_mask.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/mutation.h"
#include "Firestore/core/src/model/mutation_batch.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/precondition.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "Firestore/core/src/model/types.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/nanopb/reader.h"
#include "Firestore/core/src/nanopb/writer.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/test/unit/nanopb/nanopb_testing.h"
#include "Firestore/core/test/unit/testutil/status_testing.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "google/protobuf/util/message_differencer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

namespace v1 = google::firestore::v1;
using bundle::BundledQuery;
using bundle::NamedQuery;
using core::Query;
using core::Target;
using ::google::protobuf::util::MessageDifferencer;
using model::DatabaseId;
using model::DocumentKey;
using model::FieldMask;
using model::FieldPath;
using model::ListenSequenceNumber;
using model::MutableDocument;
using model::Mutation;
using model::MutationBatch;
using model::ObjectValue;
using model::PatchMutation;
using model::Precondition;
using model::SetMutation;
using model::SnapshotVersion;
using model::TargetId;
using nanopb::ByteString;
using nanopb::ByteStringWriter;
using nanopb::FreeNanopbMessage;
using nanopb::MakeArray;
using nanopb::MakeBytesArray;
using nanopb::MakeStdString;
using nanopb::Message;
using nanopb::ProtobufParse;
using nanopb::ProtobufSerialize;
using nanopb::SetRepeatedField;
using nanopb::StringReader;
using nanopb::Writer;
using testutil::DeletedDoc;
using testutil::Doc;
using testutil::Field;
using testutil::Filter;
using testutil::Key;
using testutil::Map;
using testutil::OrderBy;
using testutil::Query;
using testutil::UnknownDoc;
using testutil::Value;
using testutil::WrapObject;
using util::Status;

class LocalSerializerTest : public ::testing::Test {
 public:
  LocalSerializerTest()
      : remote_serializer(DatabaseId("p", "d")), serializer(remote_serializer) {
    msg_diff.ReportDifferencesToString(&message_differences);
  }

  remote::Serializer remote_serializer;
  local::LocalSerializer serializer;

  Timestamp write_time_ = Timestamp::Now();

  static google_firestore_v1_Write SetProto() {
    google_firestore_v1_Write set_proto{};
    set_proto.which_operation = google_firestore_v1_Write_update_tag;
    set_proto.update.name =
        MakeBytesArray("projects/p/databases/d/documents/docs/1");
    set_proto.update.fields_count = 2;
    set_proto.update.fields =
        MakeArray<google_firestore_v1_Document_FieldsEntry>(2);
    set_proto.update.fields[0].key = MakeBytesArray("a");
    set_proto.update.fields[0].value = Value("b");
    set_proto.update.fields[1].key = MakeBytesArray("num");
    set_proto.update.fields[1].value = Value(1);
    return set_proto;
  }

  static google_firestore_v1_Write PatchProto() {
    google_firestore_v1_Write patch_proto = SetProto();
    patch_proto.has_update_mask = true;
    patch_proto.update_mask.field_paths_count = 1;
    patch_proto.update_mask.field_paths = MakeArray<pb_bytes_array_t*>(1);
    patch_proto.update_mask.field_paths[0] = MakeBytesArray("a");
    patch_proto.has_current_document = true;
    patch_proto.current_document.which_condition_type =
        google_firestore_v1_Precondition_exists_tag;
    patch_proto.current_document.exists = true;
    return patch_proto;
  }

  static google_firestore_v1_Write DeleteProto() {
    google_firestore_v1_Write delete_proto{};
    delete_proto.which_operation = google_firestore_v1_Write_delete_tag;
    delete_proto.delete_ =
        MakeBytesArray("projects/p/databases/d/documents/docs/1");
    return delete_proto;
  }

  static google_firestore_v1_Write LegacyTransformProto() {
    google_firestore_v1_Write transform_proto{};

    google_firestore_v1_DocumentTransform_FieldTransform inc_proto1;
    inc_proto1.field_path = MakeBytesArray("integer");
    inc_proto1.which_transform_type =
        google_firestore_v1_DocumentTransform_FieldTransform_increment_tag;
    inc_proto1.increment = Value(42);

    google_firestore_v1_DocumentTransform_FieldTransform inc_proto2;
    inc_proto2.field_path = MakeBytesArray("double");
    inc_proto2.which_transform_type =
        google_firestore_v1_DocumentTransform_FieldTransform_increment_tag;
    inc_proto2.increment = Value(13.37);

    transform_proto.which_operation = google_firestore_v1_Write_transform_tag;
    transform_proto.transform.field_transforms_count = 2;
    transform_proto.transform.field_transforms =
        MakeArray<google_firestore_v1_DocumentTransform_FieldTransform>(2);
    transform_proto.transform.field_transforms[0] = inc_proto1;
    transform_proto.transform.field_transforms[1] = inc_proto2;

    transform_proto.current_document.which_condition_type =
        google_firestore_v1_Precondition_exists_tag;
    transform_proto.current_document.exists = true;
    transform_proto.transform.document =
        MakeBytesArray("projects/p/databases/d/documents/docs/1");
    return transform_proto;
  }

  google_protobuf_Timestamp WriteTimeProto() {
    google_protobuf_Timestamp write_time_proto{};
    write_time_proto.seconds = write_time_.seconds();
    write_time_proto.nanos = write_time_.nanoseconds();
    return write_time_proto;
  }

  template <typename T>
  void SetRepeatedField2(T** fields_array,
                         pb_size_t* fields_count,
                         google_firestore_v1_Value map_value) {
    HARD_ASSERT(
        map_value.which_value_type == google_firestore_v1_Value_map_value_tag,
        "Expected a Map");
    google_firestore_v1_MapValue& input = map_value.map_value;
    *fields_array = MakeArray<T>(input.fields_count);
    *fields_count = input.fields_count;
    for (pb_size_t i = 0; i < input.fields_count; ++i) {
      (*fields_array)[i].key = input.fields[i].key;
      (*fields_array)[i].value = input.fields[i].value;
    }
  }

  static void ExpectSet(google_firestore_v1_Write encoded) {
    EXPECT_EQ(google_firestore_v1_Write_update_tag, encoded.which_operation);
    EXPECT_EQ(2, encoded.update.fields_count);
    EXPECT_EQ("a", nanopb::MakeString(encoded.update.fields[0].key));
    EXPECT_EQ("b",
              nanopb::MakeString(encoded.update.fields[0].value.string_value));
    EXPECT_EQ("num", nanopb::MakeString(encoded.update.fields[1].key));
    EXPECT_EQ(1, encoded.update.fields[1].value.integer_value);
    EXPECT_FALSE(encoded.has_update_mask);
    EXPECT_FALSE(encoded.has_current_document);
  }

  static void ExpectPatch(google_firestore_v1_Write encoded) {
    EXPECT_EQ(google_firestore_v1_Write_update_tag, encoded.which_operation);
    EXPECT_EQ(2, encoded.update.fields_count);
    EXPECT_EQ("a", nanopb::MakeString(encoded.update.fields[0].key));
    EXPECT_EQ("b",
              nanopb::MakeString(encoded.update.fields[0].value.string_value));
    EXPECT_EQ("num", nanopb::MakeString(encoded.update.fields[1].key));
    EXPECT_TRUE(encoded.has_update_mask);
    EXPECT_EQ(1, encoded.update.fields[1].value.integer_value);
    EXPECT_EQ(1, encoded.update_mask.field_paths_count);
    EXPECT_TRUE(encoded.has_current_document);
    EXPECT_TRUE(encoded.current_document.exists);
  }

  static void ExpectDelete(google_firestore_v1_Write encoded) {
    EXPECT_EQ(google_firestore_v1_Write_delete_tag, encoded.which_operation);
  }

  static void ExpectUpdateTransform(google_firestore_v1_Write encoded) {
    EXPECT_EQ(2, encoded.update_transforms_count);
    EXPECT_EQ(
        google_firestore_v1_DocumentTransform_FieldTransform_increment_tag,
        encoded.update_transforms[0].which_transform_type);
    EXPECT_EQ("integer",
              nanopb::MakeString(encoded.update_transforms[0].field_path));
    EXPECT_EQ(42, encoded.update_transforms[0].increment.integer_value);
    EXPECT_EQ(
        google_firestore_v1_DocumentTransform_FieldTransform_increment_tag,
        encoded.update_transforms[1].which_transform_type);
    EXPECT_EQ("double",
              nanopb::MakeString(encoded.update_transforms[1].field_path));
    EXPECT_EQ(13.37, encoded.update_transforms[1].increment.double_value);
  }

  static void ExpectNoUpdateTransform(google_firestore_v1_Write encoded) {
    EXPECT_EQ(0, encoded.update_transforms_count);
  }

  void ExpectRoundTrip(const MutableDocument& expected,
                       const Message<firestore_client_MaybeDocument>& proto) {
    // Convert nanopb to bytes and read back. We don't use Protobuf here
    // since round-tripping through Protobuf does not maintain map field order
    ByteString nanopb_bytes = MakeByteString(proto);
    StringReader reader(nanopb_bytes);
    auto nanopb_msg =
        Message<firestore_client_MaybeDocument>::TryParse(&reader);

    MutableDocument actual =
        serializer.DecodeMaybeDocument(&reader, *nanopb_msg);
    EXPECT_OK(reader.status());
    EXPECT_EQ(expected, actual);
  }

  void ExpectRoundTrip(const TargetData& expected,
                       const Message<firestore_client_Target>& proto) {
    // Convert nanopb to bytes and read back with Protobuf
    ByteString nanopb_bytes = MakeByteString(proto);
    auto protobuf_msg =
        ProtobufParse<::firestore::client::Target>(nanopb_bytes);

    // Convert Protobuf to bytes and read back with nanopb
    ByteString protobuf_bytes = ProtobufSerialize(protobuf_msg);
    StringReader reader(protobuf_bytes);
    auto nanopb_msg = Message<firestore_client_Target>::TryParse(&reader);

    TargetData actual = serializer.DecodeTargetData(&reader, *nanopb_msg);
    EXPECT_OK(reader.status());
    EXPECT_EQ(expected, actual);
  }

  void ExpectRoundTrip(const MutationBatch& expected,
                       const Message<firestore_client_WriteBatch>& proto) {
    // Convert nanopb to bytes and read back. We don't use Protobuf here
    // since round-tripping through Protobuf does not maintain map field order
    ByteString nanopb_bytes = MakeByteString(proto);
    StringReader reader(nanopb_bytes);
    auto nanopb_msg = Message<firestore_client_WriteBatch>::TryParse(&reader);

    MutationBatch actual = serializer.DecodeMutationBatch(&reader, *nanopb_msg);
    EXPECT_OK(reader.status());
    EXPECT_EQ(expected, actual);
  }

  void ExpectRoundTrip(const NamedQuery& expected,
                       const Message<firestore_NamedQuery>& proto) {
    // Convert nanopb to bytes and read back with Protobuf
    ByteString nanopb_bytes = MakeByteString(proto);
    auto protobuf_msg = ProtobufParse<::firestore::NamedQuery>(nanopb_bytes);

    // Convert Protobuf to bytes and read back with nanopb
    ByteString protobuf_bytes = ProtobufSerialize(protobuf_msg);
    StringReader reader(protobuf_bytes);
    auto nanopb_msg = Message<firestore_NamedQuery>::TryParse(&reader);

    NamedQuery actual = serializer.DecodeNamedQuery(&reader, *nanopb_msg);
    EXPECT_OK(reader.status());
    EXPECT_EQ(expected, actual);
  }

  std::string message_differences;
  MessageDifferencer msg_diff;
};

// TODO(b/174608374): Remove these tests once we perform a schema migration.
TEST_F(LocalSerializerTest, SetMutationAndTransformMutationAreSquashed) {
  Message<firestore_client_WriteBatch> batch_proto;
  batch_proto->batch_id = 42;
  SetRepeatedField(&batch_proto->writes, &batch_proto->writes_count,
                   {SetProto(), LegacyTransformProto()});
  batch_proto->local_write_time = WriteTimeProto();

  std::string bytes = MakeStdString(batch_proto);
  StringReader reader(bytes);
  auto message = Message<firestore_client_WriteBatch>::TryParse(&reader);
  MutationBatch decoded = serializer.DecodeMutationBatch(&reader, *message);
  ASSERT_EQ(1, decoded.mutations().size());
  ASSERT_EQ(Mutation::Type::Set, decoded.mutations()[0].type());

  google_firestore_v1_Write encoded =
      remote_serializer.EncodeMutation(decoded.mutations()[0]);
  ExpectSet(encoded);
  ExpectUpdateTransform(encoded);
}

// TODO(b/174608374): Remove these tests once we perform a schema migration.
TEST_F(LocalSerializerTest, PatchMutationAndTransformMutationAreSquashed) {
  Message<firestore_client_WriteBatch> batch_proto;
  batch_proto->batch_id = 42;
  SetRepeatedField(&batch_proto->writes, &batch_proto->writes_count,
                   {PatchProto(), LegacyTransformProto()});
  batch_proto->local_write_time = WriteTimeProto();

  std::string bytes = MakeStdString(batch_proto);
  StringReader reader(bytes);
  auto message = Message<firestore_client_WriteBatch>::TryParse(&reader);
  MutationBatch decoded = serializer.DecodeMutationBatch(&reader, *message);
  ASSERT_EQ(1, decoded.mutations().size());
  ASSERT_EQ(Mutation::Type::Patch, decoded.mutations()[0].type());

  google_firestore_v1_Write encoded =
      remote_serializer.EncodeMutation(decoded.mutations()[0]);
  ExpectPatch(encoded);
  ExpectUpdateTransform(encoded);
}

// TODO(b/174608374): Remove these tests once we perform a schema migration.
TEST_F(LocalSerializerTest, TransformAndTransformThrowError) {
  Message<firestore_client_WriteBatch> batch_proto;
  batch_proto->batch_id = 42;
  SetRepeatedField(&batch_proto->writes, &batch_proto->writes_count,
                   {LegacyTransformProto(), LegacyTransformProto()});
  batch_proto->local_write_time = WriteTimeProto();

  std::string bytes = MakeStdString(batch_proto);
  StringReader reader(bytes);
  auto message = Message<firestore_client_WriteBatch>::TryParse(&reader);
  EXPECT_ANY_THROW(serializer.DecodeMutationBatch(&reader, *message));
}

// TODO(b/174608374): Remove these tests once we perform a schema migration.
TEST_F(LocalSerializerTest, DeleteAndTransformThrowError) {
  Message<firestore_client_WriteBatch> batch_proto;
  batch_proto->batch_id = 42;
  SetRepeatedField(&batch_proto->writes, &batch_proto->writes_count,
                   {DeleteProto(), LegacyTransformProto()});
  batch_proto->local_write_time = WriteTimeProto();

  std::string bytes = MakeStdString(batch_proto);
  StringReader reader(bytes);
  auto message = Message<firestore_client_WriteBatch>::TryParse(&reader);
  EXPECT_ANY_THROW(serializer.DecodeMutationBatch(&reader, *message));
}

// TODO(b/174608374): Remove these tests once we perform a schema migration.
TEST_F(LocalSerializerTest, MultipleMutationsAreSquashed) {
  Message<firestore_client_WriteBatch> batch_proto{};
  batch_proto->batch_id = 42;
  SetRepeatedField(
      &batch_proto->writes, &batch_proto->writes_count,
      {SetProto(), SetProto(), LegacyTransformProto(), DeleteProto(),
       PatchProto(), LegacyTransformProto(), PatchProto()});
  batch_proto->local_write_time = WriteTimeProto();

  std::string bytes = MakeStdString(batch_proto);
  StringReader reader(bytes);
  auto message = Message<firestore_client_WriteBatch>::TryParse(&reader);
  MutationBatch decoded = serializer.DecodeMutationBatch(&reader, *message);
  ASSERT_EQ(5, decoded.mutations().size());
  _google_firestore_v1_Write encoded =
      remote_serializer.EncodeMutation(decoded.mutations()[0]);
  ExpectSet(encoded);
  ExpectNoUpdateTransform(encoded);
  encoded = remote_serializer.EncodeMutation(decoded.mutations()[1]);
  ExpectSet(encoded);
  ExpectUpdateTransform(encoded);
  encoded = remote_serializer.EncodeMutation(decoded.mutations()[2]);
  ExpectDelete(encoded);
  encoded = remote_serializer.EncodeMutation(decoded.mutations()[3]);
  ExpectPatch(encoded);
  ExpectUpdateTransform(encoded);
  encoded = remote_serializer.EncodeMutation(decoded.mutations()[4]);
  ExpectPatch(encoded);
  ExpectNoUpdateTransform(encoded);
}

TEST_F(LocalSerializerTest, EncodesMutationBatch) {
  Mutation base =
      PatchMutation(Key("docs/1"), WrapObject("a", "b"), FieldMask{Field("a")},
                    Precondition::Exists(true));

  Mutation set = testutil::SetMutation("docs/1", Map("a", "b", "num", 1));
  Mutation patch =
      PatchMutation(Key("docs/1"), WrapObject("a", "b", "num", 1),
                    FieldMask{Field("a")}, Precondition::Exists(true));
  Mutation del = testutil::DeleteMutation("docs/1");

  MutationBatch model(42, write_time_, {base}, {set, patch, del});

  google_firestore_v1_Write base_proto{};
  base_proto.which_operation = google_firestore_v1_Write_update_tag;
  base_proto.update.name =
      MakeBytesArray("projects/p/databases/d/documents/docs/1");
  SetRepeatedField2(&base_proto.update.fields, &base_proto.update.fields_count,
                    Map("a", "b"));
  base_proto.has_update_mask = true;
  SetRepeatedField(&base_proto.update_mask.field_paths,
                   &base_proto.update_mask.field_paths_count,
                   {MakeBytesArray("a")});
  base_proto.has_current_document = true;
  base_proto.current_document.which_condition_type =
      google_firestore_v1_Precondition_exists_tag;
  base_proto.current_document.exists = true;

  Message<firestore_client_WriteBatch> batch_proto{};
  batch_proto->batch_id = 42;
  SetRepeatedField(&batch_proto->base_writes, &batch_proto->base_writes_count,
                   {base_proto});
  SetRepeatedField(&batch_proto->writes, &batch_proto->writes_count,
                   {SetProto(), PatchProto(), DeleteProto()});
  batch_proto->local_write_time = WriteTimeProto();

  ExpectRoundTrip(model, batch_proto);
}

TEST_F(LocalSerializerTest, EncodesDocumentAsMaybeDocument) {
  MutableDocument doc = Doc("some/path", /*version=*/42, Map("foo", "bar"));

  Message<firestore_client_MaybeDocument> maybe_doc_proto;
  maybe_doc_proto->which_document_type =
      firestore_client_MaybeDocument_document_tag;
  maybe_doc_proto->document.name =
      MakeBytesArray("projects/p/databases/d/documents/some/path");
  SetRepeatedField2(&maybe_doc_proto->document.fields,
                    &maybe_doc_proto->document.fields_count, Map("foo", "bar"));
  maybe_doc_proto->document.has_update_time = true;
  maybe_doc_proto->document.update_time.seconds = 0;
  maybe_doc_proto->document.update_time.nanos = 42000;

  ExpectRoundTrip(doc, maybe_doc_proto);

  // Verify has_committed_mutations
  doc = Doc("some/path", /*version=*/42, Map("foo", "bar"))
            .SetHasCommittedMutations();
  maybe_doc_proto->has_committed_mutations = true;

  ExpectRoundTrip(doc, maybe_doc_proto);
}

TEST_F(LocalSerializerTest, EncodesNoDocumentAsMaybeDocument) {
  MutableDocument no_doc = DeletedDoc("some/path", /*version=*/42);

  Message<firestore_client_MaybeDocument> maybe_doc_proto;
  maybe_doc_proto->which_document_type =
      firestore_client_MaybeDocument_no_document_tag;
  maybe_doc_proto->no_document.name =
      MakeBytesArray("projects/p/databases/d/documents/some/path");
  maybe_doc_proto->no_document.read_time.seconds = 0;
  maybe_doc_proto->no_document.read_time.nanos = 42000;

  ExpectRoundTrip(no_doc, maybe_doc_proto);

  // Verify has_committed_mutations
  no_doc = DeletedDoc("some/path", /*version=*/42).SetHasCommittedMutations();
  maybe_doc_proto->has_committed_mutations = true;

  ExpectRoundTrip(no_doc, maybe_doc_proto);
}

TEST_F(LocalSerializerTest, EncodesUnknownDocumentAsMaybeDocument) {
  MutableDocument unknown_doc = UnknownDoc("some/path", /*version=*/42);

  Message<firestore_client_MaybeDocument> maybe_doc_proto;
  maybe_doc_proto->which_document_type =
      firestore_client_MaybeDocument_unknown_document_tag;
  maybe_doc_proto->unknown_document.name =
      MakeBytesArray("projects/p/databases/d/documents/some/path");
  maybe_doc_proto->unknown_document.version.seconds = 0;
  maybe_doc_proto->unknown_document.version.nanos = 42000;
  maybe_doc_proto->has_committed_mutations = true;

  ExpectRoundTrip(unknown_doc, maybe_doc_proto);
}

TEST_F(LocalSerializerTest, EncodesTargetData) {
  core::Query query = Query("room");
  TargetId target_id = 42;
  ListenSequenceNumber sequence_number = 10;
  SnapshotVersion version = testutil::Version(1039);
  SnapshotVersion limbo_free_version = testutil::Version(1000);
  ByteString resume_token = testutil::ResumeToken(1039);

  TargetData target_data(query.ToTarget(), target_id, sequence_number,
                         QueryPurpose::Listen, SnapshotVersion(version),
                         SnapshotVersion(limbo_free_version),
                         ByteString(resume_token));

  Message<firestore_client_Target> expected{};
  expected->target_id = target_id;
  expected->last_listen_sequence_number = sequence_number;
  expected->snapshot_version.nanos = 1039000;
  expected->resume_token =
      MakeBytesArray(resume_token.data(), resume_token.size());

  expected->which_target_type = firestore_client_Target_query_tag;
  google_firestore_v1_Target_QueryTarget& query_proto = expected->query;

  // Add expected collection.
  query_proto.parent = MakeBytesArray("projects/p/databases/d/documents");
  query_proto.which_query_type =
      google_firestore_v1_Target_QueryTarget_structured_query_tag;
  google_firestore_v1_StructuredQuery_CollectionSelector from{};
  from.collection_id = MakeBytesArray("room");
  SetRepeatedField(&query_proto.structured_query.from,
                   &query_proto.structured_query.from_count, {from});

  // Add default order_by.
  google_firestore_v1_StructuredQuery_Order order_by{};
  order_by.field.field_path = MakeBytesArray(FieldPath::kDocumentKeyPath);
  order_by.direction = google_firestore_v1_StructuredQuery_Direction_ASCENDING;
  SetRepeatedField(&query_proto.structured_query.order_by,
                   &query_proto.structured_query.order_by_count, {order_by});

  ExpectRoundTrip(target_data, expected);
}

TEST_F(LocalSerializerTest, HandlesInvalidTargetData) {
  TargetId target_id = 42;
  std::string invalid_field_path = "`";

  Message<firestore_client_Target> invalid_target;
  invalid_target->target_id = target_id;

  // Add expected collection.
  invalid_target->which_target_type = firestore_client_Target_query_tag;
  google_firestore_v1_Target_QueryTarget& query_proto = invalid_target->query;
  query_proto.which_query_type =
      google_firestore_v1_Target_QueryTarget_structured_query_tag;
  google_firestore_v1_StructuredQuery_CollectionSelector from{};
  from.collection_id = MakeBytesArray("room");
  SetRepeatedField(&query_proto.structured_query.from,
                   &query_proto.structured_query.from_count, {from});

  // Add invalid order_by.
  google_firestore_v1_StructuredQuery_Order order_by{};
  order_by.field.field_path = MakeBytesArray(invalid_field_path);
  order_by.direction = google_firestore_v1_StructuredQuery_Direction_ASCENDING;
  SetRepeatedField(&query_proto.structured_query.order_by,
                   &query_proto.structured_query.order_by_count, {order_by});

  ByteString bytes = MakeByteString(invalid_target);
  StringReader reader(bytes);

  invalid_target = Message<firestore_client_Target>::TryParse(&reader);
  serializer.DecodeTargetData(&reader, *invalid_target);
  EXPECT_NOT_OK(reader.status());
}

TEST_F(LocalSerializerTest, EncodesTargetDataWithDocumentQuery) {
  core::Query query = Query("room/1");
  TargetId target_id = 42;
  ListenSequenceNumber sequence_number = 10;
  SnapshotVersion version = testutil::Version(1039);
  SnapshotVersion limbo_free_version = testutil::Version(1000);
  ByteString resume_token = testutil::ResumeToken(1039);

  TargetData target_data(query.ToTarget(), target_id, sequence_number,
                         QueryPurpose::Listen, SnapshotVersion(version),
                         SnapshotVersion(limbo_free_version),
                         ByteString(resume_token));

  Message<firestore_client_Target> expected;
  expected->target_id = target_id;
  expected->last_listen_sequence_number = sequence_number;
  expected->snapshot_version.nanos = 1039000;
  expected->last_limbo_free_snapshot_version.nanos = 1000000;
  expected->resume_token =
      MakeBytesArray(resume_token.data(), resume_token.size());
  expected->which_target_type = firestore_client_Target_documents_tag;
  SetRepeatedField(&expected->documents.documents,
                   &expected->documents.documents_count,
                   {MakeBytesArray("projects/p/databases/d/documents/room/1")});

  ExpectRoundTrip(target_data, expected);
}

TEST_F(LocalSerializerTest, EncodesNamedQuery) {
  auto now = Timestamp::Now();
  Target t =
      testutil::Query("a").AddingFilter(Filter("foo", "==", 1)).ToTarget();
  BundledQuery bundle_query(t, core::LimitType::First);
  NamedQuery named_query("query-1", bundle_query, SnapshotVersion(now));

  // Constructing expected proto lite class.
  firestore_BundledQuery expected_bundled_query{};
  expected_bundled_query.parent =
      MakeBytesArray("projects/p/databases/d/documents");
  expected_bundled_query.limit_type = firestore_BundledQuery_LimitType_FIRST;

  expected_bundled_query.which_query_type =
      firestore_BundledQuery_structured_query_tag;
  google_firestore_v1_StructuredQuery& query =
      expected_bundled_query.structured_query;

  google_firestore_v1_StructuredQuery_CollectionSelector from{};
  from.collection_id = MakeBytesArray("a");
  SetRepeatedField(&query.from, &query.from_count, {from});

  query.where.which_filter_type =
      google_firestore_v1_StructuredQuery_Filter_field_filter_tag;
  query.where.field_filter.field.field_path = MakeBytesArray("foo");
  query.where.field_filter.value = Value(1);
  query.where.field_filter.op =
      google_firestore_v1_StructuredQuery_FieldFilter_Operator_EQUAL;

  // Add default order_by.
  google_firestore_v1_StructuredQuery_Order order_by{};
  order_by.field.field_path = MakeBytesArray(FieldPath::kDocumentKeyPath);
  order_by.direction = google_firestore_v1_StructuredQuery_Direction_ASCENDING;
  SetRepeatedField(&query.order_by, &query.order_by_count, {order_by});

  Message<firestore_NamedQuery> expected_named_query;
  expected_named_query->name = MakeBytesArray("query-1");
  expected_named_query->read_time.seconds = now.seconds();
  expected_named_query->read_time.nanos = now.nanoseconds();
  expected_named_query->bundled_query = expected_bundled_query;

  ExpectRoundTrip(named_query, expected_named_query);
}

TEST_F(LocalSerializerTest, EncodesNamedLimitToLastQuery) {
  auto now = Timestamp::Now();
  Target t = testutil::Query("a")
                 // Note we use a limit to first query here because `Target`
                 // cannot be stored with limit type information. It is stored
                 // in `BundledQuery` instead.
                 .WithLimitToFirst(3)
                 .ToTarget();
  BundledQuery bundle_query(t, core::LimitType::Last);
  NamedQuery named_query("query-1", bundle_query, SnapshotVersion(now));

  // Constructing expected proto.
  firestore_BundledQuery expected_bundled_query{};
  expected_bundled_query.parent =
      MakeBytesArray("projects/p/databases/d/documents");
  expected_bundled_query.limit_type = firestore_BundledQuery_LimitType_LAST;

  expected_bundled_query.which_query_type =
      firestore_BundledQuery_structured_query_tag;
  google_firestore_v1_StructuredQuery& query =
      expected_bundled_query.structured_query;
  query.has_limit = true;
  query.limit.value = 3;

  google_firestore_v1_StructuredQuery_CollectionSelector from{};
  from.collection_id = MakeBytesArray("a");
  SetRepeatedField(&query.from, &query.from_count, {from});

  google_firestore_v1_StructuredQuery_Order order_by{};
  order_by.field.field_path = MakeBytesArray(FieldPath::kDocumentKeyPath);
  order_by.direction = google_firestore_v1_StructuredQuery_Direction_ASCENDING;
  SetRepeatedField(&query.order_by, &query.order_by_count, {order_by});

  Message<firestore_NamedQuery> expected_named_query;
  expected_named_query->name = MakeBytesArray("query-1");
  expected_named_query->read_time.seconds = now.seconds();
  expected_named_query->read_time.nanos = now.nanoseconds();
  expected_named_query->bundled_query = expected_bundled_query;

  ExpectRoundTrip(named_query, expected_named_query);
}

}  // namespace
}  // namespace local
}  // namespace firestore
}  // namespace firebase
