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

#include <cstdint>
#include <utility>
#include <vector>

#include "Firestore/Protos/nanopb/google/firestore/v1/firestore.nanopb.h"
#include "Firestore/core/src/firebase/firestore/nanopb/message.h"
#include "Firestore/core/src/firebase/firestore/nanopb/writer.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"
#include "Firestore/core/test/firebase/firestore/util/status_testing.h"
#include "grpcpp/impl/codegen/grpc_library.h"
#include "grpcpp/support/byte_buffer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace nanopb {
namespace {

using model::DatabaseId;
using remote::Serializer;

// This proto is chosen mostly because it's relatively small but still has some
// dynamically-allocated members.
using Proto = google_firestore_v1_WriteResponse;
using TestMessage = Message<Proto>;
using TestMaybeMessage = MaybeMessage<Proto>;
const auto* const kFields = google_firestore_v1_WriteResponse_fields;

class MessageTest : public testing::Test {
 public:
  grpc::ByteBuffer GoodProto() const {
    Proto proto{};

    // A couple of fields should be enough -- these tests are primarily
    // concerned with ownership, not parsing.
    proto.stream_id = serializer_.EncodeString("stream_id");
    proto.stream_token = serializer_.EncodeString("stream_token");

    ByteStringWriter writer;
    writer.WriteNanopbMessage(kFields, &proto);
    ByteString bytes = writer.Release();

    grpc::Slice slice{bytes.data(), bytes.size()};
    return grpc::ByteBuffer{&slice, 1};
  }

  grpc::ByteBuffer BadProto() const {
    return {};
  }

 private:
  // Note: gRPC slice will crash upon destruction if gRPC library hasn't been
  // initialized, which is normally done by inheriting from this class (which
  // does initialization in its constructor).
  grpc::GrpcLibraryCodegen grpc_initializer_;
  Serializer serializer_{DatabaseId{"p", "d"}};
};

TEST_F(MessageTest, Move) {
  TestMaybeMessage maybe_message = TestMessage::Parse(kFields, GoodProto());
  ASSERT_OK(maybe_message);
  TestMessage message1 = std::move(maybe_message).ValueOrDie();
  TestMessage message2 = std::move(message1);
  // This shouldn't result in a leak or double deletion; Address Sanitizer
  // should be able to verify that.
}

TEST_F(MessageTest, ParseFailure) {
  TestMaybeMessage maybe_message = TestMessage::Parse(kFields, BadProto());
  EXPECT_NOT_OK(maybe_message);
}

}  //  namespace
}  //  namespace nanopb
}  //  namespace firestore
}  //  namespace firebase
