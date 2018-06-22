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
//#include "Firestore/Source/Remote/FSTStream.h"
#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"
#include "absl/memory/memory.h"

#include <fstream>
#include <sstream>

namespace firebase {
namespace firestore {
namespace remote {

using firebase::firestore::model::SnapshotVersion;
namespace chr = std::chrono;

namespace {

/**
 * Initial backoff time after an error.
 * Set to 1s according to https://cloud.google.com/apis/design/errors.
 */
const AsyncQueue::Milliseconds kBackoffInitialDelay{chr::seconds(1)};
const AsyncQueue::Milliseconds kBackoffMaxDelay{chr::seconds(60)};
const double kBackoffFactor = 1.5;

}  // namespace

namespace internal {

// Can we eliminate state Stopped? `Stop` method should be pretty fast and make the object ready for
// destruction.

class StreamStartOp : public StreamOp {
 public:
  static void Execute(const std::shared_ptr<WatchStream>& stream, const std::shared_ptr<GrpcCall>& call) {
    auto op = new StreamStartOp{stream, call};
    call->Start(op);
  }

 private:
  StreamStartOp(const std::shared_ptr<WatchStream>& stream, const std::shared_ptr<GrpcCall>& call)
      : StreamOp{stream, call} {
  }

  void DoFinalize(WatchStream* stream, bool ok) override {
    stream->OnStart(ok);
  }
};

class StreamReadOp : public StreamOp {
 public:
  static void Execute(const std::shared_ptr<WatchStream>& stream, const std::shared_ptr<GrpcCall>& call) {
    auto op = new StreamReadOp{stream, call};
    call->Read(&op->message, op);
  }

 private:
  StreamReadOp(const std::shared_ptr<WatchStream>& stream, const std::shared_ptr<GrpcCall>& call)
      : StreamOp{stream, call} {
  }

  void DoFinalize(WatchStream* stream, bool ok) override {
    stream->OnRead(ok, message);
  }

  grpc::ByteBuffer message;
};

class StreamWriteOp : public StreamOp {
 public:
  static void Execute(
                    const grpc::ByteBuffer& message,
                    const std::shared_ptr<WatchStream>& stream,
                    const std::shared_ptr<GrpcCall>& call) {
    auto op = new StreamWriteOp{stream, call};
    call->Write(message, op);
  }

 private:
  StreamWriteOp(const std::shared_ptr<WatchStream>& stream, const std::shared_ptr<GrpcCall>& call)
      : StreamOp{stream, call} {
  }

  void DoFinalize(WatchStream* stream, bool ok) override {
    stream->OnWrite(ok);
  }
};

class StreamFinishOp : public StreamOp {
 public:
  static void Execute(
                    const std::shared_ptr<WatchStream>& stream,
                    const std::shared_ptr<GrpcCall>& call) {
    auto op = new StreamFinishOp{stream, call};
    call->Finish(&op->status, op);
  }

 private:
  StreamWriteOp(const std::shared_ptr<WatchStream>& stream, const std::shared_ptr<GrpcCall>& call)
      : StreamOp{stream, call} {
  }

  void DoFinalize(WatchStream* stream, bool ok) override {
    stream->OnFinish(ok);
  }

