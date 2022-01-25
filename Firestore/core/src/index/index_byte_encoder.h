/*
 * Copyright 2022 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_INDEX_INDEX_BYTE_ENCODER_H_
#define FIRESTORE_CORE_SRC_INDEX_INDEX_BYTE_ENCODER_H_

#include <memory>
#include <string>

#include "Firestore/core/src/model/field_index.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/util/ordered_code.h"
#include "absl/memory/memory.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace index {

/** An index value encoder. */
class DirectionalIndexByteEncoder {
 public:
  virtual ~DirectionalIndexByteEncoder() = default;

  virtual void WriteBytes(pb_bytes_array_t* val) = 0;

  virtual void WriteString(absl::string_view val) = 0;

  virtual void WriteLong(int64_t val) = 0;

  virtual void WriteDouble(double val) = 0;

  virtual void WriteInfinity() = 0;
};

class AscendingIndexByteEncoder;
class DescendingIndexByteEncoder;

/**
 * Manages index encoders and a buffer storing the encoded content.
 */
class IndexEncodingBuffer {
 public:
  IndexEncodingBuffer()
      : ascendingEncoder_(absl::make_unique<AscendingIndexByteEncoder>(this)),
        descendingEncoder_(
            absl::make_unique<DescendingIndexByteEncoder>(this)) {
  }

  void Seed(const std::string& bytes) {
    util::AppendBytes<false>(&buffer_, bytes.data(), bytes.size());
  }

  /** Returns a pointer to the encoder used by the given segment kind. */
  DirectionalIndexByteEncoder* ForKind(model::Segment::Kind kind) {
    if (kind == model::Segment::Kind::kDescending) {
      return reinterpret_cast<DirectionalIndexByteEncoder*>(
          descendingEncoder_.get());
    } else {
      return reinterpret_cast<DirectionalIndexByteEncoder*>(
          ascendingEncoder_.get());
    }
  }

  const std::string& GetEncodedBytes() const {
    return buffer_;
  }

  void Reset() {
    buffer_.clear();
  }

 private:
  friend class AscendingIndexByteEncoder;
  friend class DescendingIndexByteEncoder;

  std::string buffer_;
  std::unique_ptr<AscendingIndexByteEncoder> ascendingEncoder_;
  std::unique_ptr<DescendingIndexByteEncoder> descendingEncoder_;
};

class AscendingIndexByteEncoder : public DirectionalIndexByteEncoder {
 public:
  explicit AscendingIndexByteEncoder(IndexEncodingBuffer* encoder)
      : encoder_(encoder) {
  }

  void WriteBytes(pb_bytes_array_t* val) override {
    util::OrderedCode::WriteString(&encoder_->buffer_,
                                   nanopb::MakeStringView(val));
  }

  void WriteString(absl::string_view val) override {
    util::OrderedCode::WriteString(&encoder_->buffer_, val);
  }

  void WriteLong(int64_t val) override {
    util::OrderedCode::WriteSignedNumIncreasing(&encoder_->buffer_, val);
  }

  void WriteDouble(double val) override {
    util::OrderedCode::WriteDoubleIncreasing(&encoder_->buffer_, val);
  }

  void WriteInfinity() override {
    util::OrderedCode::WriteInfinity(&encoder_->buffer_);
  }

 private:
  IndexEncodingBuffer* encoder_;
};

class DescendingIndexByteEncoder : public DirectionalIndexByteEncoder {
 public:
  explicit DescendingIndexByteEncoder(IndexEncodingBuffer* encoder)
      : encoder_(encoder) {
  }

  void WriteBytes(pb_bytes_array_t* val) override {
    util::OrderedCode::WriteStringDecreasing(&encoder_->buffer_,
                                             nanopb::MakeStringView(val));
  }

  void WriteString(absl::string_view val) override {
    util::OrderedCode::WriteStringDecreasing(&encoder_->buffer_, val);
  }

  void WriteLong(int64_t val) override {
    util::OrderedCode::WriteSignedNumDecreasing(&encoder_->buffer_, val);
  }

  void WriteDouble(double val) override {
    util::OrderedCode::WriteDoubleDecreasing(&encoder_->buffer_, val);
  }

  void WriteInfinity() override {
    util::OrderedCode::WriteInfinity(&encoder_->buffer_);
  }

 private:
  IndexEncodingBuffer* encoder_;
};

}  // namespace index
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_INDEX_INDEX_BYTE_ENCODER_H_
