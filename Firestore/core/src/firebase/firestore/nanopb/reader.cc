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

#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"

#include "Firestore/Protos/nanopb/google/firestore/v1beta1/document.nanopb.h"

namespace firebase {
namespace firestore {
namespace nanopb {

using firebase::firestore::util::Status;
using std::int64_t;
using std::uint64_t;

Reader Reader::Wrap(const uint8_t* bytes, size_t length) {
  return Reader{pb_istream_from_buffer(bytes, length)};
}

Reader Reader::Wrap(absl::string_view string_view) {
  return Reader{pb_istream_from_buffer(
      reinterpret_cast<const uint8_t*>(string_view.data()),
      string_view.size())};
}

uint32_t Reader::ReadTag() {
  Tag tag;
  if (!status_.ok()) return 0;

  bool eof;
  if (!pb_decode_tag(&stream_, &tag.wire_type, &tag.field_number, &eof)) {
    Fail(PB_GET_ERROR(&stream_));
    return 0;
  }

  // nanopb code always returns a false status when setting eof.
  HARD_ASSERT(!eof, "nanopb set both ok status and eof to true");

  last_tag_ = tag;
  return tag.field_number;
}

bool Reader::RequireWireType(pb_wire_type_t wire_type) {
  if (!status_.ok()) return false;
  if (wire_type != last_tag_.wire_type) {
    // TODO(rsgowman): We need to add much more context to the error messages so
    // that we'll have a hope of debugging them when a customer reports these
    // errors. Ideally:
    // - last_tag_'s field_number and wire_type.
    // - containing message type
    // - anything else that we can possibly get our hands on.
    // Here, and throughout nanopb/*.cc, remote/*.cc, local/*.cc.
    Fail(
        "Input proto bytes cannot be parsed (mismatch between the wiretype and "
        "the field number (tag))");
    return false;
  }
  return true;
}

void Reader::ReadNanopbMessage(const pb_field_t fields[], void* dest_struct) {
  if (!status_.ok()) return;

  if (!pb_decode(&stream_, fields, dest_struct)) {
    Fail(PB_GET_ERROR(&stream_));
  }
}

/**
 * Note that (despite the return type) this works for bool, enum, int32, int64,
 * uint32 and uint64 proto field types.
 *
 * Note: This is not expected to be called directly, but rather only via the
 * other Decode* methods (i.e. DecodeBool, DecodeLong, etc)
 *
 * @return The decoded varint as a uint64_t.
 */
uint64_t Reader::ReadVarint() {
  RequireWireType(PB_WT_VARINT);
  if (!status_.ok()) return 0;

  uint64_t varint_value = 0;
  if (!pb_decode_varint(&stream_, &varint_value)) {
    Fail(PB_GET_ERROR(&stream_));
  }
  return varint_value;
}

void Reader::ReadNull() {
  uint64_t varint = ReadVarint();
  if (!status_.ok()) return;

  if (varint != google_protobuf_NullValue_NULL_VALUE) {
    Fail("Input proto bytes cannot be parsed (invalid null value)");
  }
}

bool Reader::ReadBool() {
  uint64_t varint = ReadVarint();
  if (!status_.ok()) return false;

  switch (varint) {
    case 0:
      return false;
    case 1:
      return true;
    default:
      Fail("Input proto bytes cannot be parsed (invalid bool value)");
      return false;
  }
}

int64_t Reader::ReadInteger() {
  return ReadVarint();
}

std::string Reader::ReadString() {
  RequireWireType(PB_WT_STRING);
  if (!status_.ok()) return "";

  pb_istream_t substream;
  if (!pb_make_string_substream(&stream_, &substream)) {
    Fail(PB_GET_ERROR(&stream_));
    return "";
  }

  std::string result(substream.bytes_left, '\0');
  if (!pb_read(&substream, reinterpret_cast<pb_byte_t*>(&result[0]),
               substream.bytes_left)) {
    Fail(PB_GET_ERROR(&substream));
    pb_close_string_substream(&stream_, &substream);
    return "";
  }

  // NB: future versions of nanopb read the remaining characters out of the
  // substream (and return false if that fails) as an additional safety
  // check within pb_close_string_substream. Unfortunately, that's not present
  // in the current version (0.38).  We'll make a stronger assertion and check
  // to make sure there *are* no remaining characters in the substream.
  HARD_ASSERT(
      substream.bytes_left == 0,
      "Bytes remaining in substream after supposedly reading all of them.");

  pb_close_string_substream(&stream_, &substream);

  return result;
}

std::vector<uint8_t> Reader::ReadBytes() {
  std::string bytes = ReadString();
  if (!status_.ok()) return {};

  return std::vector<uint8_t>(bytes.begin(), bytes.end());
}

void Reader::SkipUnknown() {
  if (!status_.ok()) return;

  if (!pb_skip_field(&stream_, last_tag_.wire_type)) {
    Fail(PB_GET_ERROR(&stream_));
  }
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase
