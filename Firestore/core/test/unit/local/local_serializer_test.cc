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
#include "Firestore/Protos/cpp/google/firestore/v1/firestore.pb.h"
#include "Firestore/core/src/bundle/bundled_query.h"
#include "Firestore/core/src/bundle/named_query.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/core/target.h"
#include "Firestore/core/src/local/target_data.h"
#include "Firestore/core/src/model/delete_mutation.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/field_mask.h"
#include "Firestore/core/src/model/field_value.h"
#include "Firestore/core/src/model/maybe_document.h"
#include "Firestore/core/src/model/mutation.h"
#include "Firestore/core/src/model/mutation_batch.h"
#include "Firestore/core/src/model/no_document.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/precondition.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "Firestore/core/src/model/types.h"
#include "Firestore/core/src/model/unknown_document.h"
#include "Firestore/core/src/nanopb/message.h"
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

namespace v1 = google::firestore::v1;
using bundle::BundledQuery;
using bundle::NamedQuery;
using core::Query;
using core::Target;
using ::google::protobuf::util::MessageDifferencer;
using model::DatabaseId;
using model::Document;
using model::DocumentKey;
using model::DocumentState;
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
using nanopb::FreeNanopbMessage;
using nanopb::Message;
using nanopb::ProtobufParse;
using nanopb::ProtobufSerialize;
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
    StringReader reader(bytes);
    auto message = Message<firestore_client_MaybeDocument>::TryParse(&reader);
    auto actual_model = serializer.DecodeMaybeDocument(&reader, *message);
    EXPECT_OK(reader.status());
    EXPECT_EQ(type, actual_model.type());
    EXPECT_EQ(model, actual_model);
  }

  ByteString EncodeMaybeDocument(local::LocalSerializer* serializer,
                                 const MaybeDocument& maybe_doc) {
    return MakeByteString(serializer->EncodeMaybeDocument(maybe_doc));
  }

  void ExpectSerializationRoundTrip(const TargetData& target_data,
                                    const ::firestore::client::Target& proto) {
    ByteString bytes = EncodeTargetData(&serializer, target_data);
    auto actual = ProtobufParse<::firestore::client::Target>(bytes);
    EXPECT_TRUE(msg_diff.Compare(proto, actual)) << message_differences;
  }

  void ExpectDeserializationRoundTrip(
      const TargetData& target_data, const ::firestore::client::Target& proto) {
    ByteString bytes = ProtobufSerialize(proto);
    StringReader reader(bytes);

    auto message = Message<firestore_client_Target>::TryParse(&reader);
    TargetData actual_target_data =
        serializer.DecodeTargetData(&reader, *message);

    EXPECT_OK(reader.status());
    EXPECT_EQ(target_data, actual_target_data);
  }

  ByteString EncodeTargetData(local::LocalSerializer* serializer,
                              const TargetData& target_data) {
    EXPECT_EQ(target_data.purpose(), QueryPurpose::Listen);
    return MakeByteString(serializer->EncodeTargetData(target_data));
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
    StringReader reader(bytes);

    auto message = Message<firestore_client_WriteBatch>::TryParse(&reader);
    MutationBatch actual_mutation_batch =
        serializer.DecodeMutationBatch(&reader, *message);

    EXPECT_OK(reader.status());
    EXPECT_EQ(model, actual_mutation_batch);
  }

  ByteString EncodeMutationBatch(local::LocalSerializer* serializer,
                                 const MutationBatch& mutation_batch) {
    return MakeByteString(serializer->EncodeMutationBatch(mutation_batch));
  }

  void ExpectSerializationRoundTrip(const NamedQuery& named_query,
                                    const ::firestore::NamedQuery& proto) {
    ByteString bytes = EncodeNamedQuery(&serializer, named_query);
    auto actual = ProtobufParse<::firestore::NamedQuery>(bytes);
    EXPECT_TRUE(msg_diff.Compare(proto, actual)) << message_differences;
  }

  ByteString EncodeNamedQuery(local::LocalSerializer* serializer,
                              const NamedQuery& named_query) {
    return MakeByteString(serializer->EncodeNamedQuery(named_query));
  }

  void ExpectDeserializationRoundTrip(const NamedQuery& named_query,
                                      const ::firestore::NamedQuery& proto) {
    ByteString bytes = ProtobufSerialize(proto);
    StringReader reader(bytes);

    auto message = Message<firestore_NamedQuery>::TryParse(&reader);
    NamedQuery actual_named_query =
        serializer.DecodeNamedQuery(&reader, *message);

    EXPECT_OK(reader.status());
    EXPECT_EQ(named_query, actual_named_query);
  }

  std::string message_differences;
  MessageDifferencer msg_diff;
};

