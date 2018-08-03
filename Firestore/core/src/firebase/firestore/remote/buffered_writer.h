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

// GRPC forbids trying to issue a write operation before the previous write
// operation has finished. This class implements simple logic to buffer writes
// via `Enqueue`.
//
// The class invariant is that not more than one write might be pending
// at any given time. To maintain the invariant, caller has to invoke
// `OnSuccessfulWrite` when and only when a write issued via this
// `BufferedWriter` has finished (`BufferedWriter` doesn't monitor GRPC by itself).
//
// If no other write is currently pending, a call to `Enqueue` will be forwarded
// to the stream associated with this `BufferedWriter` immediately. Otherwise,
// it will be buffered and issued when `OnSuccessfulWrite` is called. An
// arbitrary number of writes may be buffered.

// Buffer is cleared when `Stop` is called; deciding whether unfinished
// writes have to be issued again or not upon restart is left to the caller.
// TODO OBC - does stopped state have to exist? Is there danger that
// this class tries writing when there is no valid `GrpcCall`?
class BufferedWriter {
 public:
  explicit BufferedWriter(WatchStream* stream) : stream_{stream} {
  }

  void Start();
  // Note that it clears the buffer.
  void Stop();

  // Automatically calls `TryWrite`.
  void Enqueue(grpc::ByteBuffer&& bytes);
  // Automatically calls `TryWrite`.
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
