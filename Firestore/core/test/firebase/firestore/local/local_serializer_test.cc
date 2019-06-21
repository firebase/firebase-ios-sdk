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

#include "Firestore/core/src/firebase/firestore/local/local_serializer.h"

#include "Firestore/Protos/cpp/firestore/local/maybe_document.pb.h"
#include "Firestore/Protos/cpp/firestore/local/mutation.pb.h"
#include "Firestore/Protos/cpp/firestore/local/target.pb.h"
#include "Firestore/Protos/cpp/google/firestore/v1/firestore.pb.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "Firestore/core/src/firebase/firestore/model/mutation.h"
#include "Firestore/core/src/firebase/firestore/model/mutation_batch.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/model/unknown_document.h"
#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"
#include "Firestore/core/src/firebase/firestore/nanopb/writer.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/test/firebase/firestore/nanopb/nanopb_testing.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "Firestore/core/test/firebase/firestore/util/status_testing.h"
#include "google/protobuf/util/message_differencer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

namespace v1 = google::firestore::v1;
using core::Query;
using ::google::protobuf::util::MessageDifferencer;
using model::DatabaseId;
using model::Document;
using model::DocumentKey;
using model::FieldMask;
using model::FieldPath;
using model::FieldValue;
using model::ListenSequenceNumber;
using model::MaybeDocument;
using model::Mutation;
using model::MutationBatch;
using model::NoDocument;
using model::ObjectValue;
using model::PatchMutation;
using model::Precondition;
using model::SetMutation;
using model::SnapshotVersion;
using model::TargetId;
using model::UnknownDocument;
using nanopb::ByteString;
using nanopb::ByteStringWriter;
using nanopb::ProtobufParse;
using nanopb::ProtobufSerialize;
using nanopb::Reader;
using nanopb::Writer;
using testutil::DeletedDoc;
using testutil::Doc;
using testutil::Key;
using testutil::Query;
using testutil::UnknownDoc;
using util::Status;

class LocalSerializerTest : public ::testing::Test {
 public:
  LocalSerializerTest()
      : remote_serializer(DatabaseId("p", "d")), serializer(remote_serializer) {
    msg_diff.ReportDifferencesToString(&message_differences);
  }

  remote::Serializer remote_serializer;
  local::LocalSerializer serializer;

  template <typename... Args>
  void ExpectRoundTrip(const Args&... args) {
    // First, serialize model with our (nanopb based) serializer, then
    // deserialize the resulting bytes with libprotobuf and ensure the result is
    // the same as the expected proto.
    ExpectSerializationRoundTrip(args...);

    // Next, serialize proto with libprotobuf, then deserialize the resulting
    // bytes with our (nanopb based) deserializer and ensure the result is the
    // same as the expected model.
    ExpectDeserializationRoundTrip(args...);
  }

 private:
  void ExpectSerializationRoundTrip(
      const MaybeDocument& model,
      const ::firestore::client::MaybeDocument& proto,
      MaybeDocument::Type type) {
    EXPECT_EQ(type, model.type());
    ByteString bytes = EncodeMaybeDocument(&serializer, model);
    auto actual = ProtobufParse<::firestore::client::MaybeDocument>(bytes);
    EXPECT_TRUE(msg_diff.Compare(proto, actual)) << message_differences;
  }

  void ExpectDeserializationRoundTrip(
      const MaybeDocument& model,
      const ::firestore::client::MaybeDocument& proto,
      MaybeDocument::Type type) {
    ByteString bytes = ProtobufSerialize(proto);
    Reader reader(bytes);
    firestore_client_MaybeDocument nanopb_proto{};
    reader.ReadNanopbMessage(firestore_client_MaybeDocument_fields,
                             &nanopb_proto);
    std::unique_ptr<MaybeDocument> actual_model =
        serializer.DecodeMaybeDocument(&reader, nanopb_proto);
    reader.FreeNanopbMessage(firestore_client_MaybeDocument_fields,
                             &nanopb_proto);
    EXPECT_OK(reader.status());
    EXPECT_EQ(type, actual_model->type());
    EXPECT_EQ(model, *actual_model);
  }

  ByteString EncodeMaybeDocument(local::LocalSerializer* serializer,
                                 const MaybeDocument& maybe_doc) {
    ByteStringWriter writer;
    firestore_client_MaybeDocument proto =
        serializer->EncodeMaybeDocument(maybe_doc);
    writer.WriteNanopbMessage(firestore_client_MaybeDocument_fields, &proto);
    serializer->FreeNanopbMessage(firestore_client_MaybeDocument_fields,
                                  &proto);
    return writer.Release();
  }

