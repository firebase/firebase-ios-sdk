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

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace nanopb {

namespace {

// TODO(rsgowman): find a better home for this constant.
// A document is defined to have a max size of 1MiB - 4 bytes.
const size_t kMaxDocumentSize = 1 * 1024 * 1024 - 4;

/**
 * Creates a pb_ostream_t to the specified STL container. Note that this pointer
 * must remain valid for the lifetime of the stream.
 *
 * (This is roughly equivalent to the nanopb function pb_ostream_from_buffer().)
 *
 * @tparm Container an STL container whose value_type is a char type.
 * @param out_container where the output should be serialized to.
 */
template <typename Container>
pb_ostream_t WrapContainer(Container* out_container) {
  // Construct a nanopb output stream.
  //
  // Set the max_size to be the max document size (as an upper bound; one would
  // expect individual FieldValue's to be smaller than this).
  //
  // bytes_written is (always) initialized to 0. (NB: nanopb does not know or
  // care about the underlying output vector, so where we are in the vector
  // itself is irrelevant. i.e. don't use out_bytes->size())
  return {/*callback=*/[](pb_ostream_t* stream, const pb_byte_t* buf,
                          size_t count) -> bool {
            auto* output = static_cast<Container*>(stream->state);
            output->insert(output->end(), buf, buf + count);
            return true;
          },
          /*state=*/out_container,
          /*max_size=*/kMaxDocumentSize,
          /*bytes_written=*/0,
          /*errmsg=*/nullptr};
}

}  // namespace

Writer Writer::Wrap(std::vector<std::uint8_t>* out_bytes) {
  return Writer{WrapContainer(out_bytes)};
}

Writer Writer::Wrap(std::string* out_string) {
  return Writer{WrapContainer(out_string)};
}

void Writer::WriteNanopbMessage(const pb_field_t fields[],
                                const void* src_struct) {
  if (!pb_encode(&stream_, fields, src_struct)) {
    HARD_FAIL(PB_GET_ERROR(&stream_));
  }
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase
