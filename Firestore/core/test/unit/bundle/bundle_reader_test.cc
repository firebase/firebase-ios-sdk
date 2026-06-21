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

#include "Firestore/core/src/bundle/bundle_reader.h"

#include <memory>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/Protos/cpp/firestore/bundle.pb.h"
#include "Firestore/Protos/cpp/firestore/local/maybe_document.pb.h"
#include "Firestore/Protos/cpp/google/firestore/v1/document.pb.h"
#include "Firestore/core/src/bundle/named_query.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/local/local_serializer.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/byte_stream_cpp.h"
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
using ProtoBundledDocumentMetadata = ::firestore::BundledDocumentMetadata;
using ProtoBundleElement = ::firestore::BundleElement;
using ProtoBundleMetadata = ::firestore::BundleMetadata;
using ProtoDocument = ::google::firestore::v1::Document;
using ProtoMaybeDocument = ::firestore::client::MaybeDocument;
using ProtoNamedQuery = ::firestore::NamedQuery;
using ProtoValue = ::google::firestore::v1::Value;
using model::DatabaseId;
using nanopb::ProtobufParse;
using util::ByteStream;
using util::ByteStreamCpp;

void MessageToJsonString(const Message& message, std::string* output) {
  auto status = google::protobuf::util::MessageToJsonString(message, output);
  HARD_ASSERT(status.ok());
}

class BundleReaderTest : public ::testing::Test {
 public:
  BundleReaderTest()
      : remote_serializer(DatabaseId("p", "default")),
        local_serializer(remote_serializer),
        bundle_serializer(remote_serializer) {
    msg_diff_.ReportDifferencesToString(&message_differences);
  }

  static std::string FullPath(const std::string& path) {
    return "projects/p/databases/default/documents/" + path;
  }

  std::string AddNamedQuery(const ProtoNamedQuery& data) {
    std::string json;
    ProtoBundleElement element;
    *element.mutable_named_query() = data;
    MessageToJsonString(element, &json);
    elements_.push_back(json);
    return json;
  }

  std::string AddDocumentMetadata(const ProtoBundledDocumentMetadata& data) {
    std::string json;
    ProtoBundleElement element;
    *element.mutable_document_metadata() = data;
    MessageToJsonString(element, &json);
    elements_.push_back(json);
    return json;
  }

  std::string AddDocument(const ProtoDocument& data) {
    std::string json;
    ProtoBundleElement element;
    *element.mutable_document() = data;
    MessageToJsonString(element, &json);
    elements_.push_back(json);
    return json;
  }

  std::string BuildBundle(const std::string& bundle_id,
                          model::SnapshotVersion create_time,
                          int32_t documents) {
    std::string bundle;
    for (const auto& element : elements_) {
      auto bytes_length_string = std::to_string(element.size());
      bundle.append(bytes_length_string);
      bundle.append(element);
    }

    ProtoBundleMetadata metadata;
    metadata.set_id(bundle_id);
    metadata.set_version(1);
    metadata.set_total_documents(documents);
    metadata.mutable_create_time()->set_nanos(
        create_time.timestamp().nanoseconds());
    metadata.mutable_create_time()->set_seconds(
        create_time.timestamp().seconds());
    metadata.set_total_bytes(bundle.size());
    ProtoBundleElement element;
    *element.mutable_metadata() = metadata;

    std::string metadata_str;
    MessageToJsonString(element, &metadata_str);

    return std::to_string(metadata_str.size()) + metadata_str + bundle;
  }

  std::unique_ptr<util::ByteStream> ToByteStream(const std::string& bundle) {
    auto bundle_istream = absl::make_unique<std::stringstream>(bundle);
    return absl::make_unique<ByteStreamCpp>(
        ByteStreamCpp(std::move(bundle_istream)));
  }

  ProtoNamedQuery LimitQuery() {
    core::Query original = testutil::Query("bundles/docs/colls")
                               .AddingFilter(testutil::Filter("foo", "==", 3))
                               .AddingOrderBy(testutil::OrderBy("foo"))
                               .WithLimitToFirst(1);
    BundledQuery bundled_query(original.ToTarget(), core::LimitType::First);
    NamedQuery named_query("limitQuery", bundled_query,
                           testutil::Version(1000));
    auto bytes =
        nanopb::MakeByteString(local_serializer.EncodeNamedQuery(named_query));
    return nanopb::ProtobufParse<ProtoNamedQuery>(bytes);
  }

