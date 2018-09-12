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

// PORTING NOTE: this class has limited resemblance to `GrpcConnection` in Web
// client. However, unlike Web client, it's not meant to hide different
// implementations of a `Connection` under a single interface.

/**
 * Creates and owns gRPC objects (channel and stub) necessary to produce a
 * `GrpcStream`.
 */
class GrpcConnection {
 public:
  GrpcConnection(const core::DatabaseInfo& database_info,
                 util::AsyncQueue* worker_queue,
                 grpc::CompletionQueue* grpc_queue);

  /**
   * Creates a stream to the given stream RPC endpoint. The resulting stream
   * needs to be `Start`ed before it can be used.
   */
  // PORTING NOTE: unlike Web client, the created stream is not open and has to
  // be started manually.
  std::unique_ptr<GrpcStream> CreateStream(absl::string_view rpc_name,
                                           absl::string_view token,
                                           GrpcStreamObserver* observer);

 private:
  std::unique_ptr<grpc::ClientContext> CreateContext(
      absl::string_view token) const;
  void EnsureActiveStub();

  const core::DatabaseInfo* database_info_ = nullptr;
  util::AsyncQueue* worker_queue_ = nullptr;
  grpc::CompletionQueue* grpc_queue_ = nullptr;

  std::shared_ptr<grpc::Channel> grpc_channel_;
  std::unique_ptr<grpc::GenericStub> grpc_stub_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_CONNECTION_H_
