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
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace remote {

void BufferedWriter::DiscardUnstartedWrites() {
  queue_ = {};
}

void BufferedWriter::EnqueueWrite(grpc::ByteBuffer&& write) {
  queue_.push(write);
  TryStartWrite();
}

void BufferedWriter::TryStartWrite() {
  if (empty()) {
    return;
  }
  if (has_active_write) {
    return;
  }

  has_active_write = true;
  grpc::ByteBuffer message = std::move(queue_.front());
  queue_.pop();
  stream_->Execute<StreamWrite>(std::move(message));
}

void BufferedWriter::DequeueNextWrite() {
  has_active_write = false;
  TryStartWrite();
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