  ProtoNamedQuery LimitToLastQuery() {
    // Use a LimitToFirst query to avoid order flipping of `ToTarget()`.
    core::Query original = testutil::Query("bundles/docs/colls")
                               .AddingFilter(testutil::Filter("foo", "==", 3))
                               .AddingOrderBy(testutil::OrderBy("foo", "desc"))
                               .WithLimitToFirst(1);
    BundledQuery bundled_query(original.ToTarget(), core::LimitType::Last);
    NamedQuery named_query("limitToLastQuery", bundled_query,
                           testutil::Version(1111));
    auto bytes =
        nanopb::MakeByteString(local_serializer.EncodeNamedQuery(named_query));
    return nanopb::ProtobufParse<ProtoNamedQuery>(bytes);
  }

  ProtoBundledDocumentMetadata DeletedDocumentMetadata() {
    ProtoBundledDocumentMetadata metadata;
    metadata.set_name(FullPath("bundle/docs/colls/deleted-doc"));
    metadata.set_exists(false);
    auto version = testutil::Version(42424242);
    metadata.mutable_read_time()->set_seconds(version.timestamp().seconds());
    metadata.mutable_read_time()->set_nanos(version.timestamp().nanoseconds());

    return metadata;
  }

  ProtoBundledDocumentMetadata DocumentMetadata1() {
    ProtoBundledDocumentMetadata metadata;
    metadata.set_name(FullPath("bundle/docs/colls/doc-1"));
    metadata.set_exists(true);
    auto version = testutil::Version(99999999999);
    metadata.mutable_read_time()->set_seconds(version.timestamp().seconds());
    metadata.mutable_read_time()->set_nanos(version.timestamp().nanoseconds());
    metadata.mutable_queries()->Add("limitQuery");
    metadata.mutable_queries()->Add("limitToLastQuery");

    return metadata;
  }

  static ProtoDocument Document1() {
    ProtoDocument document;
    document.set_name(FullPath("bundle/docs/colls/doc-1"));
    auto version = testutil::Version(99999999999);
    document.mutable_update_time()->set_nanos(
        version.timestamp().nanoseconds());
    document.mutable_update_time()->set_seconds(version.timestamp().seconds());
    ProtoValue value1;
    value1.set_integer_value(12345);
    ProtoValue value2;
    value2.set_string_value("\"\\0\\ud7ff\\ue000\\uffff\", \"(╯°□°）╯︵ ┻━┻\"");
    ProtoValue value3;
    value3.set_null_value(google::protobuf::NULL_VALUE);
    document.mutable_fields()->insert({"foo", value1});
    document.mutable_fields()->insert({"bar", value2});
    document.mutable_fields()->insert({"nValue", value3});

    return document;
  }

  static ProtoBundledDocumentMetadata DocumentMetadata2() {
    ProtoBundledDocumentMetadata metadata;
    metadata.set_name(FullPath("bundle/docs/colls/doc-2"));
    metadata.set_exists(true);
    auto version = testutil::Version(11111);
    metadata.mutable_read_time()->set_seconds(version.timestamp().seconds());
    metadata.mutable_read_time()->set_nanos(version.timestamp().nanoseconds());
    metadata.mutable_queries()->Add("limitQuery");

    return metadata;
  }

  static ProtoDocument Document2() {
    ProtoDocument document;
    document.set_name(FullPath("bundle/docs/colls/doc-2"));
    auto version = testutil::Version(11111);
    document.mutable_update_time()->set_nanos(
        version.timestamp().nanoseconds());
    document.mutable_update_time()->set_seconds(version.timestamp().seconds());
    ProtoValue value1;
    value1.set_integer_value(12345);
    ProtoValue value2;
    value2.set_string_value("okok");
    ProtoValue value3;
    value3.set_null_value(google::protobuf::NULL_VALUE);
    ProtoValue value4;
    value4.mutable_array_value();
    ProtoValue value5;
    value5.mutable_map_value();
    document.mutable_fields()->insert({"\0\ud7ff\ue000\uffff\"", value1});
    document.mutable_fields()->insert({"\"(╯°□°）╯︵ ┻━┻\"", value2});
    document.mutable_fields()->insert({"nValue", value3});
    document.mutable_fields()->insert({"emptyArray", value4});
    document.mutable_fields()->insert({"emptyMap", value5});

    return document;
  }

  static ProtoDocument LargeDocument2() {
    auto document = Document2();
    for (int i = 0; i < 500; ++i) {
      ProtoValue value;
      value.set_bytes_value(std::string(10, 'x'));
      document.mutable_fields()->insert(
          {"foo_field_" + std::to_string(i), value});
    }
    return document;
  }

