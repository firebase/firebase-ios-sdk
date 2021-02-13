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

#include "Firestore/Protos/cpp/firestore/bundle.pb.h"
#include "Firestore/Protos/cpp/firestore/local/maybe_document.pb.h"
#include "Firestore/Protos/cpp/google/firestore/v1/document.pb.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/local/local_serializer.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/test/unit/nanopb/nanopb_testing.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "google/protobuf/util/json_util.h"
#include "google/protobuf/util/message_differencer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace bundle {
namespace {

using google::protobuf::util::MessageDifferencer;
using google::protobuf::util::MessageToJsonString;
using ProtoBundledDocumentMetadata = ::firestore::BundledDocumentMetadata;
using ProtoBundleElement = ::firestore::BundleElement;
using ProtoBundleMetadata = ::firestore::BundleMetadata;
using ProtoDocument = ::google::firestore::v1::Document;
using ProtoMaybeDocument = ::firestore::client::MaybeDocument;
using ProtoNamedQuery = ::firestore::NamedQuery;
using ProtoValue = ::google::firestore::v1::Value;
using model::DatabaseId;

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

  std::string AddNamedQuery(const ProtoNamedQuery & data) {
    std::string json;
    ProtoBundleElement element;
    *element.mutable_named_query() = data;
    MessageToJsonString(element, &json);
    elements_.push_back(json);
    return json;
  }

  std::string AddDocumentMetadata(const ProtoBundledDocumentMetadata & data) {
    std::string json;
    ProtoBundleElement element;
    *element.mutable_document_metadata() = data;
    MessageToJsonString(element, &json);
    elements_.push_back(json);
    return json;
  }

  std::string AddDocument(const ProtoDocument & data) {
    std::string json;
    ProtoBundleElement element;
    *element.mutable_document() = data;
    MessageToJsonString(element, &json);
    elements_.push_back(json);
    return json;
  }

  std::string BuildBundle(const std::string& bundle_id, model::SnapshotVersion create_time, int32_t documents) {
    std::string bundle;
    for(const auto& element: elements_) {
      auto bytes_length_string = std::to_string(element.size());
      bundle.append(bytes_length_string);
      bundle.append(element);
    }

    ProtoBundleMetadata metadata;
    metadata.set_id(bundle_id);
    metadata.set_version(1);
    metadata.set_total_documents(documents);
    metadata.mutable_create_time()->set_nanos(create_time.timestamp().nanoseconds());
    metadata.mutable_create_time()->set_seconds(create_time.timestamp().seconds());
    metadata.set_total_bytes(bundle.size());
    ProtoBundleElement element;
    *element.mutable_metadata() = metadata;

    std::string metadata_str;
    MessageToJsonString(element, &metadata_str);

    return std::to_string(metadata_str.size()) + metadata_str + bundle;
  }

  ProtoNamedQuery LimitQuery() {
    core::Query original = testutil::Query("bundles/docs/colls")
        .AddingFilter(testutil::Filter("foo", "==", 3))
        .AddingOrderBy(testutil::OrderBy("foo"))
        .WithLimitToFirst(1);
    BundledQuery bundled_query(original.ToTarget(), core::LimitType::First);
    NamedQuery named_query("limitQuery", bundled_query, testutil::Version(1000));
    nanopb::ByteString bytes =
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
    NamedQuery named_query("limitToLastQuery", bundled_query, testutil::Version(1111));
    nanopb::ByteString bytes =
        nanopb::MakeByteString(local_serializer.EncodeNamedQuery(named_query));
    return nanopb::ProtobufParse<ProtoNamedQuery>(bytes);
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
    document.mutable_update_time()->set_nanos(version.timestamp().nanoseconds());
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

  std::vector<std::unique_ptr<BundleElement>> VerifyFullBundleParsed(BundleReader& reader,
                                                    const std::string& expected_id,
                                                    model::SnapshotVersion version) {
    std::vector<std::unique_ptr<BundleElement>> result;
    auto actual_metadata = reader.GetBundleMetadata();
    EXPECT_EQ(actual_metadata.bundle_id(), expected_id);
    EXPECT_EQ(actual_metadata.version(), 1);
    EXPECT_EQ(actual_metadata.create_time(), version);
    // result.push_back(absl::make_unique<BundleMetadata>(actual_metadata));

    // The bundle metadata is not considered part of the bytes read. Instead, it encodes the
    // expected size of all elements.
    // EXPECT_EQ(reader.BytesRead(), 0);

    std::unique_ptr<BundleElement> next_element = reader.GetNextElement();
    while (next_element) {
      result.push_back(std::move(next_element));
      next_element = reader.GetNextElement();
    }

    // EXPECT_EQ(reader.BytesRead(), actual_metadata.total_bytes());

    return result;
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

TEST_F(BundleReaderTest, ReadsQueryAndDocument) {
  AddNamedQuery(LimitQuery());
  AddNamedQuery(LimitToLastQuery());
  AddDocumentMetadata(DocumentMetadata1());
  AddDocument(Document1());

  const auto& bundle = BuildBundle("bundle-1", testutil::Version(6000004000), 1);
  std::cout << bundle << "\n";
  BundleReader reader(bundle_serializer, absl::make_unique<std::istringstream>(bundle));

  auto elements = VerifyFullBundleParsed(reader, "bundle-1", testutil::Version(6000004000));

  EXPECT_EQ(elements.size(), 4);
  EXPECT_EQ(elements[0]->ElementType(), BundleElementType::Metadata);
}

}  //  namespace
}  //  namespace bundle
}  //  namespace firestore
}  //  namespace firebase
