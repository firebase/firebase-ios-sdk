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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_READER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_READER_H_

#include <pb.h>
#include <pb_decode.h>

#include <cstdint>
#include <functional>
#include <string>

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/nanopb/tag.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"

namespace firebase {
namespace firestore {
namespace nanopb {

/**
 * Docs TODO(rsgowman). But currently, this just wraps the underlying nanopb
 * pb_istream_t.
 */
class Reader {
 public:
  /**
   * Creates an input stream that reads from the specified bytes. Note that
   * this reference must remain valid for the lifetime of this Reader.
   *
   * (This is roughly equivalent to the nanopb function
   * pb_istream_from_buffer())
   *
   * @param bytes where the input should be deserialized from.
   */
  static Reader Wrap(const uint8_t* bytes, size_t length);

  /**
   * Reads a message type from the input stream.
   *
   * This essentially wraps calls to nanopb's pb_decode_tag() method.
   */
  Tag ReadTag();

  /**
   * Reads a nanopb message from the input stream.
   *
   * This essentially wraps calls to nanopb's pb_decode() method. If we didn't
   * use `oneof`s in our protos, this would be the primary way of decoding
   * messages.
   */
  void ReadNanopbMessage(const pb_field_t fields[], void* dest_struct);

  void ReadNull();
  bool ReadBool();
  std::int64_t ReadInteger();

  std::string ReadString();

  /**
   * Reads a message and its length.
   *
   * Analog to Writer::WriteNestedMessage(). See that methods docs for further
   * details.
   *
   * Call this method when reading a nested message. Provide a function to read
   * the message itself.
   *
   * @param read_message_fn Function to read the submessage. Note that this
   * function is expected to check the Reader's status (via
   * Reader::status().ok()) and if not ok, to return a placeholder/invalid
   * value.
   */
  template <typename T>
  T ReadNestedMessage(const std::function<T(Reader*)>& read_message_fn);

  size_t bytes_left() const {
    return stream_.bytes_left;
  }

  util::Status status() const {
    return status_;
  }

  void set_status(util::Status status) {
    status_ = status;
  }

 private:
  /**
   * Creates a new Reader, based on the given nanopb pb_istream_t. Note that
   * a shallow copy will be taken. (Non-null pointers within this struct must
   * remain valid for the lifetime of this Reader.)
   */
  explicit Reader(pb_istream_t stream) : stream_(stream) {
  }

  /**
   * Reads a "varint" from the input stream.
   *
   * This essentially wraps calls to nanopb's pb_decode_varint() method.
   *
   * Note that (despite the return type) this works for bool, enum, int32,
   * int64, uint32 and uint64 proto field types.
   *
   * Note: This is not expected to be called direclty, but rather only via the
   * other Decode* methods (i.e. DecodeBool, DecodeLong, etc)
   *
   * @return The decoded varint as a uint64_t.
   */
  std::uint64_t ReadVarint();

  util::Status status_ = util::Status::OK();

  pb_istream_t stream_;
};

template <typename T>
T Reader::ReadNestedMessage(const std::function<T(Reader*)>& read_message_fn) {
  // Implementation note: This is roughly modeled on pb_decode_delimited,
  // adjusted to account for the oneof in FieldValue.

  if (!status_.ok()) return read_message_fn(this);

  pb_istream_t raw_substream;
  if (!pb_make_string_substream(&stream_, &raw_substream)) {
    status_ =
        util::Status(FirestoreErrorCode::DataLoss, PB_GET_ERROR(&stream_));
    pb_close_string_substream(&stream_, &raw_substream);
    return read_message_fn(this);
  }
  Reader substream(raw_substream);

  // If this fails, we *won't* return right away so that we can cleanup the
  // substream (although technically, that turns out not to matter; no resource
  // leaks occur if we don't do this.)
  // TODO(rsgowman): Consider RAII here. (Watch out for Reader class which also
  // wraps streams.)
  T message = read_message_fn(&substream);
  status_ = substream.status();

  // NB: future versions of nanopb read the remaining characters out of the
  // substream (and return false if that fails) as an additional safety
  // check within pb_close_string_substream. Unfortunately, that's not present
  // in the current version (0.38).  We'll make a stronger assertion and check
  // to make sure there *are* no remaining characters in the substream.
  HARD_ASSERT(
      substream.bytes_left() == 0,
      "Bytes remaining in substream after supposedly reading all of them.");

  pb_close_string_substream(&stream_, &substream.stream_);

  return message;
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_READER_H_
