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

#include <algorithm>
#include <utility>

#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_util.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace nanopb {

using nanopb::ByteString;

constexpr size_t kMinBufferSize = 4;

void Writer::WriteNanopbMessage(const pb_field_t fields[],
                                const void* src_struct) {
  if (!pb_encode(&stream_, fields, src_struct)) {
    HARD_FAIL(PB_GET_ERROR(&stream_));
  }
}

static bool AppendToBytesArray(pb_ostream_t* stream,
                               const pb_byte_t* buf,
                               size_t count) {
  auto writer = static_cast<ByteStringWriter*>(stream->state);
  writer->Append(buf, count);
  return true;
}

ByteStringWriter::ByteStringWriter() : Writer() {
  stream_.callback = AppendToBytesArray;
  stream_.state = this;
  stream_.max_size = SIZE_MAX;
}

ByteStringWriter::~ByteStringWriter() {
  std::free(buffer_);
}

void ByteStringWriter::Append(const uint8_t* data, size_t size) {
  if (size == 0) return;

  Reserve(size);
  uint8_t* pos = buffer_->bytes + buffer_->size;
  std::memcpy(pos, data, size);
  buffer_->size += size;
}

void ByteStringWriter::Reserve(size_t size) {
  size_t current_size = buffer_ ? buffer_->size : 0;

  size_t required = std::max(current_size + size, kMinBufferSize);
  HARD_ASSERT(required >= current_size);  // Avoid overflow

  if (required <= capacity_) return;

  // If capacity * 2 overflows, required will be larger.
  size_t desired = std::max(capacity_ * 2, required);

  buffer_ = static_cast<pb_bytes_array_t*>(
      std::realloc(buffer_, PB_BYTES_ARRAY_T_ALLOCSIZE(desired)));

  if (capacity_ == 0) {
    // initialize on the first allocation.
    buffer_->size = 0;
  }
  capacity_ = desired;
}

void ByteStringWriter::SetSize(size_t size) {
  HARD_ASSERT(size <= capacity_);  // Should have reserved.
  buffer_->size = CheckedSize(size);
}

ByteString ByteStringWriter::Release() {
  pb_bytes_array_t* pending = buffer_;
  buffer_ = nullptr;
  return ByteString::Take(pending);
}

static bool AppendToString(pb_ostream_t* stream,
                           const pb_byte_t* buf,
                           size_t count) {
  auto str = static_cast<std::string*>(stream->state);
  str->insert(str->end(), buf, buf + count);
  return true;
}

StringWriter::StringWriter() : Writer() {
  stream_.callback = AppendToString;
  stream_.state = &buffer_;
  stream_.max_size = SIZE_MAX;
}

std::string StringWriter::Release() {
  return std::move(buffer_);
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase
