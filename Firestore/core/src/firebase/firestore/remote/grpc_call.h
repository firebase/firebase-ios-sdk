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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_CALL_H
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_CALL_H

#include <memory>
#include <utility>

#include <grpcpp/client_context.h>
#include <grpcpp/generic/generic_stub.h>
#include <grpcpp/support/byte_buffer.h>

#include "Firestore/core/src/firebase/firestore/util/status.h"

namespace firebase {
namespace firestore {
namespace remote {

class GrpcCall;

namespace internal {

class BufferedWriter {
public:
  explicit BufferedWriter(GrpcCall* const call) : call_{call} {
  }

  void Start();
  void Stop();
  void Clear();

  bool empty() const {
    return buffer_.empty();
  }

  void Enqueue(grpc::ByteBuffer&& bytes);
  void OnSuccessfulWrite();

private:
  void TryWrite();

  GrpcCall* call_ = nullptr;
  std::vector<grpc::ByteBuffer> buffer_;
  bool has_pending_write_ = false;
  bool is_started_ = false;
};

} // internal

class GrpcOperationsObserver;

class GrpcCall : public std::enable_shared_from_this<GrpcCall> {
 public:
  GrpcCall(std::unique_ptr<grpc::ClientContext> context,
           std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
           GrpcOperationsObserver* observer);

  void Start();
  void Read();
  void Write(grpc::ByteBuffer&& buffer);
  void WriteAndFinish(grpc::ByteBuffer&& buffer);
  void Finish();

  class Delegate {
   public:
    explicit Delegate(std::shared_ptr<GrpcCall>&& call) : call_{call} {
    }

    void OnStart();
    void OnRead(const grpc::ByteBuffer& message);
    void OnWrite();
    void OnOperationFailed();
    void OnFinishedWithServerError(const grpc::Status& status);

   private:
    bool SameGeneration() const;

    // TODO: explain ownership
    std::shared_ptr<GrpcCall> call_;
  };

 private:
  friend class internal::BufferedWriter;
  void WriteImmediately(grpc::ByteBuffer&& buffer);

  template <typename Op, typename... Args>
  void Execute(Args... args) {
    auto* operation = new Op(Delegate{shared_from_this()}, std::move(args)...);
    operation->Execute(call_.get(), context_.get());
  }

  std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call_;
  std::unique_ptr<grpc::ClientContext> context_;

  GrpcOperationsObserver* observer_ = nullptr;
  int generation_ = -1;
  internal::BufferedWriter buffered_writer_;

  bool write_and_finish_ = false;

  // For sanity checks
  bool is_started_ = false;
  bool has_pending_read_ = false;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_CALL_H
