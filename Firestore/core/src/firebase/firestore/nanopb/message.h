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
#include "Firestore/core/src/firebase/firestore/nanopb/fields_map.h"
#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"
#include "Firestore/core/src/firebase/firestore/nanopb/writer.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "grpcpp/support/byte_buffer.h"

namespace firebase {
namespace firestore {

namespace local {

class LocalSerializer;

}  // namespace local

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
  Message() = default;

  template <typename F>
  explicit Message(const F& f) : owns_proto_{true}, proto_{f()} {
  }

  template <typename F>
  static Message InitBy(const F& f) {
    return Message{f};
  }

  template <typename F>
  static Message Fill(const F& f) {
    Message result;
    result.owns_proto_ = true;
    f(&result);
    return result;
  }

  // static Message Empty() {
  //   Message result;
  //   result.owns_proto_ = true;
  //   return result;
  // }

  T release() {
    owns_proto_ = false;
    return proto_;
  }

  void reset(T&& proto) {
    Free();
    owns_proto_ = true;
    proto_ = proto;
  }

  /**
   * Attempts to parse a Nanopb message from the given `byte_buffer`. If the
   * given bytes are ill-formed, returns a failed `Status`.
   */
  static MaybeMessage<T> TryDecode(const grpc::ByteBuffer& byte_buffer);

  /**
   * Attempts to parse a Nanopb message from the given `bytes`. If the
   * given bytes are ill-formed, returns a failed `Status`.
   */
  static MaybeMessage<T> TryDecode(const ByteString& bytes);

  ~Message() {
    Free();
  }

  Message(const Message&) = delete;
  Message& operator=(const Message&) = delete;

  Message(Message&& other) noexcept
      : owns_proto_{other.owns_proto_}, proto_{other.proto_} {
    other.owns_proto_ = false;
  }

  Message& operator=(Message&& other) noexcept {
    Free();

    owns_proto_ = other.owns_proto_;
    proto_ = other.proto_;
    other.owns_proto_ = false;
    return *this;
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

  /**
   * Serializes this message into a `ByteString`.
   *
   * The lifetime of the return value is entirely independent of this message.
   */
  ByteString ToByteString() const;

 private:
  // Most code shouldn't be able to modify the underlying proto.
  friend class local::LocalSerializer;
  friend class remote::DatastoreSerializer;
  friend class remote::WatchStreamSerializer;
  friend class remote::WriteStreamSerializer;
  friend class remote::DatastoreSerializer;

  static const pb_field_t* fields() {
    return GetNanopbFields<T>();
  }

  void Free() {
    if (owns_proto()) {
      FreeNanopbMessage(fields(), &proto_);
    }
  }

  bool owns_proto() const {
    return owns_proto_ != false;
  }

  bool owns_proto_ = false;
  T proto_{};
};

namespace internal {
util::StatusOr<nanopb::ByteString> ToByteString(const grpc::ByteBuffer& buffer);
}  // namespace internal

template <typename T>
MaybeMessage<T> Message<T>::TryDecode(const grpc::ByteBuffer& byte_buffer) {
  auto maybe_bytes = internal::ToByteString(byte_buffer);
  if (!maybe_bytes.ok()) {
    return maybe_bytes.status();
  }

  return TryDecode(maybe_bytes.ValueOrDie());
}

template <typename T>
MaybeMessage<T> Message<T>::TryDecode(const ByteString& bytes) {
  Message message;
  nanopb::Reader reader{bytes};
  reader.ReadNanopbMessage(message.fields(), message.get());
  if (!reader.ok()) {
    return reader.status();
  }

  return MaybeMessage<T>{std::move(message)};
}

template <typename T>
grpc::ByteBuffer Message<T>::ToByteBuffer() const {
  ByteString bytes = ToByteString();
  grpc::Slice slice{bytes.data(), bytes.size()};
  return grpc::ByteBuffer{&slice, 1};
}

template <typename T>
ByteString Message<T>::ToByteString() const {
  nanopb::ByteStringWriter writer;
  writer.WriteNanopbMessage(fields(), &proto_);
  return writer.Release();
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_MESSAGE_H_
