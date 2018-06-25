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

// WRITE STREAM

class WatchStream;

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

  WatchStream* stream_ = nullptr;
  std::vector<grpc::ByteBuffer> buffer_;
  bool has_pending_write_ = false;
  bool is_started_ = false;
};

struct GrpcCall {
  std::unique_ptr<grpc::ClientContext> context;
  std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call;
};

}  // namespace internal

class StreamOperation {
 public:
  virtual ~StreamOperation() {
  }

  void Finalize(bool ok) {
    if (auto stream = stream_handle_.lock()) {
      DoFinalize(stream.get(), ok);
    }
  }

 protected:
    StreamOp(const std::shared_ptr<WatchStream>& stream,
        const std::shared_ptr<internal::GrpcCall>& call)
      : stream_handle_{stream},
  call_{call} {
  }

 private:
  virtual void DoFinalize(WatchStream* stream, bool ok) = 0;

    std::weak_ptr<WatchStream> stream_handle_;
  std::shared_ptr<internal::GrpcCall> call_;
};

class GrpcStreamCallbacks {
  virtual ~GrpcStreamCallbacks() {}

  virtual void OnStreamStart(bool ok) = 0;
  virtual void OnStreamRead(bool ok, const grpc::ByteBuffer& message) = 0;
  virtual void OnStreamWrite(bool ok) = 0;
  virtual void OnStreamFinish(grpc::Status status) = 0;
};

class WatchStream : public GrpcStreamCallbacks, public enable_shared_from_this<WatchStream> {
 public:
  WatchStream(util::AsyncQueue* async_queue,
              const core::DatabaseInfo& database_info,
              auth::CredentialsProvider* credentials_provider,
              FSTSerializerBeta* serializer,
              DatastoreImpl* datastore);
  ~WatchStream();

  void Start(id delegate);
  void Stop();
  bool IsStarted() const;
  bool IsOpen() const;

  void WatchQuery(FSTQueryData* query);
  void UnwatchTargetId(FSTTargetID target_id);

  void OnStreamStart(bool ok) override;
  void OnStreamRead(bool ok, const grpc::ByteBuffer& message) override;
  void OnStreamWrite(bool ok) override;
  void OnStreamFinish(grpc::Status status) override;

  // ClearError?
  void CancelBackoff();

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

  void BackoffAndTryRestarting(id delegate);
  void ResumeStartFromBackoff(id delegate);

  void Write(const grpc::ByteBuffer& message);
  void FinishStream();

  State state_{State::NotStarted};

  internal::BufferedWriter buffered_writer;

  std::shared_ptr<internal::GrpcCall> call_;

  const core::DatabaseInfo* database_info_;
  auth::CredentialsProvider* credentials_provider_;
  util::AsyncQueue* firestore_queue_;
  DatastoreImpl* datastore_;
  ExponentialBackoff backoff_;

  internal::ObjcBridge objc_bridge_;

  // FIXME
  id delegate_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_H_
