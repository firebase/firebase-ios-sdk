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
 * Nanopb-generated message types (from now on, "Nanopb protos") are plain
 * C structs that contain some dynamically-allocated memory and should be
 * deallocated by calling `pb_release`; `Message` implements a simple RAII
 * wrapper that does just that. For simplicity, `Message` implements unique
 * ownership model. It provides a pointer-like access to the underlying Nanopb
 * proto. Also, `Message` serves to translate representation formats between
 * Nanopb and gRPC.
 *
 * Note that moving *isn't* a particularly cheap operation in the general case.
 * Even without doing deep copies, Nanopb protos contain *a lot* of member
 * variables (at the time of writing, the largest `sizeof` of a Nanopb proto was
 * 248).
 */
template <typename T>
class Message {
 public:
  /**
   * Creates a valid `Message` that wraps a value-constructed ("zeroed out")
   * Nanopb proto. The created object can then be filled by using the
   * pointer-like access.
   */
  Message() = default;

  /**
   * Attempts to parse a Nanopb message from the given `byte_buffer`. If the
   * given bytes are ill-formed, returns a failed `Status`.
   */
  static MaybeMessage<T> TryParse(const grpc::ByteBuffer& byte_buffer);

  /**
   * Attempts to parse a Nanopb message from the given `bytes`. If the
   * given bytes are ill-formed, returns a failed `Status`.
   */
  static MaybeMessage<T> TryParse(const ByteString& bytes);

  ~Message() {
    Free();
  }

  /** `Message` models unique ownership. */
  Message(const Message&) = delete;
  Message& operator=(const Message&) = delete;

  /**
   * A moved-from `Message` is in an invalid state that is *not* equivalent to
   * its default-constructed state. Calling `get()` on a moved-from `Message`
   * returns a null pointer; attempting to "dereference" a moved-from `Message`
   * results in undefined behavior.
   */
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

  /**
   * Returns a pointer to the underlying Nanopb proto or null if the `Message`
   * is moved-from.
   */
  T* get() {
    return owns_proto_ ? &proto_ : nullptr;
  }

  /**
   * Returns a pointer to the underlying Nanopb proto or null if the `Message`
   * is moved-from.
   */
  const T* get() const {
    return owns_proto_ ? &proto_ : nullptr;
  }

  /**
   * Returns a reference to the underlying Nanopb proto; if the `Message` is
   * moved-from, the behavior is undefined.
   *
   * For performance reasons, prefer assigning to individual fields to
   * reassigning the whole Nanopb proto.
   */
  T& operator*() {
    return *get();
  }

  /**
   * Returns a reference to the underlying Nanopb proto; if the `Message` is
   * moved-from, the behavior is undefined.
   */
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
   * Serializes this `Message` into a byte buffer.
   *
   * The lifetime of the return value is entirely independent of this `Message`.
   */
  grpc::ByteBuffer ToByteBuffer() const;

  /**
   * Serializes this `Message` into a `ByteString`.
   *
   * The lifetime of the return value is entirely independent of this `Message`.
   */
  ByteString ToByteString() const;

 private:
  // Returns a pointer to the Nanopb-generated array that describes the fields
  // of the Nanopb proto; the array is required to call most Nanopb functions.
  //
  // Note that this is essentially a property of the type, but cannot be made
  // a template parameter for various technical reasons.
  static const pb_field_t* fields() {
    return GetNanopbFields<T>();
  }

  // Important: this function does *not* modify `owns_proto_`.
  void Free() {
    if (owns_proto_) {
      FreeNanopbMessage(fields(), &proto_);
    }
  }

  bool owns_proto_ = true;
  // The Nanopb-proto is value-initialized (zeroed out) to make sure that any
  // member variables that aren't written to are in a valid state.
  T proto_{};
};

namespace internal {

util::StatusOr<nanopb::ByteString> ToByteString(const grpc::ByteBuffer& buffer);

}  // namespace internal

template <typename T>
MaybeMessage<T> Message<T>::TryParse(const grpc::ByteBuffer& byte_buffer) {
  auto maybe_bytes = internal::ToByteString(byte_buffer);
  if (!maybe_bytes.ok()) {
    return maybe_bytes.status();
  }

  return TryParse(maybe_bytes.ValueOrDie());
}

template <typename T>
MaybeMessage<T> Message<T>::TryParse(const ByteString& bytes) {
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
