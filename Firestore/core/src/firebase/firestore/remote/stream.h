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

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#include <grpc/grpc.h>
#include <grpcpp/client_context.h>
#include <grpcpp/completion_queue.h>
#include <grpcpp/generic/generic_stub.h>
#include <grpcpp/security/credentials.h>
#include <grpcpp/support/byte_buffer.h>

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/remote/datastore.h"
#include "Firestore/core/src/firebase/firestore/remote/exponential_backoff.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_call.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_operation.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_stream_objc_bridge.h"
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

class Stream : public GrpcOperationsObserver, public std::enable_shared_from_this<Stream> {
 public:
  Stream(util::AsyncQueue* async_queue,
         auth::CredentialsProvider* credentials_provider,
         Datastore* datastore,
         util::TimerId backoff_timer_id,
         util::TimerId idle_timer_id);

  void Start();
  void Stop();
  bool IsStarted() const;
  bool IsOpen() const;

  void OnStreamStart() override;
  void OnStreamRead(const grpc::ByteBuffer& message) override;
  void OnStreamWrite() override;
  // TODO OBC set state to error immediately when operation failed, or only in
  // OnServerError?
  void OnStreamError(const util::Status& status) override;

  // ClearError?
  void CancelBackoff();
  void MarkIdle();
  void CancelIdleCheck();

  int generation() const override {
    return generation_;
  }

 protected:
  void EnsureOnQueue() const;
  void Write(grpc::ByteBuffer&& message);
  void ResetBackoff();

 private:
  enum class State {
    Initial,
    Starting,
    Open,
    Error,
    ReconnectingWithBackoff
  };

  virtual std::shared_ptr<GrpcCall> CreateGrpcCall(
      Datastore* datastore, absl::string_view token) = 0;
  virtual void FinishGrpcCall(GrpcCall* call) = 0;
  virtual void DoOnStreamStart() = 0;
  virtual util::Status DoOnStreamRead(
      const grpc::ByteBuffer& message) = 0;
  virtual void DoOnStreamWrite() = 0;
  virtual void DoOnStreamFinish(const util::Status& status) = 0;

  void ResumeStartAfterAuth(const util::StatusOr<auth::Token>& maybe_token);

  void BackoffAndTryRestarting();
  void ResumeStartFromBackoff();
  void StopDueToIdleness();

  void ResetGrpcCall();

  State state_ = State::Initial;

  std::shared_ptr<GrpcCall> grpc_call_;

  auth::CredentialsProvider* credentials_provider_;
  util::AsyncQueue* firestore_queue_;
  Datastore* datastore_;

  ExponentialBackoff backoff_;
  util::TimerId idle_timer_id_{};
  util::DelayedOperation idleness_timer_;

  // Generation is incremented in each call to `Stop`.
  int generation_ = 0;
};

class WatchStream : public Stream {
 public:
  WatchStream(util::AsyncQueue* async_queue,
              auth::CredentialsProvider* credentials_provider,
              FSTSerializerBeta* serializer,
              Datastore* datastore,
              id delegate);

  void WatchQuery(FSTQueryData* query);
  void UnwatchTargetId(FSTTargetID target_id);

 private:
  std::shared_ptr<GrpcCall> CreateGrpcCall(
      Datastore* datastore, const absl::string_view token) override;
  void FinishGrpcCall(GrpcCall* call) override;
  void DoOnStreamStart() override;
  util::Status DoOnStreamRead(const grpc::ByteBuffer& message) override;
  void DoOnStreamWrite() override;
  void DoOnStreamFinish(const util::Status& status) override;

  bridge::WatchStreamSerializer serializer_bridge_;
  bridge::WatchStreamDelegate delegate_bridge_;
};

class WriteStream : public Stream {
 public:
  WriteStream(util::AsyncQueue* async_queue,
              auth::CredentialsProvider* credentials_provider,
              FSTSerializerBeta* serializer,
              Datastore* datastore,
              id delegate);

  void SetLastStreamToken(NSData* token);
  NSData* GetLastStreamToken() const;

  void WriteHandshake();
  void WriteMutations(NSArray<FSTMutation*>* mutations);

  bool IsHandshakeComplete() const { return is_handshake_complete_; }
  // FIXME exists for tests
  void SetHandshakeComplete() { is_handshake_complete_ = true; }

 private:
  std::shared_ptr<GrpcCall> CreateGrpcCall(
      Datastore* datastore, const absl::string_view token) override;
  void FinishGrpcCall(GrpcCall* call) override;
  void DoOnStreamStart() override;
  util::Status DoOnStreamRead(const grpc::ByteBuffer& message) override;
  void DoOnStreamWrite() override;
  void DoOnStreamFinish(const util::Status& status) override;

  bridge::WriteStreamSerializer serializer_bridge_;
  bridge::WriteStreamDelegate delegate_bridge_;
  bool is_handshake_complete_{false};
  std::string last_stream_token_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_H_
