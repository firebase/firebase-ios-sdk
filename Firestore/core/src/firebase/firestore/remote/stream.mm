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

#include "Firestore/core/src/firebase/firestore/remote/stream.h"

#include <utility>

#include "Firestore/Source/Remote/FSTDatastore.h"
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

} // namespace

Stream::Stream(AsyncQueue* const async_queue,
               CredentialsProvider* const credentials_provider,
               Datastore* const datastore,
               const TimerId backoff_timer_id,
               const TimerId idle_timer_id)
    : firestore_queue_{async_queue},
      credentials_provider_{credentials_provider},
      datastore_{datastore},
      backoff_{firestore_queue_, backoff_timer_id, kBackoffFactor,
               kBackoffInitialDelay, kBackoffMaxDelay},
      idle_timer_id_{idle_timer_id} {
}

// Starting

void Stream::Start() {
  EnsureOnQueue();

  if (state_ == State::Error) {
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
  credentials_provider_->GetToken([weak_self, auth_generation](
                                      util::StatusOr<Token> maybe_token) {
    auto live_instance = weak_self.lock();
    if (!live_instance) {
      return;
    }
    live_instance->firestore_queue_->EnqueueRelaxed([maybe_token, weak_self,
                                                     auth_generation] {
      auto live_instance = weak_self.lock();
      // Streams can be stopped while waiting for authorization, so need to check generation.
      if (!live_instance || live_instance->generation() != auth_generation) {
        return;
      }
      live_instance->ResumeStartAfterAuth(maybe_token);
    });
  });
}

void Stream::ResumeStartAfterAuth(const util::StatusOr<Token>& maybe_token) {
  EnsureOnQueue();

  HARD_ASSERT(state_ == State::Starting,
              "State should still be 'Starting' (was %s)", state_);

  if (!maybe_token.ok()) {
    OnStreamError(maybe_token.status());
    return;
  }

  const absl::string_view token = [&] {
    const auto token = maybe_token.ValueOrDie();
    return token.user().is_authenticated() ? token.token()
                                           : absl::string_view{};
  }();
  grpc_call_ = CreateGrpcCall(datastore_, token);

  grpc_call_->Start();
  // TODO OBC: set state to open here, or only upon successful completion?
  // Objective-C does it here. Java does it in onOpen (though it can't do it any other way due to
  // the way GRPC handles Auth). C++, for now at least, does it upon successful
  // completion.
}

void Stream::OnStreamStart() {
  EnsureOnQueue();

  state_ = State::Open;

  grpc_call_->Read();

  DoOnStreamStart();
}

// Backoff

void Stream::BackoffAndTryRestarting() {
  // LogDebug(@"%@ %p backoff", NSStringFromClass([self class]), (__bridge void
  // *)self);
  EnsureOnQueue();

  HARD_ASSERT(state_ == State::Error,
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
  ResetBackoff();
}

void Stream::ResetBackoff() {
  backoff_.Reset();
}

// Idleness

void Stream::MarkIdle() {
  EnsureOnQueue();
  if (IsOpen() && !idleness_timer_) {
    idleness_timer_ = firestore_queue_->EnqueueAfterDelay(
        kIdleTimeout, idle_timer_id_, [this] { Stop(); });
  }
}

void Stream::CancelIdleCheck() {
  idleness_timer_.Cancel();
}

// Read/write

void Stream::OnStreamRead(const grpc::ByteBuffer& message) {
  EnsureOnQueue();

  const util::Status read_status = DoOnStreamRead(message);
  if (!read_status.ok()) {
    grpc_call_->Finish();
    // Don't wait for GRPC to produce status -- since the error happened on the client, we have all
    // the information we need.
    OnStreamError(read_status);
    return;
  }

  if (IsOpen()) {
    // While the stream is open, continue waiting for new messages
    // indefinitely.
    grpc_call_->Read();
  }
}

void Stream::OnStreamWrite() {
  EnsureOnQueue();
  DoOnStreamWrite();
}

// Stopping

void Stream::Stop() {
  EnsureOnQueue();

  if (!IsStarted()) {
    return;
  }
  // TODO OBC comment on how this interplays with finishing GRPC
  ++generation_;

  FinishGrpcCall(grpc_call_.get());
  // TODO OBC rephrase After a GRPC call finishes, it will no longer be valid, so there is no
  // reason to hold on to it now that a finish operation has been added (the
  // operation has its own `shared_ptr` to the call).
  ResetGrpcCall();

  state_ = State::Initial;
  // Don't wait for GRPC to produce status -- stopping the stream was initiated by the client, so we
  // have all the information we need.
  DoOnStreamFinish(util::Status::OK());
}

  // TODO OBC explain cancelling pending operations

void Stream::OnStreamError(const util::Status& status) {
  EnsureOnQueue();

  if (status.code() == FirestoreErrorCode::ResourceExhausted) {
    // LogDebug("%@ %p Using maximum backoff delay to prevent overloading the
    // backend.", [self class],
    //       (__bridge void *)self);
    backoff_.ResetToMax();
  } else if (status.code() == FirestoreErrorCode::Unauthenticated) {
    credentials_provider_->InvalidateToken();
  }

  ResetGrpcCall();

  state_ = State::Error;
  DoOnStreamFinish(status);
}

void Stream::ResetGrpcCall() {
  grpc_call_.reset();
  backoff_.Cancel(); // OBC iOS doesn't do it, but other platforms do
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

void Stream::Write(grpc::ByteBuffer&& message) {
  CancelIdleCheck();
  grpc_call_->Write(std::move(message));
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
  Write(serializer_bridge_.ToByteBuffer(query));
}

void WatchStream::UnwatchTargetId(FSTTargetID target_id) {
  EnsureOnQueue();
  Write(serializer_bridge_.ToByteBuffer(target_id));
}

std::shared_ptr<GrpcCall> WatchStream::CreateGrpcCall(
    Datastore* const datastore, const absl::string_view token) {
  return datastore->CreateGrpcCall(
      token, "/google.firestore.v1beta1.Firestore/Listen", this);
}

void WatchStream::DoOnStreamStart() {
  delegate_bridge_.NotifyDelegateOnOpen();
}

util::Status WatchStream::DoOnStreamRead(
    const grpc::ByteBuffer& message) {
  std::string error;
  GCFSListenResponse* response =
      serializer_bridge_.ParseResponse(message, &error);
  if (!response) {
    return util::Status{FirestoreErrorCode::Internal, error};
  }

  delegate_bridge_.NotifyDelegateOnChange(
      serializer_bridge_.ToWatchChange(response),
      serializer_bridge_.ToSnapshotVersion(response));
  return util::Status::OK();
}

void WatchStream::DoOnStreamWrite() {
  // Nothing to do.
}

void WatchStream::DoOnStreamFinish(const util::Status& status) {
  delegate_bridge_.NotifyDelegateOnStreamFinished(status);
}

void WatchStream::FinishGrpcCall(GrpcCall* const call) {
  call->Finish();
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
  Write(serializer_bridge_.CreateHandshake());

  // TODO(dimond): Support stream resumption. We intentionally do not set the
  // stream token on the handshake, ignoring any stream token we might have.
}

void WriteStream::WriteMutations(NSArray<FSTMutation*>* mutations) {
  EnsureOnQueue();
  HARD_ASSERT(IsOpen(), "Not yet open");
  HARD_ASSERT(is_handshake_complete_, "Mutations sent out of turn");

  // LOG_DEBUG("FSTWriteStream %s mutation request: %s", (__bridge void *)self,
  // request);
  Write(serializer_bridge_.ToByteBuffer(mutations));
}

// Private interface

std::shared_ptr<GrpcCall> WriteStream::CreateGrpcCall(
    Datastore* const datastore, const absl::string_view token) {
  return datastore->CreateGrpcCall(token,
                                   "/google.firestore.v1beta1.Firestore/Write", this);
}

void WriteStream::DoOnStreamStart() {
  delegate_bridge_.NotifyDelegateOnOpen();
}

void WriteStream::DoOnStreamWrite() {
  // Nothing to do
}

void WriteStream::DoOnStreamFinish(const util::Status& status) {
  delegate_bridge_.NotifyDelegateOnStreamFinished(status);
  // TODO OBC explain that order is important here
  is_handshake_complete_ = false;
}

util::Status WriteStream::DoOnStreamRead(
    const grpc::ByteBuffer& message) {
  // LOG_DEBUG("FSTWriteStream %s response: %s", (__bridge void *)self,
  // response);
  EnsureOnQueue();

  std::string error;
  auto* response = serializer_bridge_.ParseResponse(message, &error);
  if (!response) {
    return util::Status{FirestoreErrorCode::Internal, error};
  }

  serializer_bridge_.UpdateLastStreamToken(response);

  if (!is_handshake_complete_) {
    // The first response is the handshake response
    is_handshake_complete_ = true;
    delegate_bridge_.NotifyDelegateOnHandshakeComplete();
  } else {
    // A successful first write response means the stream is healthy.
    // Note that we could consider a successful handshake healthy, however, the
    // write itself might be causing an error we want to back off from.
    ResetBackoff();

    delegate_bridge_.NotifyDelegateOnCommit(
        serializer_bridge_.ToCommitVersion(response),
        serializer_bridge_.ToMutationResults(response));
  }

  return util::Status::OK();
}

void WriteStream::FinishGrpcCall(GrpcCall* const call) {
  call->WriteAndFinish(serializer_bridge_.ToByteBuffer(@[]));
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
