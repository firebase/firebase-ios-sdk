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
#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_completion.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/memory/memory.h"
#include "absl/strings/str_cat.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::CredentialsProvider;
using auth::Token;
using core::DatabaseInfo;
using util::AsyncQueue;
using util::Status;
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

}  // namespace

Datastore::Datastore(const DatabaseInfo &database_info,
                     AsyncQueue *worker_queue,
                     CredentialsProvider *credentials,
                     FSTSerializerBeta *serializer)
    : grpc_connection_{database_info, worker_queue, &grpc_queue_},
      worker_queue_{worker_queue},
      credentials_{credentials},
      rpc_executor_{CreateExecutor()},
      serializer_{serializer} {
  rpc_executor_->Execute([this] { PollGrpcQueue(); });
}

void Datastore::Shutdown() {
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
                                       serializer_,
                                       &grpc_connection_, delegate);
}

std::shared_ptr<WriteStream> Datastore::CreateWriteStream(
    id<FSTWriteStreamDelegate> delegate) {
  return std::make_shared<WriteStream>(worker_queue_, credentials_,
                                       serializer_,
                                       &grpc_connection_, delegate);
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
