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

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace remote {

BufferedWriter::BufferedWriter(WriteFunction&& write_func)
    : write_func_{std::move(write_func)} {
  HARD_ASSERT(write_func_, "BufferedWriter needs a non-empty writing function");
}

void BufferedWriter::Clear() {
  queue_ = {};
}

void BufferedWriter::Enqueue(grpc::ByteBuffer&& bytes) {
  queue_.push(std::move(bytes));
  TryWrite();
}

void BufferedWriter::TryWrite() {
  if (empty()) {
    return;
  }
  if (has_pending_write_) {
    return;
  }

  has_pending_write_ = true;
  write_func_(std::move(queue_.back()));
  queue_.pop();
}

void BufferedWriter::OnSuccessfulWrite() {
  has_pending_write_ = false;
  TryWrite();
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
