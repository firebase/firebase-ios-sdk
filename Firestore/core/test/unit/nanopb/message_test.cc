/*
 * Copyright 2019 Google
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

#include "Firestore/core/src/nanopb/message.h"

#include <cstdint>
#include <utility>
#include <vector>

#include "Firestore/Protos/nanopb/google/firestore/v1/firestore.nanopb.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/nanopb/operators.h"
#include "Firestore/core/src/nanopb/writer.h"
#include "Firestore/core/src/remote/grpc_nanopb.h"
#include "Firestore/core/test/unit/testutil/status_testing.h"
#include "grpcpp/impl/codegen/grpc_library.h"
#include "grpcpp/support/byte_buffer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace nanopb {
namespace {

using remote::ByteBufferReader;
using remote::ByteBufferWriter;

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

  // Convenience function that calls `release()` on the given `Message` object
  // and also frees the dynamic memory from the proto, as the destructor of
  // the `Message` object would.
  template <typename T>
  Message<T>& ReleaseAndFree(Message<T>& message) {
    FreeNanopbMessage(Message<T>::fields(), message.release());
    return message;
  }

 private:
  // Note: gRPC slice will crash upon destruction if gRPC library hasn't been
  // initialized, which is normally done by inheriting from this class (which
  // does initialization in its constructor).
  grpc::GrpcLibraryCodegen grpc_initializer_;
};

#if !__clang_analyzer__
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
#endif  // !__clang_analyzer__

TEST_F(MessageTest, ParseFailure) {
  ByteBufferReader reader{BadProto()};
  auto message = TestMessage::TryParse(&reader);
  EXPECT_NOT_OK(reader.status());
}

TEST_F(MessageTest, OperatorEqualsShouldReturnTrueForDefaultConstructed) {
  Message<google_firestore_v1_BitSequence> message1;
  Message<google_firestore_v1_BitSequence> message2;

  EXPECT_TRUE(message1 == message2);
  EXPECT_FALSE(message1 != message2);
}

TEST_F(MessageTest,
       OperatorEqualsShouldReturnFalseIfArg1OwnsProtoButArg2DoesNot) {
  Message<google_firestore_v1_BitSequence> message1;
  Message<google_firestore_v1_BitSequence> message2;
  ReleaseAndFree(message2);

  EXPECT_FALSE(message1 == message2);
  EXPECT_TRUE(message1 != message2);
}

TEST_F(MessageTest,
       OperatorEqualsShouldReturnFalseIfArg1DoesNotOwnProtoButArg2Does) {
  Message<google_firestore_v1_BitSequence> message1;
  Message<google_firestore_v1_BitSequence> message2;
  ReleaseAndFree(message1);

  EXPECT_FALSE(message1 == message2);
  EXPECT_TRUE(message1 != message2);
}

TEST_F(MessageTest, OperatorEqualsShouldReturnTrueIfNeitherArgsOwnTheirProto) {
  Message<google_firestore_v1_BitSequence> message1;
  Message<google_firestore_v1_BitSequence> message2;
  ReleaseAndFree(message1);
  ReleaseAndFree(message2);

  EXPECT_TRUE(message1 == message2);
  EXPECT_FALSE(message1 != message2);
}

TEST_F(MessageTest,
       OperatorEqualsShouldReturnTrueIfTheUnderlyingProtosCompareEqual) {
  Message<google_firestore_v1_BitSequence> message1;
  Message<google_firestore_v1_BitSequence> message2;
  message1->padding = 1234;
  message2->padding = 1234;

  EXPECT_TRUE(message1 == message2);
  EXPECT_FALSE(message1 != message2);
}

TEST_F(MessageTest,
       OperatorEqualsShouldReturnFalseIfTheUnderlyingProtosCompareUnequal) {
  Message<google_firestore_v1_BitSequence> message1;
  Message<google_firestore_v1_BitSequence> message2;
  message1->padding = 1234;
  message2->padding = 4321;

  EXPECT_FALSE(message1 == message2);
  EXPECT_TRUE(message1 != message2);
}

}  //  namespace
}  //  namespace nanopb
}  //  namespace firestore
}  //  namespace firebase
