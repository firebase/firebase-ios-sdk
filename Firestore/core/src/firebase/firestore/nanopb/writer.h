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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_WRITER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_WRITER_H_

#include <pb.h>
#include <pb_encode.h>

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

#include "Firestore/core/src/firebase/firestore/nanopb/tag.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"

namespace firebase {
namespace firestore {
namespace nanopb {

/**
 * Docs TODO(rsgowman). But currently, this just wraps the underlying nanopb
 * pb_ostream_t. Also doc how to check status.
 */
class Writer {
 public:
  /**
   * Creates an output stream that writes to the specified vector. Note that
   * this vector pointer must remain valid for the lifetime of this Writer.
   *
   * (This is roughly equivalent to the nanopb function
   * pb_ostream_from_buffer())
   *
   * @param out_bytes where the output should be serialized to.
   */
  static Writer Wrap(std::vector<std::uint8_t>* out_bytes);

  /**
   * Creates a non-writing output stream used to calculate the size of
   * the serialized output.
   */
  static Writer Sizing() {
    return Writer(PB_OSTREAM_SIZING);
  }

  /**
   * Writes a message type to the output stream.
   *
   * This essentially wraps calls to nanopb's pb_encode_tag() method.
   */
  void WriteTag(Tag tag);

  /**
   * Writes a nanopb message to the output stream.
   *
   * This essentially wraps calls to nanopb's `pb_encode()` method. If we didn't
   * use `oneof`s in our protos, this would be the primary way of encoding
   * messages.
   */
  void WriteNanopbMessage(const pb_field_t fields[], const void* src_struct);

  void WriteSize(size_t size);
  void WriteNull();
  void WriteBool(bool bool_value);
  void WriteInteger(std::int64_t integer_value);

  void WriteString(const std::string& string_value);

  /**
   * Writes a message and its length.
   *
   * When writing a top level message, protobuf doesn't include the length
   * (since you can get that already from the length of the binary output.) But
   * when writing a sub/nested message, you must include the length in the
   * serialization.
   *
   * Call this method when writing a nested message. Provide a function to
   * write the message itself. This method will calculate the size of the
   * written message (using the provided function with a non-writing sizing
   * stream), write out the size (and perform sanity checks), and then serialize
   * the message by calling the provided function a second time.
   */
  void WriteNestedMessage(const std::function<void(Writer*)>& write_message_fn);

  size_t bytes_written() const {
    return stream_.bytes_written;
  }

  util::Status status() const {
    return status_;
  }

 private:
  util::Status status_ = util::Status::OK();

  /**
   * Creates a new Writer, based on the given nanopb pb_ostream_t. Note that
   * a shallow copy will be taken. (Non-null pointers within this struct must
   * remain valid for the lifetime of this Writer.)
   */
  explicit Writer(const pb_ostream_t& stream) : stream_(stream) {
  }

  /**
   * Writes a "varint" to the output stream.
   *
   * This essentially wraps calls to nanopb's pb_encode_varint() method.
   *
   * Note that (despite the value parameter type) this works for bool, enum,
   * int32, int64, uint32 and uint64 proto field types.
   *
   * Note: This is not expected to be called directly, but rather only
   * via the other Write* methods (i.e. WriteBool, WriteLong, etc)
   *
   * @param value The value to write, represented as a uint64_t.
   */
  void WriteVarint(std::uint64_t value);

  pb_ostream_t stream_;
};

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_WRITER_H_
