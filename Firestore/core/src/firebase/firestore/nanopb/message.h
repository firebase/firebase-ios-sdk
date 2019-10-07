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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_MESSAGE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_MESSAGE_H_

#include <utility>

#include "Firestore/core/src/firebase/firestore/nanopb/byte_string.h"
#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"
#include "Firestore/core/src/firebase/firestore/nanopb/writer.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "grpcpp/support/byte_buffer.h"

namespace firebase {
namespace firestore {

namespace remote { namespace bridge { class DatastoreSerializer; class WatchStreamSerializer; class WriteStreamSerializer; }}

namespace nanopb {

template <typename T>
class Message;

template <typename T>
using MaybeMessage = util::StatusOr<Message<T>>;

template <typename T>
class Message {
 public:
  Message() = default;

  ~Message() {
    if (fields_) {
      remote::Serializer::FreeNanopbMessage(fields_, &proto_);
    }
  }

  static MaybeMessage<T> Parse(const pb_field_t* fields,
                               const grpc::ByteBuffer& buffer);

  Message(const Message&) = delete;
  Message& operator=(const Message&) = delete;

  Message(Message&& other) noexcept
      : fields_{other.fields_}, proto_{other.proto_} {
    other.fields_ = nullptr;
  }

  Message& operator=(Message&& other) noexcept {
    fields_ = other.fields_;
    proto_ = other.proto_;
    other.fields_ = nullptr;
  }

  const T& proto() const {
    return proto_;
  }

  grpc::ByteBuffer CreateByteBuffer() const;

 private:
  // For access to `mutable_proto`. User code shouldn't be able to modify the
  // underlying proto.
  friend class remote::bridge::WatchStreamSerializer;
  friend class remote::bridge::WriteStreamSerializer;
  friend class remote::bridge::DatastoreSerializer;

  explicit Message(const pb_field_t* fields) : fields_{fields} {
  }

  T& mutable_proto() {
    return proto_;
  }

  const pb_field_t* fields_ = nullptr;
  T proto_{};
};

namespace internal {
util::StatusOr<nanopb::ByteString> ToByteString(const grpc::ByteBuffer& buffer);
}  // namespace internal

template <typename T>
MaybeMessage<T> Message<T>::Parse(const pb_field_t* fields,
                                  const grpc::ByteBuffer& buffer) {
  auto maybe_bytes = internal::ToByteString(buffer);
  if (!maybe_bytes.ok()) {
    return maybe_bytes.status();
  }

  Message message{fields};
  nanopb::Reader reader{maybe_bytes.ValueOrDie()};
  reader.ReadNanopbMessage(fields, &message.mutable_proto());
  // TODO(varconst): error handling.

  return MaybeMessage<T>{std::move(message)};
}

template <typename T>
grpc::ByteBuffer Message<T>::CreateByteBuffer() const {
  nanopb::ByteStringWriter writer;
  writer.WriteNanopbMessage(fields_, &proto_);
  nanopb::ByteString bytes = writer.Release();

  grpc::Slice slice{bytes.data(), bytes.size()};
  return grpc::ByteBuffer{&slice, 1};
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_MESSAGE_H_
