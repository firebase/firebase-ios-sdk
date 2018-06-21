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

#include <grpcpp/create_channel.h>
#include <utility>

#include "Firestore/Source/Remote/FSTDatastore.h"
#include "Firestore/Source/Remote/FSTStream.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
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
  bidi_stream_->Write(buffer_.back(), &kWriteTag);
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
                         FSTSerializerBeta* serializer)
    : database_info_{&database_info},
      firestore_queue_{async_queue},
      credentials_provider_{credentials_provider},
      stub_{CreateStub()},
      dedicated_executor_{CreateExecutor()},
      objc_bridge_{serializer},
      backoff_{firestore_queue_, timer_id, kBackoffInitialDelay,
               kBackoffMaxDelay, kBackoffFactor} {
  dedicated_executor_->Execute([this] { PollGrpcQueue(); });
}

PseudoDatastore::~PseudoDatastore() {
  grpc_queue_.Shutdown();
  dedicated_executor_->ExecuteBlocking([] {});
}

void PseudoDataStore::PollGrpcQueue() {
  FIREBASE_ASSERT_MESSAGE(dedicated_executor_->IsCurrentExecutor(), "TODO");

  void* tag = nullptr;
  bool ok = false;
  while (grpc_queue_.Next(&tag, &ok)) {
    auto* func = static_cast<std::function<void(bool)>*>(tag);
    firestore_queue_->Enqueue([func] {
      (*func)();
      delete func;
    });
  }
}

std::unique_ptr<util::internal::Executor> PseudoDatastore::CreateExecutor() {
  const auto queue = dispatch_queue_create(
      "com.google.firebase.firestore.watchstream", DISPATCH_QUEUE_SERIAL);
  return absl::make_unique<util::internal::ExecutorLibdispatch>(queue);
}

void WatchStream::Enable() {
  firestore_queue_->VerifyIsCurrentQueue();
  state_ = State::Initial;
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
void WatchStream::ResumeStartAfterAuth(const util::StatusOr<Token>& maybe_token) {
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
  context_ = objc_bridge_.CreateContext(database_info_->database_id(), token);
  bidi_stream_ = stub_.PrepareCall(context_.get(),
                            "/google.firestore.v1beta1.Firestore/Listen",
                            &grpc_queue_);
  // TODO: if !bidi_stream_

  buffered_writer_.SetCall(bidi_stream_.get());
  bidi_stream_->StartCall(&kStartTag);
  // TODO: set state to open here, or only upon successful completion?
  // Objective-C does it here.

  // TODO: callback filter
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

  FIREBASE_ASSERT_MESSAGE(!IsStarted(), "Can only cancel backoff after an error (was %s)", state_);

  // Clear the error condition.
  state_ = State::Initial;
  backoff_.Reset();
}

void WatchStream::OnSuccessfulStart() {
  firestore_queue_->VerifyIsCurrentQueue();

  state_ = State::Open;
  buffered_writer_.Start();
  bidi_stream_->Read(&last_read_message_, &kReadTag);

  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidOpen];
}

void WatchStream::OnSuccessfulRead() {
  firestore_queue_->VerifyIsCurrentQueue();

  auto* proto = objc_bridge_.ToProto<GCFSListenResponse>(last_read_message_);
  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidChange:objc_bridge_.GetWatchChange(proto)
                 snapshotVersion:objc_bridge_.GetSnapshotVersion(proto)];

  bidi_stream_->Read(&last_read_message_, &kReadTag);
}

void WatchStream::OnSuccessfulWrite() {
  firestore_queue_->VerifyIsCurrentQueue();
  buffered_writer_.OnSuccessfulWrite();
}

void WatchStream::OnFinish() {
  firestore_queue_->VerifyIsCurrentQueue();

  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamWasInterruptedWithError:nil];  // FIXME
  delegate_ = nil;
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

  bidi_stream_->Finish(&status_, &kFinishTag);
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

bool WatchStream::IsEnabled() const {
  firestore_queue_->VerifyIsCurrentQueue();
  return state_ != State::Stopped;
}

void WatchStream::Stop() {
  // LogDebug(@"%@ %p stop", NSStringFromClass([self class]), (__bridge void *)self);
  if (IsStarted()) {
    Close();
  }
}

// Private

void WatchStream::Close(const absl::optional<grpc::Status> error) {
  firestore_queue_->VerifyIsCurrentQueue();

  // [self cancelIdleCheck];
  backoff_.Cancel();

  if (error) {
    CloseOnError(error.value());
  } else {
    CloseNormally();
  }

  // This state must be assigned before calling `notifyStreamInterrupted` to allow the callback to
  // inhibit backoff or otherwise manipulate the state in its non-started state.

  // TODO: [self.callbackFilter suppressCallbacks];
  // TODO: _callbackFilter = nil;

  bidi_stream_.reset();

  // If the caller explicitly requested a stream stop, don't notify them of a closing stream (it
  // could trigger undesirable recovery logic, etc.).
  if (error) {
    // TODO: [self notifyStreamInterruptedWithError:error.value()];
  }

  // PORTING NOTE: notifyStreamInterruptedWithError may have restarted the stream with a new
  // delegate so we do /not/ want to clear the delegate here. And since we've already suppressed
  // callbacks via our callbackFilter, there is no worry about bleed through of events from GRPC.
}

void WatchStream::CloseOnError(const Error error) {
  if (error == Error::ResourceExhausted) {
  //LogDebug("%@ %p Using maximum backoff delay to prevent overloading the backend.", [self class],
  //       (__bridge void *)self);
    backoff_.ResetToMax();
  }
  state_ = State::Error;
}

void WatchStream::CloseNormally() {
  // If this is an intentional close ensure we don't delay our next connection attempt.
  backoff_.Reset();
  //LogDebug("%@ %p Performing stream teardown", [self class], (__bridge void *)self);
  // TODO: [self tearDown];

    // Clean up the underlying RPC. If this close: is in response to an error, don't attempt to
    // call half-close to avoid secondary failures.
  if (self.requestsWriter) {
      FSTLog(@"%@ %p Closing stream client-side", [self class], (__bridge void *)self);
      @synchronized(self.requestsWriter) {
        [self.requestsWriter finishWithError:nil];
      }
    }
    //_requestsWriter = nil;
  }
  state_ = State::Stopped;
}

void WatchStream::CloseDueToIdleness() {
  firestore_queue_->VerifyIsCurrentQueue();

  if (IsOpen()) {
    Close();
    // When timing out an idle stream there's no reason to force the stream into backoff when
    // it restarts.
    CancelBackoff();
    // TODO: porting note. It's probably better to avoid the ability to set any state as final
    // state, it should be just Stopped|Error.
  }
}

// TESTING

const char* WatchStream::pemRootCertsPath = nullptr;

grpc::GenericStub WatchStream::CreateStub() const {
  if (pemRootCertsPath) {
    grpc::SslCredentialsOptions options;
    std::fstream file{pemRootCertsPath};
    std::stringstream buffer;
    buffer << file.rdbuf();
    const std::string cert = buffer.str();
    options.pem_root_certs = cert;

    grpc::ChannelArguments args;
    args.SetSslTargetNameOverride("test_cert_2");
    // args.SetSslTargetNameOverride("test_cert_4");
    return grpc::GenericStub{grpc::CreateCustomChannel(
        database_info_->host(), grpc::SslCredentials(options), args)};
  }
  return grpc::GenericStub{
      grpc::CreateChannel(database_info_->host(),
                          grpc::SslCredentials(grpc::SslCredentialsOptions()))};
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
