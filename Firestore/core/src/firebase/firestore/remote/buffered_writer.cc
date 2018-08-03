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

#include "Firestore/core/src/firebase/firestore/remote/buffered_writer.h"

#include <utility>

#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"

namespace firebase {
namespace firestore {
namespace remote {

void BufferedWriter::Start() {
  is_started_ = true;
  TryWrite();
}

void BufferedWriter::Stop() {
  buffer_.clear();
  is_started_ = has_pending_write_ = false;
}

void BufferedWriter::Enqueue(grpc::ByteBuffer&& bytes) {
  buffer_.push_back(std::move(bytes));
  TryWrite();
}

void BufferedWriter::TryWrite() {
  if (!is_started_) {
    return;
  }
  if (buffer_.empty()) {
    return;
  }
  // From the docs:
  // Only one write may be outstanding at any given time. This means that
  /// after calling Write, one must wait to receive \a tag from the completion
  /// queue BEFORE calling Write again.
  if (has_pending_write_) {
    return;
  }

  has_pending_write_ = true;
  stream_->Write(buffer_.back());
  buffer_.pop_back();
}

void BufferedWriter::OnSuccessfulWrite() {
  has_pending_write_ = false;
  TryWrite();
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