  void ExpectSerializationRoundTrip(const QueryData& query_data,
                                    const ::firestore::client::Target& proto) {
    ByteString bytes = EncodeQueryData(&serializer, query_data);
    auto actual = ProtobufParse<::firestore::client::Target>(bytes);
    EXPECT_TRUE(msg_diff.Compare(proto, actual)) << message_differences;
  }

  void ExpectDeserializationRoundTrip(
      const QueryData& query_data, const ::firestore::client::Target& proto) {
    ByteString bytes = ProtobufSerialize(proto);
    Reader reader(bytes);

    firestore_client_Target nanopb_proto{};
    reader.ReadNanopbMessage(firestore_client_Target_fields, &nanopb_proto);
    QueryData actual_query_data =
        serializer.DecodeQueryData(&reader, nanopb_proto);
    reader.FreeNanopbMessage(firestore_client_Target_fields, &nanopb_proto);

    EXPECT_OK(reader.status());
    EXPECT_EQ(query_data, actual_query_data);
  }

  ByteString EncodeQueryData(local::LocalSerializer* serializer,
                             const QueryData& query_data) {
    EXPECT_EQ(query_data.purpose(), QueryPurpose::kListen);
    ByteStringWriter writer;
    firestore_client_Target proto = serializer->EncodeQueryData(query_data);
    writer.WriteNanopbMessage(firestore_client_Target_fields, &proto);
    serializer->FreeNanopbMessage(firestore_client_Target_fields, &proto);
    return writer.Release();
  }

  void ExpectSerializationRoundTrip(
      const MutationBatch& model,
      const ::firestore::client::WriteBatch& proto) {
    ByteString bytes = EncodeMutationBatch(&serializer, model);
    auto actual = ProtobufParse<::firestore::client::WriteBatch>(bytes);
    EXPECT_TRUE(msg_diff.Compare(proto, actual)) << message_differences;
  }

  void ExpectDeserializationRoundTrip(
      const MutationBatch& model,
      const ::firestore::client::WriteBatch& proto) {
    ByteString bytes = ProtobufSerialize(proto);
    Reader reader(bytes);

    firestore_client_WriteBatch nanopb_proto{};
    reader.ReadNanopbMessage(firestore_client_WriteBatch_fields, &nanopb_proto);
    MutationBatch actual_mutation_batch =
        serializer.DecodeMutationBatch(&reader, nanopb_proto);
    reader.FreeNanopbMessage(firestore_client_WriteBatch_fields, &nanopb_proto);

    EXPECT_OK(reader.status());
    EXPECT_EQ(model, actual_mutation_batch);
  }

  ByteString EncodeMutationBatch(local::LocalSerializer* serializer,
                                 const MutationBatch& mutation_batch) {
    ByteStringWriter writer;
    firestore_client_WriteBatch proto =
        serializer->EncodeMutationBatch(mutation_batch);
    writer.WriteNanopbMessage(firestore_client_WriteBatch_fields, &proto);
    serializer->FreeNanopbMessage(firestore_client_WriteBatch_fields, &proto);
    return writer.Release();
  }

  std::string message_differences;
  MessageDifferencer msg_diff;
};

TEST_F(LocalSerializerTest, EncodesMutationBatch) {
  std::unique_ptr<Mutation> set =
      testutil::SetMutation("foo/bar", {{"a", FieldValue::FromString("b")},
                                        {"num", FieldValue::FromInteger(1)}});
  std::unique_ptr<Mutation> patch = absl::make_unique<PatchMutation>(
      Key("bar/baz"),
      ObjectValue::FromMap({{"a", FieldValue::FromString("b")},
                            {"num", FieldValue::FromInteger(1)}}),
      FieldMask({FieldPath({"a"})}), Precondition::Exists(true));
  std::unique_ptr<Mutation> del = testutil::DeleteMutation("baz/quux");

  Timestamp write_time = Timestamp::Now();
  std::vector<std::unique_ptr<Mutation>> mutations;
  mutations.push_back(std::move(set));
  mutations.push_back(std::move(patch));
  mutations.push_back(std::move(del));
  MutationBatch model(42, write_time, std::move(mutations));

  v1::Value b_value{};
  *b_value.mutable_string_value() = "b";
  v1::Value one_value{};
  one_value.set_integer_value(1);

  v1::Write set_proto{};
  *set_proto.mutable_update()->mutable_name() =
      "projects/p/databases/d/documents/foo/bar";
  (*set_proto.mutable_update()->mutable_fields())["a"] = b_value;
  (*set_proto.mutable_update()->mutable_fields())["num"] = one_value;

  v1::Write patch_proto{};
  *patch_proto.mutable_update()->mutable_name() =
      "projects/p/databases/d/documents/bar/baz";
  (*patch_proto.mutable_update()->mutable_fields())["a"] = b_value;
  (*patch_proto.mutable_update()->mutable_fields())["num"] = one_value;
  patch_proto.mutable_update_mask()->add_field_paths("a");
  patch_proto.mutable_current_document()->set_exists(true);

  v1::Write del_proto{};
  *del_proto.mutable_delete_() = "projects/p/databases/d/documents/baz/quux";

  ::google::protobuf::Timestamp write_time_proto{};
  write_time_proto.set_seconds(write_time.seconds());
  write_time_proto.set_nanos(write_time.nanoseconds());

  ::firestore::client::WriteBatch batch_proto{};
  batch_proto.set_batch_id(42);
  *batch_proto.add_writes() = set_proto;
  assert(batch_proto.writes(0).update().name() ==
         "projects/p/databases/d/documents/foo/bar");
  *batch_proto.add_writes() = patch_proto;
  *batch_proto.add_writes() = del_proto;
  *batch_proto.mutable_local_write_time() = write_time_proto;

  ExpectRoundTrip(model, batch_proto);
}

