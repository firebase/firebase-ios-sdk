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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_BUFFERED_WRITER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_BUFFERED_WRITER_H_

#include <vector>

#include <grpcpp/support/byte_buffer.h>

namespace firebase {
namespace firestore {
namespace remote {

class WatchStream;

class BufferedWriter {
 public:
  explicit BufferedWriter(WatchStream* stream) : stream_{stream} {
  }

  void Start() {
    is_started_ = true;
    TryWrite();
  }

  void Enqueue(grpc::ByteBuffer&& bytes);

  void OnSuccessfulWrite();

 private:
  friend class WatchStream;

  void TryWrite();

  WatchStream* stream_ = nullptr;
  std::vector<grpc::ByteBuffer> buffer_;
  bool has_pending_write_ = false;
  bool is_started_ = false;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_BUFFERED_WRITER_H_
