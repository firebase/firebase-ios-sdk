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

namespace firebase {
namespace firestore {
namespace remote {

StreamWrite* BufferedWriter::EnqueueWrite(grpc::ByteBuffer&& write) {
  queue_.push(write);
  return TryStartWrite();
}

StreamWrite* BufferedWriter::TryStartWrite() {
  if (queue_.empty() || has_active_write_) {
    return nullptr;
  }

  has_active_write_ = true;
  grpc::ByteBuffer message = std::move(queue_.front());
  queue_.pop();
  return StreamOperation::ExecuteOperation<StreamWrite>(
      stream_, call_, firestore_queue_, std::move(message));
}

StreamWrite* BufferedWriter::DequeueNextWrite() {
  has_active_write_ = false;
  return TryStartWrite();
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
