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
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/nanopb/tag.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/strings/string_view.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace nanopb {

/**
 * Docs TODO(rsgowman). But currently, this just wraps the underlying nanopb
 * pb_istream_t.
 *
 * All 'ReadX' methods verify the wiretype (by examining the last_tag_ field, as
 * set by ReadTag()) to ensure the correct type. If that fails, the status of
 * the Reader instance is set to non-ok.
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
   * Creates an input stream from bytes backing the string_view. Note that
   * the backing buffer must remain valid for the lifetime of this Reader.
   *
   * (This is roughly equivalent to the nanopb function
   * pb_istream_from_buffer())
   */
  static Reader Wrap(absl::string_view);

  /**
   * Reads a message type from the input stream.
   *
   * This essentially wraps calls to nanopb's pb_decode_tag() method.
   *
   * In addition to returning the tag, this method also stores it. Subsequent
   * calls to ReadX will use the stored last tag to verify that the type is
   * correct (and will otherwise set the status of this Reader object to a
   * non-ok value with the code set to FirestoreErrorCode::DataLoss).
   *
   * @return The field number of the tag. Technically, this differs slightly
   * from the tag itself insomuch as it doesn't include the wire type.
   */
  uint32_t ReadTag();

  const Tag& last_tag() const {
    return last_tag_;
  }

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

  std::vector<uint8_t> ReadBytes();

  /**
   * Reads a message and its length.
   *
   * Analog to Writer::WriteNestedMessage(). See that methods docs for further
   * details.
   *
   * Call this method when reading a nested message. Provide a function to read
   * the message itself. An overload exists to allow the function to return
   * either an optional or a unique_ptr.
   *
   * @param read_message_fn Function to read the submessage. Note that this
   * function should return {} (or nullptr/nullopt) on error.
   * @return Empty (i.e. nullptr/nullopt) on failure, else the deserialized
   * value.
   */
  template <typename T>
  absl::optional<T> ReadNestedMessage(
      const std::function<absl::optional<T>(Reader*)>& read_message_fn) {
    return ReadNestedMessageImpl(read_message_fn);
  }
  template <typename T>
  std::unique_ptr<T> ReadNestedMessage(
      const std::function<std::unique_ptr<T>(Reader*)>& read_message_fn) {
    return ReadNestedMessageImpl(read_message_fn);
  }

  template <typename T, typename C>
  using ReadingMemberFunction = T (C::*)(Reader*) const;

  /**
   * Reads a message and its length.
   *
   * Identical to ReadNestedMessage(), except this additionally takes the
   * serializer (either local or remote) as the first parameter, thus allowing
   * non-static methods to be used as the read_message_member_fn.
   */
  template <typename T, typename C>
  absl::optional<T> ReadNestedMessage(
      const C& serializer,
      ReadingMemberFunction<absl::optional<T>, C> read_message_member_fn) {
    return ReadNestedMessageImpl(serializer, read_message_member_fn);
  }
  template <typename T, typename C>
  std::unique_ptr<T> ReadNestedMessage(
      const C& serializer,
      ReadingMemberFunction<std::unique_ptr<T>, C> read_message_member_fn) {
    return ReadNestedMessageImpl(serializer, read_message_member_fn);
  }

  /**
   * Discards the bytes associated with the last read tag. (According to the
   * proto spec, we must ignore unknown fields.)
   *
   * This method uses the last tag read via ReadTag to determine how many bytes
   * should be discarded.
   */
  void SkipUnknown();

  size_t bytes_left() const {
    return stream_.bytes_left;
  }

  /**
   * True if the stream still has bytes left, and the status is ok.
   */
  bool good() const {
    return stream_.bytes_left && status_.ok();
  }

  util::Status status() const {
    return status_;
  }

  void set_status(util::Status status) {
    status_ = status;
  }

  /**
   * Ensures this Reader's status is `!ok().
   *
   * If this Reader's status is already !ok(), then this may augment the
   * description, but will otherwise leave it alone. Otherwise, this Reader's
   * status will be set to FirestoreErrorCode::DataLoss with the specified
   * description.
   */
  void Fail(const absl::string_view description) {
    status_.Update(util::Status(FirestoreErrorCode::DataLoss, description));
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
   * Ensures the last read tag (set via ReadTag()) is of the specified type. If
   * not, then Reader::status() will return a non-ok value (with the code set to
   * FirestoreErrorCode::DataLoss).
   *
   * @return Convenience indicator for success. (If false, then status() will
   * return a non-ok value.)
   */
  bool RequireWireType(pb_wire_type_t wire_type);

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

  template <typename T>
  T ReadNestedMessageImpl(const std::function<T(Reader*)>& read_message_fn);

  template <typename T, typename C>
  T ReadNestedMessageImpl(const C& serializer,
                          ReadingMemberFunction<T, C> read_message_member_fn);

  util::Status status_ = util::Status::OK();

  pb_istream_t stream_;

  Tag last_tag_;
};

template <typename T>
T Reader::ReadNestedMessageImpl(
    const std::function<T(Reader*)>& read_message_fn) {
  // Implementation note: This is roughly modeled on pb_decode_delimited,
  // adjusted to account for the oneof in FieldValue.

  RequireWireType(PB_WT_STRING);
  if (!status_.ok()) return {};

  pb_istream_t raw_substream;
  if (!pb_make_string_substream(&stream_, &raw_substream)) {
    status_ =
        util::Status(FirestoreErrorCode::DataLoss, PB_GET_ERROR(&stream_));
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

template <typename T, typename C>
T Reader::ReadNestedMessageImpl(
    const C& serializer,
    Reader::ReadingMemberFunction<T, C> read_message_member_fn) {
  std::function<T(Reader*)> read_message_fn = [=](Reader* reader) {
    return (serializer.*read_message_member_fn)(reader);
  };

  return ReadNestedMessageImpl(std::move(read_message_fn));
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_READER_H_
