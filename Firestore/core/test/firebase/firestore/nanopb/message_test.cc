/*
 * Copyright 2019 Google
 *
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

#include <cstdint>
#include <utility>
#include <vector>

#include "Firestore/Protos/nanopb/google/firestore/v1/firestore.nanopb.h"
#include "Firestore/core/src/firebase/firestore/nanopb/message.h"
#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_util.h"
#include "Firestore/core/src/firebase/firestore/nanopb/writer.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_nanopb.h"
#include "Firestore/core/test/firebase/firestore/util/status_testing.h"
#include "gmock/gmock.h"
#include "grpcpp/impl/codegen/grpc_library.h"
#include "grpcpp/support/byte_buffer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace nanopb {
namespace {

using remote::ByteBufferReader;
using remote::ByteBufferWriter;
using ::testing::MatchesRegex;

// This proto is chosen mostly because it's relatively small but still has some
// dynamically-allocated members.
using Proto = google_firestore_v1_WriteResponse;
using TestMessage = Message<Proto>;

class MessageTest : public testing::Test {
 public:
  grpc::ByteBuffer GoodProto() const {
    TestMessage message;

    // A couple of fields should be enough -- these tests are primarily
    // concerned with ownership, not parsing.
    message->stream_id = MakeBytesArray("stream_id");
    message->stream_token = MakeBytesArray("stream_token");

    ByteBufferWriter writer;
    writer.Write(message.fields(), message.get());
    return writer.Release();
  }

  grpc::ByteBuffer BadProto() const {
    return {};
  }

 private:
  // Note: gRPC slice will crash upon destruction if gRPC library hasn't been
  // initialized, which is normally done by inheriting from this class (which
  // does initialization in its constructor).
  grpc::GrpcLibraryCodegen grpc_initializer_;
};

TEST_F(MessageTest, Move) {
  ByteBufferReader reader{GoodProto()};
  auto message1 = TestMessage::TryParse(&reader);
  ASSERT_OK(reader.status());
  TestMessage message2 = std::move(message1);
  EXPECT_EQ(message1.get(), nullptr);
  EXPECT_NE(message2.get(), nullptr);
  // This shouldn't result in a leak or double deletion; Address Sanitizer
  // should be able to verify that.
}

TEST_F(MessageTest, ParseFailure) {
  ByteBufferReader reader{BadProto()};
  auto message = TestMessage::TryParse(&reader);
  EXPECT_NOT_OK(reader.status());
}

TEST_F(MessageTest, PrintsInt) {
  Message<firestore_client_WriteBatch> m;
  m->batch_id = 123;

  EXPECT_THAT(m.ToString(), MatchesRegex(
                                R"(<WriteBatch 0x[0-9A-Fa-f]+>: {
  batch_id: 123
})"));
}

TEST_F(MessageTest, PrintsBool) {
  Message<firestore_client_MaybeDocument> m;
  m->has_committed_mutations = true;

  EXPECT_THAT(m.ToString(), MatchesRegex(
                                R"(<MaybeDocument 0x[0-9A-Fa-f]+>: {
  has_committed_mutations: true
})"));
}

TEST_F(MessageTest, PrintsString) {
  Message<firestore_client_MutationQueue> m;
  m->last_stream_token = MakeBytesArray("Abc123");

  EXPECT_THAT(m.ToString(), MatchesRegex(
                                R"(<MutationQueue 0x[0-9A-Fa-f]+>: {
  last_stream_token: "Abc123"
})"));
}

TEST_F(MessageTest, PrintsBytes) {
  Message<firestore_client_MutationQueue> m;
  m->last_stream_token = MakeBytesArray("\001\002\003");

  EXPECT_THAT(m.ToString(), MatchesRegex(
                                R"(<MutationQueue 0x[0-9A-Fa-f]+>: {
  last_stream_token: "\\001\\002\\003"
})"));
}

TEST_F(MessageTest, PrintsSubmessages) {
  Message<firestore_client_Target> m;
  m->snapshot_version.seconds = 123;
  m->snapshot_version.nanos = 456;

  EXPECT_THAT(m.ToString(), MatchesRegex(
                                R"(<Target 0x[0-9A-Fa-f]+>: {
  snapshot_version {
    seconds: 123
    nanos: 456
  }
})"));
}

TEST_F(MessageTest, PrintsArraysOfPrimitives) {
  Message<google_firestore_v1_Target_DocumentsTarget> m;

  m->documents_count = 2;
  m->documents = MakeArray<pb_bytes_array_t*>(m->documents_count);
  m->documents[0] = MakeBytesArray("doc1");
  m->documents[1] = MakeBytesArray("doc2");

  EXPECT_THAT(m.ToString(), MatchesRegex(
                                R"(<DocumentsTarget 0x[0-9A-Fa-f]+>: {
  documents: "doc1"
  documents: "doc2"
})"));
}

TEST_F(MessageTest, PrintsArraysOfObjects) {
  Message<google_firestore_v1_ListenRequest> m;

  m->labels_count = 2;
  m->labels =
      MakeArray<google_firestore_v1_ListenRequest_LabelsEntry>(m->labels_count);

  m->labels[0].key = MakeBytesArray("key1");
  m->labels[0].value = MakeBytesArray("value1");
  m->labels[1].key = MakeBytesArray("key2");
  m->labels[1].value = MakeBytesArray("value2");

  EXPECT_THAT(m.ToString(), MatchesRegex(
                                R"(<ListenRequest 0x[0-9A-Fa-f]+>: {
  labels {
    key: "key1"
    value: "value1"
  }
  labels {
    key: "key2"
    value: "value2"
  }
})"));
}

TEST_F(MessageTest, PrintsNestedSubmessages) {
}

TEST_F(MessageTest, PrintsOneofs) {
}

TEST_F(MessageTest, PrintsOptionals) {
  Message<google_firestore_v1_Write> m;

  auto& mask = m->update_mask;
  mask.field_paths_count = 2;
  mask.field_paths = MakeArray<pb_bytes_array_t*>(mask.field_paths_count);
  mask.field_paths[0] = MakeBytesArray("abc");
  mask.field_paths[1] = MakeBytesArray("def");

  // `has_update_mask` is false, so `update_mask` shouldn't be printed.
  // Note that normally setting `update_mask` without setting `has_update_mask`
  // to true shouldn't happen.
  EXPECT_THAT(m.ToString(), MatchesRegex("<Write 0x[0-9A-Fa-f]+>: {\n}"));

  m->has_update_mask = true;
  EXPECT_THAT(m.ToString(), MatchesRegex(
                                R"(<Write 0x[0-9A-Fa-f]+>: {
  update_mask {
    field_paths: "abc"
    field_paths: "def"
  }
})"));
}

TEST_F(MessageTest, PrintingDoesNotOmitsNestedUnsetFields) {
}

TEST_F(MessageTest, PrintsEmptyMessageIfRoot) {
  Message<google_firestore_v1_Write> m;
  EXPECT_THAT(m.ToString(), MatchesRegex("<Write 0x[0-9A-Fa-f]+>: {\n}"));
}

}  //  namespace
}  //  namespace nanopb
}  //  namespace firestore
}  //  namespace firebase
