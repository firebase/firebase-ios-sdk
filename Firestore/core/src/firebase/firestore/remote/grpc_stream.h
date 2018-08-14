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

#include "Firestore/core/src/firebase/firestore/remote/buffered_writer.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_queue.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"

namespace firebase {
namespace firestore {
namespace remote {

class GrpcOperationsObserver;

class GrpcStream : public std::enable_shared_from_this<GrpcStream> {
 public:
  GrpcStream(std::unique_ptr<grpc::ClientContext> context,
           std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
           GrpcOperationsObserver* observer,
           GrpcCompletionQueue* grpc_queue);

  void Start();
  void Read();
  void Write(grpc::ByteBuffer&& buffer);
  void Finish();
  void WriteAndFinish(grpc::ByteBuffer&& buffer);

  class Delegate {
   public:
    void OnStart();
    void OnRead(const grpc::ByteBuffer& message);
    void OnWrite();
    void OnOperationFailed();
    void OnFinishedWithServerError(const grpc::Status& status);

   private:
    explicit Delegate(std::shared_ptr<GrpcStream>&& call)
        : stream_{std::move(call)} {
    }

    bool SameGeneration() const;

    // TODO: explain ownership
    std::shared_ptr<GrpcStream> stream_;
  };

 private:
  // `Delegate` is public to easily allow all derived operations to
  friend class Delegate;

  void WriteImmediately(grpc::ByteBuffer&& buffer);

  template <typename Op, typename... Args>
  void Execute(Args... args) {
    if (grpc_queue_->IsShuttingDown()) {
      return;
    }
    auto* operation = new Op(Delegate{shared_from_this()}, std::move(args)...);
    operation->Execute(stream_.get(), context_.get());
  }

  std::unique_ptr<grpc::ClientContext> context_;
  std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call_;
  GrpcCompletionQueue* grpc_queue_ = nullptr;

  GrpcOperationsObserver* observer_ = nullptr;
  int generation_ = -1;
  BufferedWriter buffered_writer_;

  bool write_and_finish_ = false;

  // For sanity checks
  bool is_started_ = false;
  bool has_pending_read_ = false;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_CALL_H