TEST_F(LocalSerializerTest, EncodesMutationBatch) {
  Mutation base =
      PatchMutation(Key("bar/baz"), WrapObject("a", "b"), FieldMask{Field("a")},
                    Precondition::Exists(true));

  Mutation set = testutil::SetMutation("foo/bar", Map("a", "b", "num", 1));
  Mutation patch =
      PatchMutation(Key("bar/baz"), WrapObject("a", "b", "num", 1),
                    FieldMask{Field("a")}, Precondition::Exists(true));
  Mutation del = testutil::DeleteMutation("baz/quux");

  Timestamp write_time = Timestamp::Now();
  MutationBatch model(42, write_time, {base}, {set, patch, del});

  v1::Value b_value{};
  *b_value.mutable_string_value() = "b";
  v1::Value one_value{};
  one_value.set_integer_value(1);

  v1::Write base_proto{};
  *base_proto.mutable_update()->mutable_name() =
      "projects/p/databases/d/documents/bar/baz";
  (*base_proto.mutable_update()->mutable_fields())["a"] = b_value;
  base_proto.mutable_update_mask()->add_field_paths("a");
  base_proto.mutable_current_document()->set_exists(true);

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
  *batch_proto.add_base_writes() = base_proto;
  *batch_proto.add_writes() = set_proto;
  assert(batch_proto.writes(0).update().name() ==
         "projects/p/databases/d/documents/foo/bar");
  *batch_proto.add_writes() = patch_proto;
  *batch_proto.add_writes() = del_proto;
  *batch_proto.mutable_local_write_time() = write_time_proto;

  ExpectRoundTrip(model, batch_proto);
}

TEST_F(LocalSerializerTest, EncodesDocumentAsMaybeDocument) {
  Document doc = Doc("some/path", /*version=*/42, Map("foo", "bar"));

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

  // Verify has_committed_mutations
  doc = Doc("some/path", /*version=*/42, Map("foo", "bar"),
            DocumentState::kCommittedMutations);
  maybe_doc_proto.set_has_committed_mutations(true);

  ExpectRoundTrip(doc, maybe_doc_proto, doc.type());
}

TEST_F(LocalSerializerTest, EncodesNoDocumentAsMaybeDocument) {
  NoDocument no_doc = DeletedDoc("some/path", /*version=*/42);

  ::firestore::client::MaybeDocument maybe_doc_proto;
  maybe_doc_proto.mutable_no_document()->set_name(
      "projects/p/databases/d/documents/some/path");
  maybe_doc_proto.mutable_no_document()->mutable_read_time()->set_seconds(0);
  maybe_doc_proto.mutable_no_document()->mutable_read_time()->set_nanos(42000);

  ExpectRoundTrip(no_doc, maybe_doc_proto, no_doc.type());

  // Verify has_committed_mutations
  no_doc =
      DeletedDoc("some/path", /*version=*/42, /*has_committed_mutations=*/true);
  maybe_doc_proto.set_has_committed_mutations(true);

  ExpectRoundTrip(no_doc, maybe_doc_proto, no_doc.type());
}

TEST_F(LocalSerializerTest, EncodesUnknownDocumentAsMaybeDocument) {
  UnknownDocument unknown_doc = UnknownDoc("some/path", /*version=*/42);

  ::firestore::client::MaybeDocument maybe_doc_proto;
  maybe_doc_proto.mutable_unknown_document()->set_name(
      "projects/p/databases/d/documents/some/path");
  maybe_doc_proto.mutable_unknown_document()->mutable_version()->set_seconds(0);
  maybe_doc_proto.mutable_unknown_document()->mutable_version()->set_nanos(
      42000);
  maybe_doc_proto.set_has_committed_mutations(true);

  ExpectRoundTrip(unknown_doc, maybe_doc_proto, unknown_doc.type());
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

  ::firestore::client::Target expected;
  expected.set_target_id(target_id);
  expected.set_last_listen_sequence_number(sequence_number);
  expected.mutable_snapshot_version()->set_nanos(1039000);
  expected.mutable_last_limbo_free_snapshot_version()->set_nanos(1000000);
  expected.set_resume_token(resume_token.data(), resume_token.size());
  v1::Target::QueryTarget* query_proto = expected.mutable_query();

  // Add expected collection.
  query_proto->set_parent("projects/p/databases/d/documents");
  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("room");
  *query_proto->mutable_structured_query()->add_from() = std::move(from);

  // Add default order_by.
  v1::StructuredQuery::Order order;
  order.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order.set_direction(v1::StructuredQuery::ASCENDING);
  *query_proto->mutable_structured_query()->add_order_by() = std::move(order);

  ExpectRoundTrip(target_data, expected);
}

