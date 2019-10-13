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
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "grpcpp/support/byte_buffer.h"

namespace firebase {
namespace firestore {

namespace remote {

class DatastoreSerializer;
class WatchStreamSerializer;
class WriteStreamSerializer;

}  // namespace remote

namespace nanopb {

/**
 * Free the dynamically-allocated memory within a Nanopb-generated message.
 *
 * This essentially wraps calls to Nanopb's `pb_release()` function.
 */
void FreeNanopbMessage(const pb_field_t* fields, void* dest_struct);

template <typename T>
class Message;

template <typename T>
using MaybeMessage = util::StatusOr<Message<T>>;

/**
 * A unique-ownership RAII wrapper for Nanopb-generated message types.
 *
 * Nanopb-generated message types are plain C structs that contain some
 * dynamically-allocated memory and should be deallocated by calling
 * `pb_release`; `Message` implements a simple RAII wrapper that does just that.
 * For simplicity, `Message` implements unique ownership and is immutable after
 * construction (not counting friend classes). Use `proto()` member function to
 * access the underlying proto.
 *
 * `Message` provides a pointer-like access to the underlying Nanopb-generated
 * message type.
 *
 * Note that moving *isn't* a particularly cheap operation in the general case.
 * Even without doing deep copies, Nanopb-generated messages may contain *a lot*
 * of member variables.
 */
template <typename T>
class Message {
 public:
  /**
   * Attempts to parse a Nanopb message from the given `byte_buffer`.
   *
   * If the given bytes are ill-formed, returns a failed `Status`.
   *
   * `fields` is the Nanopb-generated descriptor of message `T`, which are named
   * by adding a `_fields` suffix to the name of the message. E.g., for
   * `google_firestore_v1_Foo` message, the corresponding fields descriptor will
   * be named `google_firestore_v1_Foo_fields`.
   */
  static MaybeMessage<T> TryDecode(const pb_field_t* fields,
                                   const grpc::ByteBuffer& byte_buffer);

  ~Message() {
    if (owns_proto()) {
      FreeNanopbMessage(fields_, &proto_);
    }
  }

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

  T* get() {
    return owns_proto() ? &proto_ : nullptr;
  }

  const T* get() const {
    return owns_proto() ? &proto_ : nullptr;
  }

  T& operator*() {
    return *get();
  }

  const T& operator*() const {
    return *get();
  }

  T* operator->() {
    return get();
  }

  const T* operator->() const {
    return get();
  }

  /**
   * Serializes this message into a byte buffer.
   *
   * The lifetime of the return value is entirely independent of this message.
   */
  grpc::ByteBuffer ToByteBuffer() const;

 private:
  // For access to the explicit constructor. Most code shouldn't be able to
  // modify the underlying proto.
  friend class remote::WatchStreamSerializer;
  friend class remote::WriteStreamSerializer;
  friend class remote::DatastoreSerializer;

  explicit Message(const pb_field_t* fields) : fields_{fields} {
  }

  bool owns_proto() const {
    return fields_ != nullptr;
  }

  // Note: `fields_` doubles as the flag that indicates whether this instance
  // owns the underlying proto (and consequently should release it upon
  // destruction).
  const pb_field_t* fields_ = nullptr;
  T proto_{};
};

namespace internal {
util::StatusOr<nanopb::ByteString> ToByteString(const grpc::ByteBuffer& buffer);
}  // namespace internal

template <typename T>
MaybeMessage<T> Message<T>::TryDecode(const pb_field_t* fields,
                                      const grpc::ByteBuffer& byte_buffer) {
  auto maybe_bytes = internal::ToByteString(byte_buffer);
  if (!maybe_bytes.ok()) {
    return maybe_bytes.status();
  }

  Message message{fields};
  nanopb::Reader reader{maybe_bytes.ValueOrDie()};
  reader.ReadNanopbMessage(fields, message.get());
  if (!reader.ok()) {
    return reader.status();
  }

  return MaybeMessage<T>{std::move(message)};
}

template <typename T>
grpc::ByteBuffer Message<T>::ToByteBuffer() const {
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
