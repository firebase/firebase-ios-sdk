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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_CONNECTION_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_CONNECTION_H_

#include <memory>

#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_stream_observer.h"
#include "absl/strings/string_view.h"
#include "grpcpp/channel.h"
#include "grpcpp/client_context.h"
#include "grpcpp/completion_queue.h"
#include "grpcpp/generic/generic_stub.h"

namespace firebase {
namespace firestore {
namespace remote {

class GrpcConnection {
 public:
  GrpcConnection(util::AsyncQueue* firestore_queue,
            const core::DatabaseInfo& database_info, grpc::CompletionQueue* grpc_queue);

  std::unique_ptr<GrpcStream> OpenGrpcStream(absl::string_view token,
                                             absl::string_view path,
                                             GrpcStreamObserver* observer);

 private:
  void EnsureValidGrpcStub();
  std::shared_ptr<grpc::Channel> CreateGrpcChannel() const;
  std::unique_ptr<grpc::ClientContext> CreateGrpcContext(
      absl::string_view token) const;
  std::unique_ptr<grpc::GenericClientAsyncReaderWriter> CreateGrpcReaderWriter(
      grpc::ClientContext* context, absl::string_view path);

  util::AsyncQueue* firestore_queue_ = nullptr;
  const core::DatabaseInfo* database_info_ = nullptr;
  grpc::CompletionQueue* grpc_queue_ = nullptr;

  std::shared_ptr<grpc::Channel> grpc_channel_;
  grpc::GenericStub grpc_stub_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_CONNECTION_H_