TEST_F(LocalSerializerTest, HandlesInvalidTargetData) {
  TargetId target_id = 42;
  std::string invalid_field_path = "`";

  ::firestore::client::Target invalid_target;
  invalid_target.set_target_id(target_id);
  v1::Target::QueryTarget* query_proto = invalid_target.mutable_query();

  // Add expected collection.
  query_proto->set_parent("projects/p/databases/d/documents");
  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("room");
  *query_proto->mutable_structured_query()->add_from() = std::move(from);

  // Add invalid order_by.
  v1::StructuredQuery::Order order;
  order.mutable_field()->set_field_path(invalid_field_path);
  order.set_direction(v1::StructuredQuery::ASCENDING);
  *query_proto->mutable_structured_query()->add_order_by() = std::move(order);

  ByteString bytes = ProtobufSerialize(invalid_target);
  StringReader reader(bytes);

  auto message = Message<firestore_client_Target>::TryParse(&reader);
  serializer.DecodeTargetData(&reader, *message);
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

  ::firestore::client::Target expected;
  expected.set_target_id(target_id);
  expected.set_last_listen_sequence_number(sequence_number);
  expected.mutable_snapshot_version()->set_nanos(1039000);
  expected.mutable_last_limbo_free_snapshot_version()->set_nanos(1000000);
  expected.set_resume_token(resume_token.data(), resume_token.size());
  v1::Target::DocumentsTarget* documents_proto = expected.mutable_documents();
  documents_proto->add_documents("projects/p/databases/d/documents/room/1");

  ExpectRoundTrip(target_data, expected);
}

TEST_F(LocalSerializerTest, EncodesNamedQuery) {
  auto now = Timestamp::Now();
  Target t =
      testutil::Query("a").AddingFilter(Filter("foo", "==", 1)).ToTarget();
  BundledQuery bundle_query(t, core::LimitType::First);
  NamedQuery named_query("query-1", bundle_query, SnapshotVersion(now));

  // Constructing expected proto lite class.
  ::firestore::BundledQuery expected_bundled_query;
  expected_bundled_query.set_parent("projects/p/databases/d/documents");
  expected_bundled_query.set_limit_type(
      ::firestore::BundledQuery_LimitType_FIRST);

  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("a");
  *expected_bundled_query.mutable_structured_query()->add_from() =
      std::move(from);

  v1::StructuredQuery::FieldFilter field_filter;
  field_filter.mutable_field()->set_field_path("foo");
  field_filter.mutable_value()->set_integer_value(1);
  field_filter.set_op(
      google::firestore::v1::StructuredQuery_FieldFilter_Operator_EQUAL);
  *expected_bundled_query.mutable_structured_query()
       ->mutable_where()
       ->mutable_field_filter() = std::move(field_filter);

  v1::StructuredQuery::Order order;
  order.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order.set_direction(v1::StructuredQuery::ASCENDING);
  *expected_bundled_query.mutable_structured_query()->add_order_by() =
      std::move(order);

  ::firestore::NamedQuery expected_named_query;
  expected_named_query.set_name("query-1");
  expected_named_query.mutable_read_time()->set_seconds(now.seconds());
  expected_named_query.mutable_read_time()->set_nanos(now.nanoseconds());
  *expected_named_query.mutable_bundled_query() =
      std::move(expected_bundled_query);

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

  // Constructing expected proto lite class.
  ::firestore::BundledQuery expected_bundled_query;
  expected_bundled_query.set_parent("projects/p/databases/d/documents");
  expected_bundled_query.set_limit_type(
      ::firestore::BundledQuery_LimitType_LAST);

  expected_bundled_query.mutable_structured_query()->mutable_limit()->set_value(
      3);

  v1::StructuredQuery::CollectionSelector from;
  from.set_collection_id("a");
  *expected_bundled_query.mutable_structured_query()->add_from() =
      std::move(from);

  v1::StructuredQuery::Order order;
  order.mutable_field()->set_field_path(FieldPath::kDocumentKeyPath);
  order.set_direction(v1::StructuredQuery::ASCENDING);
  *expected_bundled_query.mutable_structured_query()->add_order_by() =
      std::move(order);

  ::firestore::NamedQuery expected_named_query;
  expected_named_query.set_name("query-1");
  expected_named_query.mutable_read_time()->set_seconds(now.seconds());
  expected_named_query.mutable_read_time()->set_nanos(now.nanoseconds());
  *expected_named_query.mutable_bundled_query() =
      std::move(expected_bundled_query);

  ExpectRoundTrip(named_query, expected_named_query);
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
