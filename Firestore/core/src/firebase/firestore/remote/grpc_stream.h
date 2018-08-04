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

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/remote/buffered_writer.h"
#include "Firestore/core/src/firebase/firestore/remote/datastore.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_call.h"
#include "Firestore/core/src/firebase/firestore/remote/exponential_backoff.h"
#include "Firestore/core/src/firebase/firestore/remote/stream_operation.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/strings/string_view.h"

#include <memory>

#import "Firestore/Protos/objc/google/firestore/v1beta1/Firestore.pbobjc.h"
#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Remote/FSTStream.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

namespace firebase {
namespace firestore {
namespace remote {

// TODO: WRITE STREAM

namespace internal {

// Contains operations that are still delegated to Objective-C, notably proto
// parsing.
class ObjcBridge {
 public:
  ObjcBridge(FSTSerializerBeta* serializer, id delegate)
      : serializer_{serializer}, delegate_{delegate} {
  }

  grpc::ByteBuffer ToByteBuffer(FSTQueryData* query) const;
  grpc::ByteBuffer ToByteBuffer(FSTTargetID target_id) const;

  FSTWatchChange* ToWatchChange(GCFSListenResponse* proto) const;
  model::SnapshotVersion ToSnapshotVersion(GCFSListenResponse* proto) const;

  void NotifyDelegateOnOpen();
  NSError* NotifyDelegateOnChange(const grpc::ByteBuffer& message);
  void NotifyDelegateOnError(FirestoreErrorCode error_code);

 private:
  // TODO(StatusOr)
  template <typename Proto>
  Proto* ToProto(const grpc::ByteBuffer& buffer, NSError** error) const {
    return [Proto parseFromData:ToNSData(buffer) error:error];
  }

  grpc::ByteBuffer ToByteBuffer(NSData* data) const;
  NSData* ToNsData(const grpc::ByteBuffer& buffer) const;

  FSTSerializerBeta* serializer_;
  id delegate_;
};

}  // namespace internal

class WatchStream : public std::enable_shared_from_this<WatchStream> {
 public:
  WatchStream(
      util::AsyncQueue* async_queue,
              auth::CredentialsProvider* credentials_provider,
              FSTSerializerBeta* serializer,
              Datastore* datastore, id delegate);

  void Start();
  void Stop();
  bool IsStarted() const;
  bool IsOpen() const;

  void WatchQuery(FSTQueryData* query);
  void UnwatchTargetId(FSTTargetID target_id);

  void OnStreamStart(bool ok);
  void OnStreamRead(bool ok, const grpc::ByteBuffer& message);
  void OnStreamWrite(bool ok);
  void OnStreamFinish(util::Status status);

  // ClearError?
  void CancelBackoff();
  void MarkIdle();
  void CancelIdleCheck();

  int generation() const {
    return generation_;
  }

 private:
  friend class BufferedWriter;

  enum class State {
    Initial,
    Starting,
    Open,
    GrpcError,
    ReconnectingWithBackoff,
    ShuttingDown
  };

  void ResumeStartAfterAuth(const util::StatusOr<auth::Token>& maybe_token, int auth_generation);

  void BackoffAndTryRestarting();
  void ResumeStartFromBackoff();
  void StopDueToIdleness();

  void Write(const grpc::ByteBuffer& message);

  void OnConnectionBroken();
  void HalfCloseConnection();

  template <typename Op, typename... Args>
  void Execute(Args... args) {
    auto* operation = new Op(this, grpc_call_, generation(), args...);
    operation->Execute();
  }

  State state_ = State::Initial;

  BufferedWriter buffered_writer_;
  std::shared_ptr<GrpcCall> grpc_call_;

  internal::ObjcBridge objc_bridge_;
  auth::CredentialsProvider* credentials_provider_;
  util::AsyncQueue* firestore_queue_;
  Datastore* datastore_;

  ExponentialBackoff backoff_;
  util::DelayedOperation idleness_timer_;

  // Generation is incremented in each call to `Start`, so the first generation
  // will be zero.
  int generation_ = -1;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_H_