  grpc::Status status_;
};

//        OBJC BRIDGE

std::unique_ptr<grpc::ClientContext> ObjcBridge::CreateContext(
    const model::DatabaseId& database_id, const absl::string_view token) const {
  return [FSTDatastore createGrpcClientContextWithDatabaseID:&database_id
                                                       token:token];
}

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

FSTWatchChange* ObjcBridge::GetWatchChange(GCFSListenResponse* proto) {
  return [serializer_ decodedWatchChange:proto];
}

SnapshotVersion ObjcBridge::GetSnapshotVersion(GCFSListenResponse* proto) {
  return [serializer_ versionFromListenResponse:proto];
}

NSData* ObjcBridge::ToNsData(const grpc::ByteBuffer& buffer) const {
  std::vector<grpc::Slice> slices;
  buffer.Dump(&slices);  // TODO: check return value
  if (slices.size() == 1) {
    return [NSData dataWithBytes:slices.front().begin()
                          length:slices.front().size()];
  } else {
    // FIXME
    return [NSData dataWithBytes:slices.front().begin()
                          length:slices.front().size()];
  }
}

//        BUFFERED WRITER

void BufferedWriter::Enqueue(grpc::ByteBuffer&& bytes) {
  buffer_.push_back(std::move(bytes));
  TryWrite();
}

void BufferedWriter::TryWrite() {
  if (!is_started_) {
    return;
  }
  if (buffer_.empty()) {
    return;
  }
  // From the docs:
  // Only one write may be outstanding at any given time. This means that
  /// after calling Write, one must wait to receive \a tag from the completion
  /// queue BEFORE calling Write again.
  if (has_pending_write_) {
    return;
  }

  has_pending_write_ = true;
  // bidi_stream_->Write(buffer_.back(), &kWriteTag);
  stream_->Write(buffer.back());
  buffer_.pop_back();
}

void BufferedWriter::OnSuccessfulWrite() {
  has_pending_write_ = false;
  TryWrite();
}

}  // namespace internal

using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::auth::Token;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::DatabaseId;
// using firebase::firestore::model::SnapshotVersion;

//        WATCH STREAM

WatchStream::WatchStream(util::AsyncQueue* const async_queue,
                         TimerId timer_id,
                         const DatabaseInfo& database_info,
                         CredentialsProvider* const credentials_provider,
                         FSTSerializerBeta* serializer,
                         DatastoreImpl* datastore)
    : database_info_{&database_info},
      firestore_queue_{async_queue},
      credentials_provider_{credentials_provider},
      datastore_{datastore},
      buffered_writer_{this},
      objc_bridge_{serializer},
      backoff_{firestore_queue_, timer_id, kBackoffInitialDelay,
               kBackoffMaxDelay, kBackoffFactor} {
}

void WatchStream::Start(id delegate) {
  firestore_queue_->VerifyIsCurrentQueue();

  if (state_ == State::Error) {
    BackoffAndTryRestarting(delegate);
    return;
  }

  // TODO: util::LogDebug(%@ %p start", NSStringFromClass([self class]),
  // (__bridge void *)self);

  FIREBASE_ASSERT_MESSAGE(state_ == State::Initial, "Already started");
  state_ = State::Auth;
  FIREBASE_ASSERT_MESSAGE(delegate_ == nil, "Delegate must be nil");
  delegate_ = delegate;

  const bool do_force_refresh = false;
  credentials_provider_->GetToken(
      do_force_refresh, [this](util::StatusOr<Token> maybe_token) {
        firestore_queue_->EnqueueRelaxed(
            [this, maybe_token] { ResumeStartAfterAuth(maybe_token); });
      });
}

// Call may be closed due to:
// - error;
// - idleness;
// - network disable/reenable
void WatchStream::ResumeStartAfterAuth(
    const util::StatusOr<Token>& maybe_token) {
  firestore_queue_->VerifyIsCurrentQueue();

  if (state_ == State::Stopped) {
    // Streams can be stopped while waiting for authorization.
    return;
  } else {
    FIREBASE_ASSERT_MESSAGE(state_ == State::Auth,
                            "State should still be auth (was %s)", state_);
  }

  if (!maybe_token.ok()) {
    // TODO: error handling
    OnFinish();  // FIXME
    return;
  }

  const absl::string_view token = [&] {
    const auto token = maybe_token.ValueOrDie();
    return token.user().is_authenticated() ? token.token()
                                           : absl::string_view{};
  }();
  auto context = objc_bridge_.CreateContext(database_info_->database_id(), token);
  auto bidi_stream = datastore_->-CreateGrpcCall(context_.get(),
                                   "/google.firestore.v1beta1.Firestore/Listen");
  call_ = std::make_shared<GrpcCall>(std::move(context), std::move(bidi_stream));

  // bidi_stream_->StartCall(&kStartTag);
  StreamStartOp::Execute(call_, shared_from_this());
  // TODO: set state to open here, or only upon successful completion?
  // Objective-C does it here.
}

void WatchStream::BackoffAndTryRestarting() {
  // LogDebug(@"%@ %p backoff", NSStringFromClass([self class]), (__bridge void
  // *)self);
  firestore_queue_->VerifyIsCurrentQueue();

  FIREBASE_ASSERT_MESSAGE(state_ == State::Error,
                          "Should only perform backoff in an error case");

  backoff_.BackoffAndRun(
      [this, delegate] { ResumeStartFromBackoff(delegate); });
  state_ = State::Backoff;
}

void WatchStream::ResumeStartFromBackoff(id delegate) {
  firestore_queue_->VerifyIsCurrentQueue();

  if (state_ == State::Stopped) {
    // We should have canceled the backoff timer when the stream was closed, but
    // just in case we make this a no-op.
    return;
  }

  // In order to have performed a backoff the stream must have been in an error
  // state just prior to entering the backoff state. If we weren't stopped we
  // must be in the backoff state.
  FIREBASE_ASSERT_MESSAGE(state_ == State::Backoff,
                          "State should still be backoff (was %s)", state_);

  state_ = State::Initial;
  Start(delegate);
  FIREBASE_ASSERT_MESSAGE(IsStarted(), "Stream should have started.");
}

void WatchStream::CancelBackoff() {
  firestore_queue_->VerifyIsCurrentQueue();

  FIREBASE_ASSERT_MESSAGE(
      !IsStarted(), "Can only cancel backoff after an error (was %s)", state_);

  // Clear the error condition.
  state_ = State::Initial;
  backoff_.Reset();
}

void WatchStream::OnStart(const bool ok) {
  if (!ok) {
    FinishStream();
    return;
  }

  firestore_queue_->VerifyIsCurrentQueue();

  state_ = State::Open;
  buffered_writer_.Start();
  //bidi_stream_->Read(&last_read_message_, &kReadTag);
  StreamReadOp::Execute(call_, shared_from_this());

  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidOpen];
}

void WatchStream::OnRead(const bool ok, const grpc::ByteBuffer& message) {
  if (!ok) {
    FinishStream();
    return;
  }

  firestore_queue_->VerifyIsCurrentQueue();

  auto* proto = objc_bridge_.ToProto<GCFSListenResponse>(last_read_message_);
  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidChange:objc_bridge_.GetWatchChange(proto)
                 snapshotVersion:objc_bridge_.GetSnapshotVersion(proto)];