TEST_F(LocalSerializerTest, EncodesDocumentAsMaybeDocument) {
  Document doc = *Doc("some/path", /*version=*/42,
                      {{"foo", FieldValue::FromString("bar")}});

  ::firestore::client::MaybeDocument maybe_doc_proto;
  maybe_doc_proto.mutable_document()->set_name(
      "projects/p/databases/d/documents/some/path");
  ::google::firestore::v1::Value value_proto;
  value_proto.set_string_value("bar");
  maybe_doc_proto.mutable_document()->mutable_fields()->insert(
      {"foo", value_proto});
  maybe_doc_proto.mutable_document()->mutable_update_time()->set_seconds(0);
  maybe_doc_proto.mutable_document()->mutable_update_time()->set_nanos(42000);

  ExpectRoundTrip(doc, maybe_doc_proto, doc.type());
}

TEST_F(LocalSerializerTest, EncodesNoDocumentAsMaybeDocument) {
  NoDocument no_doc = *DeletedDoc("some/path", /*version=*/42);

  ::firestore::client::MaybeDocument maybe_doc_proto;
  maybe_doc_proto.mutable_no_document()->set_name(
      "projects/p/databases/d/documents/some/path");
  maybe_doc_proto.mutable_no_document()->mutable_read_time()->set_seconds(0);
  maybe_doc_proto.mutable_no_document()->mutable_read_time()->set_nanos(42000);

  ExpectRoundTrip(no_doc, maybe_doc_proto, no_doc.type());
}

TEST_F(LocalSerializerTest, EncodesUnknownDocumentAsMaybeDocument) {
  UnknownDocument unknown_doc = *UnknownDoc("some/path", /*version=*/42);

  ::firestore::client::MaybeDocument maybe_doc_proto;
  maybe_doc_proto.mutable_unknown_document()->set_name(
      "projects/p/databases/d/documents/some/path");
  maybe_doc_proto.mutable_unknown_document()->mutable_version()->set_seconds(0);
  maybe_doc_proto.mutable_unknown_document()->mutable_version()->set_nanos(
      42000);

  ExpectRoundTrip(unknown_doc, maybe_doc_proto, unknown_doc.type());
}

TEST_F(LocalSerializerTest, EncodesQueryData) {
  core::Query query = testutil::Query("room");
  TargetId target_id = 42;
  ListenSequenceNumber sequence_number = 10;
  SnapshotVersion version = testutil::Version(1039);
  ByteString resume_token = testutil::ResumeToken(1039);

  QueryData query_data(core::Query(query), target_id, sequence_number,
                       QueryPurpose::kListen, SnapshotVersion(version),
                       ByteString(resume_token));

  // Let the RPC serializer test various permutations of query serialization.
  ByteStringWriter writer;
  google_firestore_v1_Target_QueryTarget proto =
      remote_serializer.EncodeQueryTarget(query_data.query());
  writer.WriteNanopbMessage(google_firestore_v1_Target_QueryTarget_fields,
                            &proto);
  remote_serializer.FreeNanopbMessage(
      google_firestore_v1_Target_QueryTarget_fields, &proto);

  ByteString query_target_bytes = writer.Release();
  auto query_target_proto =
      ProtobufParse<v1::Target::QueryTarget>(query_target_bytes);

  ::firestore::client::Target expected;
  expected.set_target_id(target_id);
  expected.set_last_listen_sequence_number(sequence_number);
  expected.mutable_snapshot_version()->set_nanos(1039000);
  expected.set_resume_token(resume_token.data(), resume_token.size());
  v1::Target::QueryTarget* query_proto = expected.mutable_query();
  query_proto->set_parent(query_target_proto.parent());
  *query_proto->mutable_structured_query() =
      query_target_proto.structured_query();

  ExpectRoundTrip(query_data, expected);
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
