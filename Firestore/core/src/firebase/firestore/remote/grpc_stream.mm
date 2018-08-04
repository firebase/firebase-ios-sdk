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
#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace remote {

namespace chr = std::chrono;

using model::SnapshotVersion;
using util::AsyncQueue;

namespace {

/**
 * Initial backoff time after an error.
 * Set to 1s according to https://cloud.google.com/apis/design/errors.
 */
const double kBackoffFactor = 1.5;
const AsyncQueue::Milliseconds kBackoffInitialDelay{chr::seconds(1)};
const AsyncQueue::Milliseconds kBackoffMaxDelay{chr::seconds(60)};
const AsyncQueue::Milliseconds kIdleTimeout{chr::seconds(60)};

}  // namespace

namespace {

class StreamStart : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

 private:
  void DoExecute(GrpcCall* const call) override {
    call->Start(this);
  }
  void OnCompletion(WatchStream* const stream, const bool ok) override {
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
  void OnCompletion(WatchStream* const stream, const bool ok) override {
    stream->OnStreamRead(ok, message_);
  }

  grpc::ByteBuffer message_;
};

class StreamWrite : public StreamOperation {
 public:
  void StreamWrite(WatchStream* const stream,
                   const std::shared_ptr<GrpcCall>& call,
                   const int generation,
                   const grpc::ByteBuffer& message)
      : StreamOperation{stream, call, generation}, message_{&message} {
  }