  std::vector<std::unique_ptr<BundleElement>> VerifyFullBundleParsed(
      BundleReader& reader,
      const std::string& expected_id,
      model::SnapshotVersion version) {
    std::vector<std::unique_ptr<BundleElement>> result;
    auto actual_metadata = reader.GetBundleMetadata();
    EXPECT_OK(reader.reader_status());
    EXPECT_EQ(actual_metadata.bundle_id(), expected_id);
    EXPECT_EQ(actual_metadata.version(), 1);
    EXPECT_EQ(actual_metadata.create_time(), version);

    // The bundle metadata is not considered part of the bytes read. Instead, it
    // encodes the expected size of all elements.
    EXPECT_EQ(reader.bytes_read(), 0);

    std::unique_ptr<BundleElement> next_element = reader.GetNextElement();
    while (next_element) {
      EXPECT_OK(reader.reader_status());
      result.push_back(std::move(next_element));
      next_element = reader.GetNextElement();
    }

    EXPECT_EQ(reader.bytes_read(), actual_metadata.total_bytes());

    return result;
  }

  void VerifyNamedQueryEncodesToOriginal(const NamedQuery& actual_read,
                                         const ProtoNamedQuery& original) {
    EXPECT_EQ(actual_read.element_type(), BundleElement::Type::NamedQuery);
    auto actual_proto = local_serializer.EncodeNamedQuery(actual_read);
    auto bytes = nanopb::MakeByteString(actual_proto);
    EXPECT_TRUE(
        msg_diff_.Compare(ProtobufParse<ProtoNamedQuery>(bytes), original))
        << message_differences;
    message_differences.clear();
  }

  void VerifyDocumentEncodesToOriginal(const BundleDocument& actual_read,
                                       const ProtoDocument& original) {
    EXPECT_EQ(actual_read.element_type(), BundleElement::Type::Document);
    auto actual_proto =
        local_serializer.EncodeMaybeDocument(actual_read.document());
    auto bytes = nanopb::MakeByteString(actual_proto);
    ProtoMaybeDocument maybe_document;
    *maybe_document.mutable_document() = original;
    EXPECT_TRUE(msg_diff_.Compare(ProtobufParse<ProtoMaybeDocument>(bytes),
                                  maybe_document))
        << message_differences;
    message_differences.clear();
  }

  static void VerifyDocumentMetadataEquals(
      const BundledDocumentMetadata& actual_read,
      const ProtoBundledDocumentMetadata& original) {
    EXPECT_EQ(actual_read.element_type(),
              BundleElement::Type::DocumentMetadata);
    EXPECT_EQ(FullPath(actual_read.key().ToString()), original.name());
    EXPECT_EQ(actual_read.read_time(),
              model::SnapshotVersion(Timestamp(original.read_time().seconds(),
                                               original.read_time().nanos())));
    EXPECT_EQ(actual_read.exists(), original.exists());
    EXPECT_EQ(actual_read.queries(),
              std::vector<std::string>(original.queries().begin(),
                                       original.queries().end()));
  }

  remote::Serializer remote_serializer;
  local::LocalSerializer local_serializer;
  bundle::BundleSerializer bundle_serializer;

 protected:
  MessageDifferencer msg_diff_;
  std::string message_differences;

 private:
  std::vector<std::string> elements_;
};

TEST_F(BundleReaderTest, ReadsEmptyBundle) {
  ProtoBundleMetadata metadata;
  metadata.set_id("bundle-1");
  metadata.set_version(1);
  metadata.set_total_documents(0);
  metadata.mutable_create_time();  // No seconds/nanos
  metadata.set_total_bytes(0);
  ProtoBundleElement element;
  *element.mutable_metadata() = metadata;

  std::string metadata_str;
  MessageToJsonString(element, &metadata_str);
  std::string bundle = std::to_string(metadata_str.size()) + metadata_str;

  BundleReader reader(bundle_serializer, ToByteStream(bundle));
  VerifyFullBundleParsed(reader, "bundle-1", testutil::Version(0));
}