  //bidi_stream_->Read(&last_read_message_, &kReadTag);
  StreamReadOp::Execute(call_, shared_from_this());
}

void WatchStream::OnWrite(const bool ok) {
  if (!ok) {
    FinishStream();
    return;
  }

  firestore_queue_->VerifyIsCurrentQueue();
  buffered_writer_.OnSuccessfulWrite();
}

void WatchStream::OnFinish(bool ok, grpc::Status status) {
  firestore_queue_->VerifyIsCurrentQueue();

  FIREBASE_ASSERT_MESSAGE(ok, "TODO");
  // FIXME
  if (status.code() == FIRFirestoreErrorCodeOK) {
    // TODO
    return;
  }

  state_ = State::Error;
  buffered_writer_.Stop();

  // FIXME
  long error = status.code();

  // FIXME
  if (error == FIRFirestoreErrorCodeResourceExhausted) {
    // LogDebug("%@ %p Using maximum backoff delay to prevent overloading the
    // backend.", [self class],
    //       (__bridge void *)self);
    backoff_.ResetToMax();
  }
}

  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamWasInterruptedWithError:nil];  // FIXME
  delegate_ = nil;
}

void WatchStream::Write(const grpc::ByteBuffer& message) {
  StreamWriteOp::Execute(message, call_, shared_from_this());
}

void WatchStream::WatchQuery(FSTQueryData* query) {
  firestore_queue_->VerifyIsCurrentQueue();

  // [self cancelIdleCheck];
  buffered_writer_.Enqueue(objc_bridge_.ToByteBuffer(query));
}

void WatchStream::UnwatchTargetId(FSTTargetID target_id) {
  firestore_queue_->VerifyIsCurrentQueue();

  // [self cancelIdleCheck];
  buffered_writer_.Enqueue(objc_bridge_.ToByteBuffer(target_id));
}

void WatchStream::Stop() {
  firestore_queue_->VerifyIsCurrentQueue();

  if (!IsOpen()) {
    return;
  }
  state_ = State::Stopped;
  buffered_writer_.Stop();

  FinishStream();
  // If this is an intentional close ensure we don't delay our next connection
  // attempt.
  backoff_.Reset(); // ???
  // LogDebug("%@ %p Performing stream teardown", [self class], (__bridge void
  // *)self);
  // TODO: [self tearDown];
}

void WatchStream::FinishStream() {
  StreamFinishOp::Execute(call_, shared_from_this());
}

bool WatchStream::IsOpen() const {
  firestore_queue_->VerifyIsCurrentQueue();
  return state_ == State::Open;
}

bool WatchStream::IsStarted() const {
  firestore_queue_->VerifyIsCurrentQueue();
  const bool is_starting = (state_ == State::Auth || state_ == State::Backoff);
  return is_starting || IsOpen();
}

void WatchStream::CloseDueToIdleness() {
  firestore_queue_->VerifyIsCurrentQueue();

  if (IsOpen()) {
    Stop();
    // When timing out an idle stream there's no reason to force the stream into
    // backoff when it restarts.
    CancelBackoff();
  }
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