 private:
  void DoExecute(GrpcCall* const call) override {
    call->Write(*message_, this);
  }
  void OnCompletion(WatchStream* const stream, const bool ok) override {
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

  void OnCompletion(WatchStream* stream, const bool ok) override {
    FIREBASE_ASSERT_MESSAGE(ok,
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

}  // namespace

namespace internal {

grpc::ByteBuffer ObjcBridge::ToByteBuffer(FSTQueryData* query) const {
  GCFSListenRequest* request = [GCFSListenRequest message];
  request.database = [serializer_ encodedDatabaseID];
  request.addTarget = [serializer_ encodedTarget:query];
  request.labels = [serializer_ encodedListenRequestLabelsForQueryData:query];

  return ToByteBuffer([request data]);
}

grpc::ByteBuffer ObjcBridge::ToByteBuffer(FSTTargetID target_id) const {
  GCFSListenRequest* request = [GCFSListenRequest message];
  request.database = [serializer_ encodedDatabaseID];
  request.removeTarget = target_id;

  return ToByteBuffer([request data]);
}

grpc::ByteBuffer ObjcBridge::ToByteBuffer(NSData* data) const {
  const grpc::Slice slice{[data bytes], [data length]};
  return grpc::ByteBuffer{&slice, 1};
}

FSTWatchChange* ObjcBridge::ToWatchChange(GCFSListenResponse* proto) const {
  return [serializer_ decodedWatchChange:proto];
}

SnapshotVersion ObjcBridge::ToSnapshotVersion(GCFSListenResponse* proto) const {
  return [serializer_ versionFromListenResponse:proto];
}

NSData* ObjcBridge::ToNsData(const grpc::ByteBuffer& buffer) const {
  std::vector<grpc::Slice> slices;
  const grpc::Status status = buffer.Dump(&slices);
  HARD_ASSERT(status.ok(), "Trying to convert a corrupted grpc::ByteBuffer");
  if (slices.size() == 1) {
    return [NSData dataWithBytes:slices.front().begin()
                          length:slices.front().size()];
  } else {
    NSMutableData* data = [NSMutableData dataWithCapacity:buffer.Length()];
    for (const auto& slice : slices) {
      [data appendBytes: slice.begin() length:slize.size()];
    }
    return data;
  }
}

void ObjcBridge::NotifyDelegateOnOpen() {
  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidOpen];
}

NSError* ObjcBridge::NotifyDelegateOnChange(const grpc::ByteBuffer& message) {
  NSError* error;
  auto* proto = ToProto<GCFSListenResponse>(message, &error);
  if (proto) {
    id<FSTWatchStreamDelegate> delegate = delegate_;
    [delegate watchStreamDidChange:ToWatchChange(proto)
      snapshotVersion:ToSnapshotVersion(proto)];
    return nil;
  }

  NSDictionary *info = @{
    NSLocalizedDescriptionKey : @"Unable to parse response from the server",
    NSUnderlyingErrorKey : error,
    @"Expected class" : [GCFSListenResponse class],
    @"Received value" : ToNSData(message),
  };
  return [NSError errorWithDomain:FIRFirestoreErrorDomain
                                code:FIRFirestoreErrorCodeInternal
                            userInfo:info];
}

void ObjcBridge::NotifyDelegateOnError(const FirestoreErrorCode error_code) {
  id<FSTWatchStreamDelegate> delegate = delegate_;
  NSError* error = util::MakeNSError(error_code, "Server error");
  [delegate watchStreamWasInterruptedWithError:error];
}

}  // namespace

using auth::CredentialsProvider;
using auth::Token;
using core::DatabaseInfo;
using model::DatabaseId;

WatchStream::WatchStream(AsyncQueue* const async_queue,
                         // TimerId timer_id,
                         CredentialsProvider* const credentials_provider,
                         FSTSerializerBeta* serializer,
                         Datastore* datastore,
                         id delegate)
    : firestore_queue_{async_queue},
      credentials_provider_{credentials_provider},
      datastore_{datastore},
      buffered_writer_{this},
      objc_bridge_{serializer, delegate},
      backoff_{firestore_queue_,
               util::TimerId::ListenStreamConnectionBackoff /*FIXME*/,
               kBackoffFactor, kBackoffInitialDelay, kBackoffMaxDelay} {
}

void WatchStream::Start() {
  firestore_queue_->VerifyIsCurrentQueue();

  ++generation_;

  if (state_ == State::GrpcError) {
    BackoffAndTryRestarting();
    return;
  }

  // TODO: util::LogDebug(%@ %p start", NSStringFromClass([self class]),
  // (__bridge void *)self);

  FIREBASE_ASSERT_MESSAGE(state_ == State::NotStarted, "Already started");
  state_ = State::Auth;

  const bool do_force_refresh = false;
  std::weak_ptr<WatchStream> self{shared_from_this()};
  credentials_provider_->GetToken(
      do_force_refresh, [this, self](util::StatusOr<Token> maybe_token) {
        if (auto live_instance = self.lock()) {
          firestore_queue_->EnqueueRelaxed([this, maybe_token, self] {
            if (auto live_instance = self.lock()) {
              ResumeStartAfterAuth(maybe_token);
            }
          });
        }
      });
}

void WatchStream::ResumeStartAfterAuth(
    const util::StatusOr<Token>& maybe_token) {
  firestore_queue_->VerifyIsCurrentQueue();

  if (state_ == State::ShuttingDown) {
    // Streams can be stopped while waiting for authorization.
    return;
  } else {
    FIREBASE_ASSERT_MESSAGE(state_ == State::Auth,
                            "State should still be auth (was %s)", state_);
  }

  if (!maybe_token.ok()) {
    OnStreamFinish(maybe_token.status());
    return;
  }

  const absl::string_view token = [&] {
    const auto token = maybe_token.ValueOrDie();
    return token.user().is_authenticated() ? token.token()
                                           : absl::string_view{};
  }();
  auto context = datastore_->CreateContext(token);
  auto bidi_stream = datastore_->CreateGrpcCall(
      context.get(), "/google.firestore.v1beta1.Firestore/Listen");
  call_ =
      std::make_shared<GrpcCall>(std::move(context), std::move(bidi_stream));

  Execute<StreamStart>();
  // TODO: set state to open here, or only upon successful completion?
  // Objective-C does it here.
}

void WatchStream::BackoffAndTryRestarting() {
  // LogDebug(@"%@ %p backoff", NSStringFromClass([self class]), (__bridge void
  // *)self);
  firestore_queue_->VerifyIsCurrentQueue();

  FIREBASE_ASSERT_MESSAGE(state_ == State::GrpcError,
                          "Should only perform backoff in an error case");

  backoff_.BackoffAndRun([this] { ResumeStartFromBackoff(); });
  state_ = State::ReconnectingWithBackoff;
}

void WatchStream::ResumeStartFromBackoff() {
  firestore_queue_->VerifyIsCurrentQueue();

  if (state_ == State::ShuttingDown) {
    // We should have canceled the backoff timer when the stream was closed, but
    // just in case we make this a no-op.
    return;
  }

  // In order to have performed a backoff the stream must have been in an error
  // state just prior to entering the backoff state. If we weren't stopped we
  // must be in the backoff state.
  FIREBASE_ASSERT_MESSAGE(state_ == State::ReconnectingWithBackoff,
                          "State should still be backoff (was %s)", state_);

  state_ = State::NotStarted;
  Start();
  FIREBASE_ASSERT_MESSAGE(IsStarted(), "Stream should have started.");
}

void WatchStream::CancelBackoff() {
  firestore_queue_->VerifyIsCurrentQueue();

  FIREBASE_ASSERT_MESSAGE(
      !IsStarted(), "Can only cancel backoff after an error (was %s)", state_);

  // Clear the error condition.
  state_ = State::NotStarted;
  backoff_.Reset();
}

void WatchStream::MarkIdle() {
  firestore_queue_->VerifyIsCurrentQueue();
  if (IsOpen() && !idleness_timer_) {
    idleness_timer_ = firestore_queue_->EnqueueAfterDelay(
        kIdleTimeout, util::TimerId::ListenStreamIdle,
        [this] { CloseDueToIdleness(); });
  }
}

void WatchStream::CancelIdleCheck() {
  idleness_timer_.Cancel();
}

void WatchStream::OnStreamStart(const bool ok) {
  if (!ok) {
    FinishStream();
    return;
  }

  firestore_queue_->VerifyIsCurrentQueue();

  state_ = State::Open;
  buffered_writer_.Start();
  Execute<StreamRead>();

  objc_bridge_.NotifyDelegateOnOpen();
}

void WatchStream::OnStreamRead(const bool ok, const grpc::ByteBuffer& message) {
  if (!ok) {
    FinishStream();
    return;
  }

  firestore_queue_->VerifyIsCurrentQueue();

  NSError* error = objc_bridge_.NotifyDelegateOnChange(message);
  if (!error) {
    Execute<StreamRead>();
  else {
    // TODO
    LOG_DEBUG("%s", [error description]);
    FinishStream();
  }
}

void WatchStream::OnStreamWrite(const bool ok) {
  if (!ok) {
    FinishStream();
    return;
  }

  firestore_queue_->VerifyIsCurrentQueue();
  buffered_writer_.OnSuccessfulWrite();
}

void WatchStream::OnStreamFinish(const util::Status status) {
  firestore_queue_->VerifyIsCurrentQueue();

  if (status.ok()) {
    // TODO
    state_ = State::ShuttingDown;
    buffered_writer_.Stop();
    return;
  }

  state_ = State::GrpcError;
  buffered_writer_.Stop();

  const FirestoreErrorCode error = status.code();
  if (error == FirestoreErrorCode::ResourceExhausted) {
    // LogDebug("%@ %p Using maximum backoff delay to prevent overloading the
    // backend.", [self class],
    //       (__bridge void *)self);
    backoff_.ResetToMax();
  }

  objc_bridge_.NotifyDelegateOnError(error);
}

void WatchStream::Write(const grpc::ByteBuffer& message) {
  Execute<StreamWrite>(message);
}

void WatchStream::WatchQuery(FSTQueryData* query) {
  firestore_queue_->VerifyIsCurrentQueue();

  CancelIdleCheck();
  buffered_writer_.Enqueue(objc_bridge_.ToByteBuffer(query));
}

void WatchStream::UnwatchTargetId(FSTTargetID target_id) {
  firestore_queue_->VerifyIsCurrentQueue();

  CancelIdleCheck();
  buffered_writer_.Enqueue(objc_bridge_.ToByteBuffer(target_id));
}

void WatchStream::Stop() {
  firestore_queue_->VerifyIsCurrentQueue();

  if (!IsOpen()) {
    return;
  }
  buffered_writer_.Stop();
  FinishStream();
  state_ = State::ShuttingDown;

  // If this is an intentional close, ensure we don't delay our next connection
  // attempt.
  backoff_.Reset();  // ???
  // LogDebug("%@ %p Performing stream teardown", [self class], (__bridge void
  // *)self);
  // TODO: [self tearDown];
}

void WatchStream::FinishStream() {
  if (!IsOpen()) {
    return;
  }
  Execute<StreamFinish>();
}

bool WatchStream::IsOpen() const {
  firestore_queue_->VerifyIsCurrentQueue();
  return state_ == State::Open;
}

bool WatchStream::IsStarted() const {
  firestore_queue_->VerifyIsCurrentQueue();
  const bool is_starting =
      (state_ == State::Auth || state_ == State::ReconnectingWithBackoff);
  return is_starting || IsOpen();
}

void WatchStream::CloseDueToIdleness() {
  firestore_queue_->VerifyIsCurrentQueue();

  if (IsOpen()) {
    Stop();
    // When timing out an idle stream there's no reason to force the stream into
    // backoff when it restarts.
    CancelBackoff();
    state_ = State::NotStarted;  // FIXME to distinguish from other stop cases.
  }
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