TEST_F(BundleReaderTest, ReadsQueryAndDocument) {
  AddNamedQuery(LimitQuery());
  AddNamedQuery(LimitToLastQuery());
  AddDocumentMetadata(DocumentMetadata1());
  AddDocument(Document1());

  const auto& bundle =
      BuildBundle("bundle-1", testutil::Version(6000004000), 1);
  BundleReader reader(bundle_serializer, ToByteStream(bundle));

  std::vector<std::unique_ptr<BundleElement>> elements =
      VerifyFullBundleParsed(reader, "bundle-1", testutil::Version(6000004000));

  EXPECT_EQ(elements.size(), 4);
  {
    SCOPED_TRACE("LimitQuery");
    VerifyNamedQueryEncodesToOriginal(
        *static_cast<NamedQuery*>(elements[0].get()), LimitQuery());
  }
  {
    SCOPED_TRACE("LimitToLastQuery");
    VerifyNamedQueryEncodesToOriginal(
        *static_cast<NamedQuery*>(elements[1].get()), LimitToLastQuery());
  }
  VerifyDocumentMetadataEquals(
      *static_cast<BundledDocumentMetadata*>(elements[2].get()),
      DocumentMetadata1());
  VerifyDocumentEncodesToOriginal(
      *static_cast<BundleDocument*>(elements[3].get()), Document1());
}

TEST_F(BundleReaderTest, ReadsQueryAndDocumentWithUnexpectedOrder) {
  AddDocumentMetadata(DocumentMetadata1());
  AddDocument(Document1());
  AddNamedQuery(LimitQuery());
  AddDocumentMetadata(DocumentMetadata2());
  AddDocument(Document2());

  const auto& bundle =
      BuildBundle("bundle-1", testutil::Version(6000004000), 2);
  BundleReader reader(bundle_serializer, ToByteStream(bundle));

  std::vector<std::unique_ptr<BundleElement>> elements =
      VerifyFullBundleParsed(reader, "bundle-1", testutil::Version(6000004000));

  EXPECT_EQ(elements.size(), 5);
  {
    SCOPED_TRACE("DocumentMetadata1");
    VerifyDocumentMetadataEquals(
        *static_cast<BundledDocumentMetadata*>(elements[0].get()),
        DocumentMetadata1());
  }
  {
    SCOPED_TRACE("Document1");
    VerifyDocumentEncodesToOriginal(
        *static_cast<BundleDocument*>(elements[1].get()), Document1());
  }
  {
    SCOPED_TRACE("LimitQuery");
    VerifyNamedQueryEncodesToOriginal(
        *static_cast<NamedQuery*>(elements[2].get()), LimitQuery());
  }
  {
    SCOPED_TRACE("DocumentMetadata2");
    VerifyDocumentMetadataEquals(
        *static_cast<BundledDocumentMetadata*>(elements[3].get()),
        DocumentMetadata2());
  }
  {
    SCOPED_TRACE("Document2");
    VerifyDocumentEncodesToOriginal(
        *static_cast<BundleDocument*>(elements[4].get()), Document2());
  }
}

TEST_F(BundleReaderTest, ReadsWithoutNamedQuery) {
  AddDocumentMetadata(DocumentMetadata1());
  AddDocument(Document1());

  const auto& bundle =
      BuildBundle("bundle-1", testutil::Version(6000004000), 1);
  BundleReader reader(bundle_serializer, ToByteStream(bundle));

  std::vector<std::unique_ptr<BundleElement>> elements =
      VerifyFullBundleParsed(reader, "bundle-1", testutil::Version(6000004000));

  EXPECT_EQ(elements.size(), 2);
  VerifyDocumentMetadataEquals(
      *static_cast<BundledDocumentMetadata*>(elements[0].get()),
      DocumentMetadata1());
  VerifyDocumentEncodesToOriginal(
      *static_cast<BundleDocument*>(elements[1].get()), Document1());
}

TEST_F(BundleReaderTest, ReadsWithDeletedDocument) {
  AddDocumentMetadata(DeletedDocumentMetadata());
  AddDocumentMetadata(DocumentMetadata2());
  AddDocument(Document2());

  const auto& bundle =
      BuildBundle("bundle-1", testutil::Version(6000004000), 2);
  BundleReader reader(bundle_serializer, ToByteStream(bundle));

  std::vector<std::unique_ptr<BundleElement>> elements =
      VerifyFullBundleParsed(reader, "bundle-1", testutil::Version(6000004000));

  EXPECT_EQ(elements.size(), 3);
  VerifyDocumentMetadataEquals(
      *static_cast<BundledDocumentMetadata*>(elements[0].get()),
      DeletedDocumentMetadata());
  VerifyDocumentMetadataEquals(
      *static_cast<BundledDocumentMetadata*>(elements[1].get()),
      DocumentMetadata2());
  VerifyDocumentEncodesToOriginal(
      *static_cast<BundleDocument*>(elements[2].get()), Document2());
}

