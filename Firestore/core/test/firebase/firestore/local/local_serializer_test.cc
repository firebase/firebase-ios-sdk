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
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "google/protobuf/util/message_differencer.h"
#include "gtest/gtest.h"

namespace local = firebase::firestore::local;
namespace remote = firebase::firestore::remote;
namespace v1beta1 = google::firestore::v1beta1;

using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::MaybeDocument;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::testutil::Doc;
using firebase::firestore::util::Status;
using firebase::firestore::util::StatusOr;
using google::protobuf::util::MessageDifferencer;

// TODO(rsgowman): This is copied from remote/serializer_tests.cc. Refactor.
#define EXPECT_OK(status) EXPECT_TRUE(StatusOk(status))

class LocalSerializerTest : public ::testing::Test {
 public:
  LocalSerializerTest()
      : remote_serializer(kDatabaseId), serializer(remote_serializer) {
    msg_diff.ReportDifferencesToString(&message_differences);
  }

  const DatabaseId kDatabaseId{"p", "d"};
  remote::Serializer remote_serializer;
  local::LocalSerializer serializer;

  void ExpectRoundTrip(const MaybeDocument& model,
                       const firestore::client::MaybeDocument& proto,
                       MaybeDocument::Type type) {
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
  // TODO(rsgowman): This is copied from remote/serializer_tests.cc. Refactor.
  testing::AssertionResult StatusOk(const Status& status) {
    if (!status.ok()) {
      return testing::AssertionFailure()
             << "Status should have been ok, but instead contained "
             << status.ToString();
    }
    return testing::AssertionSuccess();
  }

  // TODO(rsgowman): This is copied from remote/serializer_tests.cc. Refactor.
  template <typename T>
  testing::AssertionResult StatusOk(const StatusOr<T>& status) {
    return StatusOk(status.status());
  }

 private:
  void ExpectSerializationRoundTrip(
      const MaybeDocument& model,
      const firestore::client::MaybeDocument& proto,
      MaybeDocument::Type type) {
    EXPECT_EQ(type, model.type());
    std::vector<uint8_t> bytes = EncodeMaybeDocument(&serializer, model);
    firestore::client::MaybeDocument actual_proto;
    bool ok = actual_proto.ParseFromArray(bytes.data(),
                                          static_cast<int>(bytes.size()));
    EXPECT_TRUE(ok);
    EXPECT_TRUE(msg_diff.Compare(proto, actual_proto)) << message_differences;
  }

  void ExpectDeserializationRoundTrip(
      const MaybeDocument& model,
      const firestore::client::MaybeDocument& proto,
      MaybeDocument::Type type) {
    std::vector<uint8_t> bytes(proto.ByteSizeLong());
    bool status =
        proto.SerializeToArray(bytes.data(), static_cast<int>(bytes.size()));
    EXPECT_TRUE(status);
    StatusOr<std::unique_ptr<MaybeDocument>> actual_model_status =
        serializer.DecodeMaybeDocument(bytes);
    EXPECT_OK(actual_model_status);
    std::unique_ptr<MaybeDocument> actual_model =
        std::move(actual_model_status).ValueOrDie();
    EXPECT_EQ(type, actual_model->type());
    EXPECT_EQ(model, *actual_model);
  }

  std::vector<uint8_t> EncodeMaybeDocument(local::LocalSerializer* serializer,
                                           const MaybeDocument& maybe_doc) {
    std::vector<uint8_t> bytes;
    Status status = serializer->EncodeMaybeDocument(maybe_doc, &bytes);
    EXPECT_OK(status);
    return bytes;
  }

  std::string message_differences;
  MessageDifferencer msg_diff;
};

TEST_F(LocalSerializerTest, EncodesDocumentAsMaybeDocument) {
  Document doc = Doc("some/path", /*version=*/42);

  firestore::client::MaybeDocument maybe_doc_proto;
  maybe_doc_proto.mutable_document()->set_name(
      "projects/p/databases/d/documents/some/path");
  maybe_doc_proto.mutable_document()->mutable_update_time()->set_seconds(0);
  maybe_doc_proto.mutable_document()->mutable_update_time()->set_nanos(42000);

  ExpectRoundTrip(doc, maybe_doc_proto, doc.type());
}
