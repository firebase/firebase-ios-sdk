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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_H_

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#include <memory>
#include <string>

#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/remote/datastore.h"
#include "Firestore/core/src/firebase/firestore/remote/exponential_backoff.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_operation.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"
#include "Firestore/core/src/firebase/firestore/remote/stream_objc_bridge.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "absl/strings/string_view.h"
#include "grpcpp/support/byte_buffer.h"

namespace firebase {
namespace firestore {
namespace remote {

class Stream : public GrpcStreamObserver,
               public std::enable_shared_from_this<Stream> {
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
  void OnStreamError(const util::Status& status) override;

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
  std::string GetDebugDescription() const;

 private:
  enum class State { Initial, Starting, Open, Error, ReconnectingWithBackoff };

  virtual std::unique_ptr<GrpcStream> CreateGrpcStream(
      Datastore* datastore, absl::string_view token) = 0;
  virtual void FinishGrpcStream(GrpcStream* call) = 0;
  virtual void DoOnStreamStart() = 0;
  virtual util::Status DoOnStreamRead(const grpc::ByteBuffer& message) = 0;
  virtual void DoOnStreamFinish(const util::Status& status) = 0;
  // PORTING NOTE: C++ cannot rely on RTTI, unlike other platforms.
  virtual std::string GetDebugName() const = 0;

  void Authenticate();
  void ResumeStartAfterAuth(const util::StatusOr<auth::Token>& maybe_token);

  void BackoffAndTryRestarting();
  void ResumeStartFromBackoff();
  void StopDueToIdleness();

  void ResetGrpcStream();

  State state_ = State::Initial;

  std::unique_ptr<GrpcStream> grpc_stream_;

  auth::CredentialsProvider* credentials_provider_;
  util::AsyncQueue* firestore_queue_;
  Datastore* datastore_;

  ExponentialBackoff backoff_;
  util::TimerId idle_timer_id_{};
  util::DelayedOperation idleness_timer_;

  // Generation is incremented in each call to `Stop`.
  int generation_ = 0;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_H_
