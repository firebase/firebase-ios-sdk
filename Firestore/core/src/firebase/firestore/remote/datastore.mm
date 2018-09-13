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

#include "Firestore/core/src/firebase/firestore/remote/datastore.h"

#include <unordered_set>

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_completion.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "absl/memory/memory.h"
#include "absl/strings/str_cat.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::CredentialsProvider;
using auth::Token;
using core::DatabaseInfo;
using model::DocumentKey;
using util::AsyncQueue;
using util::Status;
using util::StatusOr;
using util::internal::Executor;
using util::internal::ExecutorLibdispatch;

namespace {

std::unique_ptr<Executor> CreateExecutor() {
  auto queue = dispatch_queue_create("com.google.firebase.firestore.rpc",
                                     DISPATCH_QUEUE_SERIAL);
  return absl::make_unique<ExecutorLibdispatch>(queue);
}

std::string MakeString(grpc::string_ref grpc_str) {
  return {grpc_str.begin(), grpc_str.size()};
}

absl::string_view MakeStringView(grpc::string_ref grpc_str) {
  return {grpc_str.begin(), grpc_str.size()};
}

template <typename T>
void LogGrpcCallFinished(absl::string_view rpc_name,
                         T *call,
                         const Status &status) {
  LOG_DEBUG("RPC %s completed. Error: %s: %s", rpc_name, status.code(),
            status.error_message());
  if (bridge::IsLoggingEnabled()) {
    auto headers =
        Datastore::GetWhitelistedHeadersAsString(call->GetResponseHeaders());
    LOG_DEBUG("RPC %s returned headers (whitelisted): %s", rpc_name, headers);
  }
}

template <typename T>
void RemoveGrpcCall(std::vector<std::unique_ptr<T>> *container, T *to_remove) {
  auto found = std::find_if(container->begin(), container->end(),
                            [to_remove](const std::unique_ptr<T> &call) {
                              return call.get() == to_remove;
                            });
  HARD_ASSERT(found != container->end(), "Missing gRPC call");
  container->erase(found);
}

}  // namespace

Datastore::Datastore(const DatabaseInfo &database_info,
                     AsyncQueue *worker_queue,
                     CredentialsProvider *credentials,
                     FSTSerializerBeta *serializer)
    : grpc_connection_{database_info, worker_queue, &grpc_queue_},
      worker_queue_{worker_queue},
      credentials_{credentials},
      rpc_executor_{CreateExecutor()},
      serializer_bridge_{serializer} {
  rpc_executor_->Execute([this] { PollGrpcQueue(); });
}

void Datastore::Shutdown() {
  for (auto &call : lookup_calls_) {
    call->Cancel();
  }
  lookup_calls_.clear();

  // `grpc::CompletionQueue::Next` will only return `false` once `Shutdown` has
  // been called and all submitted tags have been extracted. Without this call,
  // `rpc_executor_` will never finish.
  grpc_queue_.Shutdown();
  // Drain the executor to make sure it extracted all the operations from gRPC
  // completion queue.
  rpc_executor_->ExecuteBlocking([] {});
}

void Datastore::PollGrpcQueue() {
  HARD_ASSERT(rpc_executor_->IsCurrentExecutor(),
              "PollGrpcQueue should only be called on the "
              "dedicated Datastore executor");

  void *tag = nullptr;
  bool ok = false;
  while (grpc_queue_.Next(&tag, &ok)) {
    auto completion = static_cast<GrpcCompletion *>(tag);
    // While it's valid in principle, we never deliberately pass a null pointer
    // to gRPC completion queue and expect it back. This assertion might be
    // relaxed if necessary.
    HARD_ASSERT(tag, "gRPC queue returned a null tag");
    completion->Complete(ok);
  }
}

std::shared_ptr<WatchStream> Datastore::CreateWatchStream(
    id<FSTWatchStreamDelegate> delegate) {
  return std::make_shared<WatchStream>(worker_queue_, credentials_,
                                       serializer_bridge_.GetSerializer(),
                                       &grpc_connection_, delegate);
}

std::shared_ptr<WriteStream> Datastore::CreateWriteStream(
    id<FSTWriteStreamDelegate> delegate) {
  return std::make_shared<WriteStream>(worker_queue_, credentials_,
                                       serializer_bridge_.GetSerializer(),
                                       &grpc_connection_, delegate);
}

void Datastore::LookupDocuments(
    const std::vector<DocumentKey> &keys,
    FSTVoidMaybeDocumentArrayErrorBlock completion) {
  grpc::ByteBuffer message = serializer_bridge_.ToByteBuffer(
      serializer_bridge_.CreateLookupRequest(keys));

  auto on_error = [completion](const Status &status) {
    completion(nil, util::MakeNSError(status));
  };

  auto on_success =
      [this, completion](const std::vector<grpc::ByteBuffer> &responses) {
        Status parse_status;
        NSArray<FSTMaybeDocument *> *docs =
            serializer_bridge_.MergeLookupResponses(responses, &parse_status);
        if (!parse_status.ok()) {
          completion(nil, util::MakeNSError(parse_status));
        } else {
          completion(docs, nil);
        }
      };

  WithToken(
      [this, message, on_success, on_error](const Token &token) {
        lookup_calls_.push_back(grpc_connection_.CreateStreamingReader(
            "/google.firestore.v1beta1.Firestore/BatchGetDocuments", token,
            std::move(message)));
        GrpcStreamingReader *call = lookup_calls_.back().get();

        call->Start([this, on_success, on_error, call](
                        const Status &status,
                        const std::vector<grpc::ByteBuffer> &responses) {
          LogGrpcCallFinished("BatchGetDocuments", call, status);
          HandleCallStatus(status);

          if (!status.ok()) {
            on_error(status);
          } else {
            on_success(responses);
          }

          RemoveGrpcCall(&lookup_calls_, call);
        });
      },
      on_error);
}

void Datastore::WithToken(const OnToken &on_token, const OnError &on_error) {
  // Auth may outlive Firestore
  std::weak_ptr<Datastore> weak_this{shared_from_this()};

  credentials_->GetToken([this, weak_this, on_token,
                          on_error](StatusOr<Token> maybe_token) {
    worker_queue_->EnqueueRelaxed([weak_this, maybe_token, on_token, on_error] {
      auto strong_this = weak_this.lock();
      if (!strong_this) {
        return;
      }

      if (!maybe_token.ok()) {
        on_error(maybe_token.status());
      }
      on_token(maybe_token.ValueOrDie());
    });
  });
}

void Datastore::HandleCallStatus(const Status &status) {
  if (status.code() == FirestoreErrorCode::Unauthenticated) {
    credentials_->InvalidateToken();
  }
}

std::string Datastore::GetWhitelistedHeadersAsString(
    const GrpcStream::MetadataT &headers) {
  static std::unordered_set<std::string> whitelist = {
      "date", "x-google-backends", "x-google-netmon-label", "x-google-service",
      "x-google-gfe-request-trace"};

  std::string result;
  for (const auto &kv : headers) {
    if (whitelist.find(MakeString(kv.first)) != whitelist.end()) {
      absl::StrAppend(&result, MakeStringView(kv.first), ": ",
                      MakeStringView(kv.second), "\n");
    }
  }
  return result;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
