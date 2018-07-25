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

#include "Firestore/core/src/firebase/firestore/nanopb/writer.h"

#include "Firestore/Protos/nanopb/google/firestore/v1beta1/document.nanopb.h"

namespace firebase {
namespace firestore {
namespace nanopb {

using firebase::firestore::util::Status;
using std::int64_t;
using std::int8_t;
using std::uint64_t;

Writer Writer::Wrap(std::vector<uint8_t>* out_bytes) {
  // TODO(rsgowman): find a better home for this constant.
  // A document is defined to have a max size of 1MiB - 4 bytes.
  static const size_t kMaxDocumentSize = 1 * 1024 * 1024 - 4;

  // Construct a nanopb output stream.
  //
  // Set the max_size to be the max document size (as an upper bound; one would
  // expect individual FieldValue's to be smaller than this).
  //
  // bytes_written is (always) initialized to 0. (NB: nanopb does not know or
  // care about the underlying output vector, so where we are in the vector
  // itself is irrelevant. i.e. don't use out_bytes->size())
  pb_ostream_t raw_stream = {
      /*callback=*/[](pb_ostream_t* stream, const pb_byte_t* buf,
                      size_t count) -> bool {
        auto* out_bytes = static_cast<std::vector<uint8_t>*>(stream->state);
        out_bytes->insert(out_bytes->end(), buf, buf + count);
        return true;
      },
      /*state=*/out_bytes,
      /*max_size=*/kMaxDocumentSize,
      /*bytes_written=*/0,
      /*errmsg=*/nullptr};
  return Writer(raw_stream);
}

void Writer::WriteTag(Tag tag) {
  if (!status_.ok()) return;

  if (!pb_encode_tag(&stream_, tag.wire_type, tag.field_number)) {
    HARD_FAIL(PB_GET_ERROR(&stream_));
  }
}

void Writer::WriteNanopbMessage(const pb_field_t fields[],
                                const void* src_struct) {
  if (!status_.ok()) return;

  if (!pb_encode(&stream_, fields, src_struct)) {
    HARD_FAIL(PB_GET_ERROR(&stream_));
  }
}

void Writer::WriteSize(size_t size) {
  return WriteVarint(size);
}

void Writer::WriteVarint(uint64_t value) {
  if (!status_.ok()) return;

  if (!pb_encode_varint(&stream_, value)) {
    HARD_FAIL(PB_GET_ERROR(&stream_));
  }
}

void Writer::WriteNull() {
  return WriteVarint(google_protobuf_NullValue_NULL_VALUE);
}

void Writer::WriteBool(bool bool_value) {
  return WriteVarint(bool_value);
}

void Writer::WriteInteger(int64_t integer_value) {
  return WriteVarint(integer_value);
}

void Writer::WriteString(const std::string& string_value) {
  if (!status_.ok()) return;

  if (!pb_encode_string(
          &stream_, reinterpret_cast<const pb_byte_t*>(string_value.c_str()),
          string_value.length())) {
    HARD_FAIL(PB_GET_ERROR(&stream_));
  }
}

void Writer::WriteBytes(const std::vector<uint8_t>& bytes) {
  if (!status_.ok()) return;

  if (!pb_encode_string(&stream_,
                        reinterpret_cast<const pb_byte_t*>(bytes.data()),
                        bytes.size())) {
    HARD_FAIL(PB_GET_ERROR(&stream_));
  }
}

void Writer::WriteNestedMessage(
    const std::function<void(Writer*)>& write_message_fn) {
  if (!status_.ok()) return;

  // First calculate the message size using a non-writing substream.
  Writer sizer = Writer::Sizing();
  write_message_fn(&sizer);
  status_ = sizer.status();
  if (!status_.ok()) return;
  size_t size = sizer.bytes_written();

  // Write out the size to the output writer.
  WriteSize(size);
  if (!status_.ok()) return;

  // If this stream is itself a sizing stream, then we don't need to actually
  // parse field_value a second time; just update the bytes_written via a call
  // to pb_write. (If we try to write the contents into a sizing stream, it'll
  // fail since sizing streams don't actually have any buffer space.)
  if (stream_.callback == nullptr) {
    if (!pb_write(&stream_, nullptr, size)) {
      HARD_FAIL(PB_GET_ERROR(&stream_));
    }
    return;
  }

  // Ensure the output stream has enough space
  if (stream_.bytes_written + size > stream_.max_size) {
    HARD_FAIL(
        "Insufficient space in the output stream to write the given message");
  }

  // Use a substream to verify that a callback doesn't write more than what it
  // did the first time. (Use an initializer rather than setting fields
  // individually like nanopb does. This gives us a *chance* of noticing if
  // nanopb adds new fields.)
  Writer writer({stream_.callback, stream_.state,
                 /*max_size=*/size, /*bytes_written=*/0,
                 /*errmsg=*/nullptr});
  write_message_fn(&writer);
  status_ = writer.status();
  if (!status_.ok()) return;

  stream_.bytes_written += writer.stream_.bytes_written;
  stream_.state = writer.stream_.state;
  stream_.errmsg = writer.stream_.errmsg;

  if (writer.bytes_written() != size) {
    // submsg size changed
    HARD_FAIL("Parsing the nested message twice yielded different sizes");
  }
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase
