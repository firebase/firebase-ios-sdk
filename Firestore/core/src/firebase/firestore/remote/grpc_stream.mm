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

#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"

#include <utility>

#include "Firestore/Source/Remote/FSTDatastore.h"
#include "Firestore/core/src/firebase/firestore/remote/stream_operation.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace remote {

namespace {

using auth::CredentialsProvider;
using auth::Token;
using core::DatabaseInfo;
using model::DatabaseId;
using model::SnapshotVersion;
using util::AsyncQueue;
using util::TimerId;

/**
 * Initial backoff time after an error.
 * Set to 1s according to https://cloud.google.com/apis/design/errors.
 */
const double kBackoffFactor = 1.5;
const AsyncQueue::Milliseconds kBackoffInitialDelay{std::chrono::seconds(1)};
const AsyncQueue::Milliseconds kBackoffMaxDelay{std::chrono::seconds(60)};
const AsyncQueue::Milliseconds kIdleTimeout{std::chrono::seconds(60)};

// Operations

class StreamStart : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

 private:
  void DoExecute(GrpcCall* const call) override {
    call->Start(this);
  }
  void OnCompletion(Stream* const stream, const bool ok) override {
    stream->OnStreamStart(ok);
  }
};

class StreamRead : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

 private:
  void DoExecute(GrpcCall* const call) override {
    call->Read(&message_, this);
  }
  void OnCompletion(Stream* const stream, const bool ok) override {
    stream->OnStreamRead(ok, message_);
  }

  grpc::ByteBuffer message_;
};

class StreamWrite : public StreamOperation {
 public:
  StreamWrite(Stream* const stream,
              const std::shared_ptr<GrpcCall>& call,
              const int generation,
              const grpc::ByteBuffer& message)
      : StreamOperation{stream, call, generation}, message_{&message} {
  }

 private:
  void DoExecute(GrpcCall* const call) override {
    call->Write(*message_, this);
  }
  void OnCompletion(Stream* const stream, const bool ok) override {
    stream->OnStreamWrite(ok);
  }

  const grpc::ByteBuffer* message_;
};

class StreamFinish : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

 private:
  void DoExecute(GrpcCall* const call) override {
    call->TryCancel();
    call->Finish(&grpc_status_, this);
  }

  void OnCompletion(Stream* stream, const bool ok) override {
    HARD_ASSERT(ok,
                "Calling Finish on a GRPC call should never fail, "
                "according to the docs");
    stream->OnStreamFinish(ToFirestoreStatus(grpc_status_));
  }

  static util::Status ToFirestoreStatus(const grpc::Status from) {
    if (from.ok()) {
      return {};
    }
    return {Datastore::ToFirestoreErrorCode(from.error_code()),
            from.error_message()};
  }

  grpc::Status grpc_status_;
};
}

Stream::Stream(AsyncQueue* const async_queue,
               CredentialsProvider* const credentials_provider,
               Datastore* const datastore,
               const TimerId backoff_timer_id,
               const TimerId idle_timer_id)
    : firestore_queue_{async_queue},
      credentials_provider_{credentials_provider},
      datastore_{datastore},
      buffered_writer_{this},
      backoff_{firestore_queue_, backoff_timer_id, kBackoffFactor,
               kBackoffInitialDelay, kBackoffMaxDelay},
      idle_timer_id_{idle_timer_id} {
}

// Starting

void Stream::Start() {
  EnsureOnQueue();

  if (state_ == State::GrpcError) {
    BackoffAndTryRestarting();
    return;
  }

  // TODO: util::LogDebug(%@ %p start", NSStringFromClass([self class]),
  // (__bridge void *)self);

  HARD_ASSERT(state_ == State::Initial, "Already started");
  state_ = State::Starting;

  // Auth may outlive the stream, so make sure it doesn't try to access a
  // deleted object.
  std::weak_ptr<Stream> weak_self{shared_from_this()};
  const int auth_generation = generation();
  // TODO OBC: refactor, way too nested.
  credentials_provider_->GetToken(
      [weak_self, auth_generation](util::StatusOr<Token> maybe_token) {
        if (auto live_instance = weak_self.lock()) {
          live_instance->firestore_queue_->EnqueueRelaxed(
              [maybe_token, weak_self, auth_generation] {
                if (auto live_instance = weak_self.lock()) {
                  // Streams can be stopped while waiting for authorization.
                  if (live_instance->generation_ == auth_generation) {
                    live_instance->ResumeStartAfterAuth(maybe_token);
                  }
                }
              });
        }
      });
}

void Stream::ResumeStartAfterAuth(const util::StatusOr<Token>& maybe_token) {
  EnsureOnQueue();

  HARD_ASSERT(state_ == State::Starting,
              "State should still be 'Starting' (was %s)", state_);

  if (!maybe_token.ok()) {
    OnStreamFinish(maybe_token.status());
    return;
  }

  const absl::string_view token = [&] {
    const auto token = maybe_token.ValueOrDie();
    return token.user().is_authenticated() ? token.token()
                                           : absl::string_view{};
  }();
  grpc_call_ = DoCreateGrpcCall(datastore_, token);

  Execute<StreamStart>();
  // TODO OBC: set state to open here, or only upon successful completion?
  // Objective-C does it here. C++, for now at least, does it upon successful
  // completion.
}

void Stream::OnStreamStart(const bool ok) {
  EnsureOnQueue();
  if (!ok) {
    OnConnectionBroken();
    return;
  }

  state_ = State::Open;

  buffered_writer_.Start();
  Execute<StreamRead>();
}

// Backoff

void Stream::BackoffAndTryRestarting() {
  // LogDebug(@"%@ %p backoff", NSStringFromClass([self class]), (__bridge void
  // *)self);
  EnsureOnQueue();

  HARD_ASSERT(state_ == State::GrpcError,
              "Should only perform backoff in an error case");

  backoff_.BackoffAndRun([this] { ResumeStartFromBackoff(); });
  state_ = State::ReconnectingWithBackoff;
}

void Stream::ResumeStartFromBackoff() {
  EnsureOnQueue();

  if (state_ == State::Initial) {
    // We should have canceled the backoff timer when the stream was closed, but
    // just in case we make this a no-op.
    return;
  }

  // In order to have performed a backoff the stream must have been in an error
  // state just prior to entering the backoff state. If we weren't stopped we
  // must be in the backoff state.
  HARD_ASSERT(state_ == State::ReconnectingWithBackoff,
              "State should still be backoff (was %s)", state_);

  state_ = State::Initial;
  Start();
  HARD_ASSERT(IsStarted(), "Stream should have started.");
}

void Stream::CancelBackoff() {
  EnsureOnQueue();

  HARD_ASSERT(!IsStarted(), "Can only cancel backoff after an error (was %s)",
              state_);

  // Clear the error condition.
  state_ = State::Initial;
  backoff_.Reset();
}

// Idleness

void Stream::MarkIdle() {
  EnsureOnQueue();
  if (IsOpen() && !idleness_timer_) {
    idleness_timer_ = firestore_queue_->EnqueueAfterDelay(
        kIdleTimeout, idle_timer_id_, [this] { StopDueToIdleness(); });
  }
}

void Stream::CancelIdleCheck() {
  idleness_timer_.Cancel();
}

// Read/write

// Called by `BufferedWriter`.
void Stream::Write(const grpc::ByteBuffer& message) {
  Execute<StreamWrite>(message);
}

void Stream::OnStreamRead(const bool ok, const grpc::ByteBuffer& message) {
  EnsureOnQueue();
  if (!ok) {
    OnConnectionBroken();
    return;
  }

  client_side_error_ = DoOnStreamRead(message);
  if (client_side_error_) {
    OnConnectionBroken();
    return;
  }

  if (IsOpen()) {
    // While `Stop` hasn't been called, continue waiting for new messages
    // indefinitely.
    Execute<StreamRead>();
  }
}

void Stream::OnStreamWrite(const bool ok) {
  EnsureOnQueue();
  if (!ok) {
    OnConnectionBroken();
    return;
  }

  DoOnStreamWrite();
  buffered_writer_.OnSuccessfulWrite();
}

// Stopping

void Stream::Stop() {
  EnsureOnQueue();

  if (!IsStarted()) {
    return;
  }
  ++generation_; // This means the stream will NOT get `OnStreamFinish`.

  client_side_error_ = false;
  buffered_writer_.Stop();
  HalfCloseConnection();
  // If this is an intentional close, ensure we don't delay our next connection
  // attempt.
  backoff_.Reset();

  state_ = State::Initial;
}

void Stream::OnConnectionBroken() {
  EnsureOnQueue();

  if (!IsOpen()) {
    return;
  }

  buffered_writer_.Stop();
  HalfCloseConnection();

  state_ = State::GrpcError;
}

void Stream::HalfCloseConnection() {
  EnsureOnQueue();
  if (!IsOpen()) {
    return;
  }

  Execute<StreamFinish>();
  // After a GRPC call finishes, it will no longer valid, so there is no reason
  // to hold on to it now that a finish operation has been added (the operation
  // has its own `shared_ptr` to the call).
  grpc_call_.reset();
}

void Stream::OnStreamFinish(const util::Status status) {
  EnsureOnQueue();

  const FirestoreErrorCode error = [&] {
    if (client_side_error_ && status.code() == FirestoreErrorCode::Ok) {
      return FirestoreErrorCode::Internal;
    }
    return status.code();
  }();

  if (error == FirestoreErrorCode::ResourceExhausted) {
    // LogDebug("%@ %p Using maximum backoff delay to prevent overloading the
    // backend.", [self class],
    //       (__bridge void *)self);
    backoff_.ResetToMax();
  } else if (error == FirestoreErrorCode::Unauthenticated) {
    credentials_provider_->InvalidateToken();
  }
  client_side_error_ = false;

  DoOnStreamFinish(error);
}

void Stream::StopDueToIdleness() {
  EnsureOnQueue();
  if (!IsOpen()) {
    return;
  }

  Stop();
  // When timing out an idle stream there's no reason to force the stream
  // into backoff when it restarts.
  CancelBackoff();
  state_ = State::Initial;
}

// Check state

bool Stream::IsOpen() const {
  EnsureOnQueue();
  return state_ == State::Open;
}

bool Stream::IsStarted() const {
  EnsureOnQueue();
  const bool is_starting =
      (state_ == State::Starting || state_ == State::ReconnectingWithBackoff);
  return is_starting || IsOpen();
}

// Protected helpers

void Stream::EnsureOnQueue() const {
  firestore_queue_->VerifyIsCurrentQueue();
}

void Stream::BufferedWrite(grpc::ByteBuffer&& message) {
  CancelIdleCheck();
  buffered_writer_.Enqueue(std::move(message));
}

// Watch stream

WatchStream::WatchStream(AsyncQueue* const async_queue,
                         CredentialsProvider* const credentials_provider,
                         FSTSerializerBeta* serializer,
                         Datastore* const datastore,
                         id delegate)
    : Stream{async_queue, credentials_provider, datastore,
             TimerId::ListenStreamConnectionBackoff, TimerId::ListenStreamIdle},
      serializer_bridge_{serializer},
      delegate_bridge_{delegate} {
}

void WatchStream::WatchQuery(FSTQueryData* query) {
  EnsureOnQueue();
  BufferedWrite(serializer_bridge_.ToByteBuffer(query));
}

void WatchStream::UnwatchTargetId(FSTTargetID target_id) {
  EnsureOnQueue();
  BufferedWrite(serializer_bridge_.ToByteBuffer(target_id));
}

std::shared_ptr<GrpcCall> WatchStream::DoCreateGrpcCall(
    Datastore* const datastore, const absl::string_view token) {
  return datastore->CreateGrpcCall(
      token, "/google.firestore.v1beta1.Firestore/Listen");
}

void WatchStream::DoOnStreamStart() {
  delegate_bridge_.NotifyDelegateOnOpen();
}

bool WatchStream::DoOnStreamRead(const grpc::ByteBuffer& message) {
  // TODO OBC proper error handling?
  GCFSListenResponse* response = serializer_bridge_.ParseResponse(message);
  if (response) {
    delegate_bridge_.NotifyDelegateOnChange(
        serializer_bridge_.ToWatchChange(response),
        serializer_bridge_.ToSnapshotVersion(response));
    return true;
  }
  return false;
}

void WatchStream::DoOnStreamWrite() {
  // Nothing to do.
}

void WatchStream::DoOnStreamFinish(const FirestoreErrorCode error) {
  delegate_bridge_.NotifyDelegateOnStreamFinished(error);
}

// Write stream

WriteStream::WriteStream(AsyncQueue* const async_queue,
                         CredentialsProvider* const credentials_provider,
                         FSTSerializerBeta* serializer,
                         Datastore* const datastore,
                         id delegate)
    : Stream{async_queue, credentials_provider, datastore,
             TimerId::WriteStreamConnectionBackoff, TimerId::WriteStreamIdle},
      serializer_bridge_{serializer},
      delegate_bridge_{delegate} {
}

void WriteStream::SetLastStreamToken(NSData* token) {
  serializer_bridge_.SetLastStreamToken(token);
}

NSData* WriteStream::GetLastStreamToken() const {
  return serializer_bridge_.GetLastStreamToken();
}

void WriteStream::WriteHandshake() {
  EnsureOnQueue();
  HARD_ASSERT(IsOpen(), "Not yet open");
  HARD_ASSERT(!is_handshake_complete_, "Handshake sent out of turn");

  // LOG_DEBUG("WriteStream %s initial request: %s", this, [request
  // description]);
  BufferedWrite(serializer_bridge_.CreateHandshake());

  // TODO(dimond): Support stream resumption. We intentionally do not set the
  // stream token on the handshake, ignoring any stream token we might have.
}

void WriteStream::WriteMutations(NSArray<FSTMutation*>* mutations) {
  EnsureOnQueue();
  HARD_ASSERT(IsOpen(), "Not yet open");
  HARD_ASSERT(!is_handshake_complete_, "Mutations sent out of turn");

  // LOG_DEBUG("FSTWriteStream %s mutation request: %s", (__bridge void *)self,
  // request);
  BufferedWrite(serializer_bridge_.ToByteBuffer(mutations));
}

// Private interface

std::shared_ptr<GrpcCall> WriteStream::DoCreateGrpcCall(
    Datastore* const datastore, const absl::string_view token) {
  return datastore->CreateGrpcCall(token,
                                   "/google.firestore.v1beta1.Firestore/Write");
}

void WriteStream::DoOnStreamStart() {
  delegate_bridge_.NotifyDelegateOnOpen();
}

void WriteStream::DoOnStreamWrite() {
  // OBC is this logic necessary? We finish the stream gracefully.
  // (void) tearDown {
  // if ([self isHandshakeComplete]) {
  //   // Send an empty write request to the backend to indicate imminent stream
  //   closure. This allows
  //   // the backend to clean up resources.
  //   [self writeMutations:@[]];
  // }
}

void WriteStream::DoOnStreamFinish(const FirestoreErrorCode error) {
  delegate_bridge_.NotifyDelegateOnStreamFinished(error);
}

bool WriteStream::DoOnStreamRead(const grpc::ByteBuffer& message) {
  // LOG_DEBUG("FSTWriteStream %s response: %s", (__bridge void *)self,
  // response);
  EnsureOnQueue();

  auto* response = serializer_bridge_.ParseResponse(message);
  if (!response) {
    return false;
  }

  SetLastStreamToken(serializer_bridge_.ToStreamToken(response));

  if (!is_handshake_complete_) {
    // The first response is the handshake response
    is_handshake_complete_ = true;
    delegate_bridge_.NotifyDelegateOnHandshakeComplete();
  } else {
    // A successful first write response means the stream is healthy.
    // Note that we could consider a successful handshake healthy, however, the
    // write itself might be causing an error we want to back off from.
    CancelBackoff();

    delegate_bridge_.NotifyDelegateOnCommit(
        serializer_bridge_.ToCommitVersion(response),
        serializer_bridge_.ToMutationResults(response));
  }

  return true;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
