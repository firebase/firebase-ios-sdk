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
#include "Firestore/core/src/firebase/firestore/remote/exponential_backoff.h"
#include "Firestore/core/src/firebase/firestore/util/executor.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/strings/string_view.h"

#include <memory>

#import "Firestore/Protos/objc/google/firestore/v1beta1/Firestore.pbobjc.h"
#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

namespace firebase {
namespace firestore {
namespace remote {

// close
// error
// state machine
//
// idle
//
// enable/disable -- make sure gRPC leaves us alone with its callbacks as soon
//     as we close the stream.
//
// WRITE STREAM

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
  grpc::ByteBuffer ToByteBuffer(FSTTargetID target_id) const;

  FSTWatchChange* GetWatchChange(GCFSListenResponse* proto);
  model::SnapshotVersion GetSnapshotVersion(GCFSListenResponse* proto);

  // TODO(StatusOr)
  template <typename Proto>
  Proto* ToProto(const grpc::ByteBuffer& buffer) {
    NSError* error;
    return [Proto parseFromData:ToNsData(buffer) error:&error];
  }

 private:
  grpc::ByteBuffer ToByteBuffer(NSData* data) const;
  NSData* ToNsData(const grpc::ByteBuffer& buffer) const;

  FSTSerializerBeta* serializer_;
};

class WatchStream;

class BufferedWriter {
 public:
  explicit BufferedWriter(WatchStream* stream) : stream_{stream} {}

  void Start() { is_started_ = true; TryWrite(); }
  void Stop() { is_started_ = false; }
  void Enqueue(grpc::ByteBuffer&& bytes);

  void OnSuccessfulWrite();

 private:
  friend class WatchStream;

  void TryWrite();

  grpc::GenericClientAsyncReaderWriter* call_ = nullptr;
  std::vector<grpc::ByteBuffer> buffer_;
  bool has_pending_write_ = false;
  bool is_started_ = false;
};

}  // namespace internal

class PseudoDatastore {
  private:
  void PollGrpcQueue();

  grpc::GenericStub CreateStub() const;
  static std::unique_ptr<util::internal::Executor> CreateExecutor();

  const core::DatabaseInfo* database_info_;
  std::unique_ptr<util::internal::Executor> dedicated_executor_;

  grpc::GenericStub stub_;
  grpc::CompletionQueue grpc_queue_;
};

class GrpcCallbacks {
  virtual ~GrpcCallbacks() {}

  virtual void OnStart(bool ok) = 0;
  virtual void OnRead(bool ok, const grpc::ByteBuffer& message) = 0;
  virtual void OnWrite(bool ok) = 0;
  virtual void OnFinish(bool ok, grpc::Status status) = 0;
};

class WatchStream : public GrpcCallbacks, public enable_shared_from_this<WatchStream> {
 public:
  WatchStream(util::AsyncQueue* async_queue,
              const core::DatabaseInfo& database_info,
              auth::CredentialsProvider* credentials_provider,
              FSTSerializerBeta* serializer);
  ~WatchStream();

  void Enable();
  void Start(id delegate);
  void Stop();
  bool IsEnabled() const;
  bool IsStarted() const;
  bool IsOpen() const;

  void WatchQuery(FSTQueryData* query);
  void UnwatchTargetId(FSTTargetID target_id);

  void OnStart(bool ok) override;
  void OnRead(bool ok, const grpc::ByteBuffer& message) override;
  void OnWrite(bool ok) override;
  void OnFinish(bool ok, grpc::Status status) override;

  // ClearError?
  void CancelBackoff();

  static const char* pemRootCertsPath;

 private:
  enum class State {
    NotStarted,
    Auth,
    Open,
    GrpcError,
    ReconnectingWithBackoff,
    ShuttingDown
  };

  void Authenticate(const util::StatusOr<auth::Token>& maybe_token);

  void PerformBackoff(id delegate);
  void ResumeStartFromBackoff(id delegate);

  void Write(const grpc::ByteBuffer& message) {

  State state_{State::Initial};

  struct GrpcCall {
    std::unique_ptr<grpc::ClientContext> context;
    std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call;
  };
  internal::BufferedWriter buffered_writer;

  std::shared_ptr<GrpcCall> call_;

  auth::CredentialsProvider* credentials_provider_;
  util::AsyncQueue* firestore_queue_;
  ExponentialBackoff backoff_;

  internal::ObjcBridge objc_bridge_;

  // FIXME
  id delegate_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_H_