TEST_F(BundleReaderTest, ReadsWithoutDocumentOrQuery) {
  const auto& bundle =
      BuildBundle("bundle-1", testutil::Version(6000004000), 0);
  BundleReader reader(bundle_serializer, ToByteStream(bundle));

  std::vector<std::unique_ptr<BundleElement>> elements =
      VerifyFullBundleParsed(reader, "bundle-1", testutil::Version(6000004000));

  EXPECT_EQ(elements.size(), 0);
}

TEST_F(BundleReaderTest, ReadsLargeDocument) {
  AddDocumentMetadata(DocumentMetadata2());
  AddDocument(LargeDocument2());

  const auto& bundle =
      BuildBundle("bundle-1", testutil::Version(6000004000), 0);
  BundleReader reader(bundle_serializer, ToByteStream(bundle));

  std::vector<std::unique_ptr<BundleElement>> elements =
      VerifyFullBundleParsed(reader, "bundle-1", testutil::Version(6000004000));

  VerifyDocumentMetadataEquals(
      *static_cast<BundledDocumentMetadata*>(elements[0].get()),
      DocumentMetadata2());
  VerifyDocumentEncodesToOriginal(
      *static_cast<BundleDocument*>(elements[1].get()), LargeDocument2());
}

TEST_F(BundleReaderTest, FailsWithBadLengthPrefix) {
  const auto& bundle =
      BuildBundle("bundle-1", testutil::Version(6000004000), 0);
  for (int l = 1; l < 4; ++l) {
    auto bad_prefix = bundle.substr(l);
    BundleReader reader(bundle_serializer, ToByteStream(bad_prefix));

    EXPECT_EQ(reader.GetBundleMetadata(), BundleMetadata());
    EXPECT_EQ(reader.GetNextElement(), nullptr);

    EXPECT_NOT_OK(reader.reader_status());
  }
}

TEST_F(BundleReaderTest, FailsWhenSecondElementMissing) {
  const auto& bundle =
      BuildBundle("bundle-1", testutil::Version(6000004000), 0);
  BundleReader reader(bundle_serializer, ToByteStream(bundle + "foo"));

  // Metadata can still be read because it is complete.
  EXPECT_EQ(reader.GetBundleMetadata(),
            BundleMetadata("bundle-1", 1, testutil::Version(6000004000), 0, 0));
  EXPECT_EQ(reader.GetNextElement(), nullptr);

  EXPECT_NOT_OK(reader.reader_status());
}

TEST_F(BundleReaderTest, FailsWhenNotEnoughDataCanBeRead) {
  const auto& bundle =
      BuildBundle("bundle-1", testutil::Version(6000004000), 0);
  BundleReader reader(bundle_serializer, ToByteStream("1" + bundle));

  EXPECT_EQ(reader.GetBundleMetadata(), BundleMetadata());
  EXPECT_EQ(reader.GetNextElement(), nullptr);
  EXPECT_NOT_OK(reader.reader_status());
}

TEST_F(BundleReaderTest, FailsWhenFirstElementIsNotBundleMetadata) {
  AddDocumentMetadata(DocumentMetadata1());
  AddDocument(Document1());

  const auto& bundle =
      BuildBundle("bundle-1", testutil::Version(6000004000), 0);
  auto found = bundle.find("documentMetadata");
  auto metadata_closing_bracket = bundle.find_last_of('}', found);
  auto bundle_without_meta =
      bundle.substr(metadata_closing_bracket + 1, bundle.size());
  BundleReader reader(bundle_serializer, ToByteStream(bundle_without_meta));

  EXPECT_EQ(reader.GetBundleMetadata(), BundleMetadata());
  EXPECT_EQ(reader.GetNextElement(), nullptr);

  EXPECT_NOT_OK(reader.reader_status());
}

// Simulate a corruption by inserting a char in the bundle, and verifies it
// reports failure properly, not crashing.
TEST_F(BundleReaderTest, FailsWhenBundleIsSomehowCorrupted) {
  AddDocumentMetadata(DocumentMetadata1());
  AddDocument(Document1());
  AddNamedQuery(LimitQuery());
  AddDocumentMetadata(DocumentMetadata2());
  AddDocument(Document2());

  const auto& bundle =
      BuildBundle("bundle-1", testutil::Version(6000004000), 0);

  for (size_t i = 0; i < bundle.size(); ++i) {
    std::string copy(bundle);
    copy.insert(i, "1");
    BundleReader reader(bundle_serializer, ToByteStream(copy));
    while (reader.GetNextElement() != nullptr) {
    }
    EXPECT_NOT_OK(reader.reader_status());
  }
}

}  //  namespace
}  //  namespace bundle
}  //  namespace firestore
}  //  namespace firebase
