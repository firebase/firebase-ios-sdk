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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_H_

#include <grpc/grpc.h>
#include <grpcpp/client_context.h>
#include <grpcpp/completion_queue.h>
#include <grpcpp/generic/generic_stub.h>
#include <grpcpp/security/credentials.h>
#include <grpcpp/support/byte_buffer.h>

#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/util/executor.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/strings/string_view.h"

#include <memory>

#import "Firestore/Protos/objc/google/firestore/v1beta1/Firestore.pbobjc.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"

namespace firebase {
namespace firestore {
namespace remote {

/*
message ListenRequest {
// The database name. In the format:
`projects/{project_id}/databases/{database_id}`. string database = 1; oneof
target_change { Target add_target = 2; int32 remove_target = 3;
}
map<string, string> labels = 4;
}

message ListenResponse {
oneof response_type {
  TargetChange target_change = 2;
  DocumentChange document_change = 3;
  DocumentDelete document_delete = 4;
  // because it is no longer relevant to that target.
  DocumentRemove document_remove = 6;
  // Returned when documents may have been removed from the given target, but
  // the exact documents are unknown.
  ExistenceFilter filter = 5;
}
}
 */

// compile protos
// proto to slices vector
// write
// queue
// read
//
// error
// close
// backoff
// idle
//
// write stream

namespace internal {

// Contains operations that are still delegated to Objective-C, notably proto
// parsing.
class ObjcBridge {
 public:
  explicit ObjcBridge(FSTSerializerBeta* serializer) : serializer_{serializer} {
  }

  std::unique_ptr<grpc::ClientContext> CreateContext(
      const model::DatabaseId& database_id,
      const absl::string_view token) const;

  grpc::ByteBuffer ToByteBuffer(FSTQueryData* query) const;

  // TODO(StatusOr)
  template <typename Proto>
  Proto ToProto(const grpc::ByteBuffer& buffer) {
    NSError* error;
    return [Proto parseFromData:ToNsData(buffer) error:&error];
  }

 private:
  grpc::ByteBuffer ToByteBuffer(NSData* data) const;
  NSData* ToNsData(const grpc::ByteBuffer& buffer) const;

  FSTSerializerBeta* serializer_;
};

class BufferedWriter {
 public:
  // explicit BufferedWriter(grpc::GenericClientAsyncReaderWriter* const call) : call_{call} {
  // }
  void SetCall(grpc::GenericClientAsyncReaderWriter* const call) { call_ = call; }
  void Write(grpc::ByteBuffer&& bytes);

 private:
  using FuncT = std::function<void()>;

  void TryWrite();
  FuncT* CreateContinuation();

  grpc::GenericClientAsyncReaderWriter* call_ = nullptr;
  std::vector<grpc::ByteBuffer> buffer_;
  bool has_pending_write_ = false;
};

class GrpcQueue {
 public:
  GrpcQueue(grpc::CompletionQueue* grpc_queue,
            std::unique_ptr<util::internal::Executor> own_executor,
            util::internal::Executor* callback_executor);

 private:
  grpc::CompletionQueue* grpc_queue_;
  std::unique_ptr<util::internal::Executor> own_executor_;
  util::internal::Executor* callback_executor_;
};

}  // namespace internal

class WatchStream {
 public:
  WatchStream(std::unique_ptr<util::internal::Executor> executor,
              const core::DatabaseInfo& database_info,
              auth::CredentialsProvider* credentials_provider,
              FSTSerializerBeta* serializer);

  void Start();
  // TODO: Close

  void WatchQuery(FSTQueryData* query);

 private:
  enum class State {
    Initial,
    Auth,
    Open,
    // Error
    // Backoff
    Stopped
  };

  void Authenticate(const util::StatusOr<auth::Token>& maybe_token);
  grpc::GenericStub CreateStub() const;

  State state_{State::Initial};

  std::unique_ptr<util::internal::Executor> executor_;
  const core::DatabaseInfo* database_info_;
  auth::CredentialsProvider* credentials_provider_;

  std::unique_ptr<grpc::ClientContext> context_;
  grpc::GenericStub stub_;
  std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call_;
  grpc::CompletionQueue queue_;

  internal::ObjcBridge objc_bridge_;
  internal::BufferedWriter buffered_writer_;
  internal::GrpcQueue polling_queue_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_H_
