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

#include <algorithm>
#include <fstream>
#include <sstream>

#include <grpcpp/create_channel.h>
#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/memory/memory.h"
#include "absl/strings/match.h"

#import "Firestore/Source/API/FIRFirestoreVersion.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::CredentialsProvider;
using auth::Token;
using core::DatabaseInfo;
using model::DatabaseId;
using model::DocumentKey;
using util::StringFormat;
using util::internal::ExecutorLibdispatch;

namespace {

std::unique_ptr<util::internal::Executor> CreateExecutor() {
  auto queue = dispatch_queue_create("com.google.firebase.firestore.datastore",
                                     DISPATCH_QUEUE_SERIAL);
  return absl::make_unique<ExecutorLibdispatch>(queue);
}

absl::string_view ToStringView(grpc::string_ref grpc_str) {
  return {grpc_str.begin(), grpc_str.size()};
}

std::string ToString(grpc::string_ref grpc_str) {
  return {grpc_str.begin(), grpc_str.end()};
}

}  // namespace

const char *const kXGoogAPIClientHeader = "x-goog-api-client";
const char *const kGoogleCloudResourcePrefix = "google-cloud-resource-prefix";

Datastore::Datastore(util::AsyncQueue *firestore_queue,
                     const core::DatabaseInfo &database_info)
    : firestore_queue_{firestore_queue},
      database_info_{&database_info},
      grpc_channel_{CreateGrpcChannel()},
      grpc_stub_{grpc_channel_},
      dedicated_executor_{CreateExecutor()} {
  dedicated_executor_->Execute([this] { PollGrpcQueue(); });
}

void Datastore::Shutdown() {
  grpc_queue_.Shutdown();
  // Drain the executor to make sure it extracted all the operations from gRPC
  // completion queue.
  dedicated_executor_->ExecuteBlocking([] {});
}

void Datastore::PollGrpcQueue() {
  HARD_ASSERT(dedicated_executor_->IsCurrentExecutor(),
              "PollGrpcQueue should only be called on the "
              "dedicated Datastore executor");

  void *tag = nullptr;
  bool ok = false;
  while (grpc_queue_.Next(&tag, &ok)) {
    auto operation = static_cast<GrpcOperation *>(tag);
    HARD_ASSERT(tag, "GRPC queue returned a null tag");
    operation->Complete(ok);
  }
}

std::shared_ptr<grpc::Channel> Datastore::CreateGrpcChannel() const {
  return grpc::CreateChannel(
      database_info_->host(),
      grpc::SslCredentials(grpc::SslCredentialsOptions()));
}

void Datastore::EnsureValidGrpcStub() {
  // TODO(varconst): find out in which cases a gRPC channel might shut down.
  // This might be overkill.
  if (!grpc_channel_ ||
      grpc_channel_->GetState(false) == GRPC_CHANNEL_SHUTDOWN) {
    grpc_channel_ = CreateGrpcChannel();
    grpc_stub_ = grpc::GenericStub{grpc_channel_};
  }
}

std::unique_ptr<GrpcStream> Datastore::CreateGrpcStream(
    absl::string_view token,
    absl::string_view path,
    GrpcStreamObserver *observer) {
  EnsureValidGrpcStub();

  auto context = CreateGrpcContext(token);
  auto reader_writer = CreateGrpcReaderWriter(context.get(), path);
  return absl::make_unique<GrpcStream>(
      std::move(context), std::move(reader_writer), observer, firestore_queue_);
}

std::unique_ptr<grpc::ClientContext> Datastore::CreateGrpcContext(
    absl::string_view token) const {
  auto context = absl::make_unique<grpc::ClientContext>();
  if (token.data()) {
    context->set_credentials(grpc::AccessTokenCredentials(token.data()));
  }

  // TODO(dimond): This should ideally also include the grpc version, however,
  // gRPC defines the version as a macro, so it would be hardcoded based on
  // version we have at compile time of the Firestore library, rather than the
  // version available at runtime/at compile time by the user of the library.
  //
  // TODO(varconst): once C++ SDK is ready, this should be "gl-cpp" or similar.
  context->AddMetadata(
      kXGoogAPIClientHeader,
      StringFormat("gl-objc/ fire/%s grpc/",
                   reinterpret_cast<const char *>(FIRFirestoreVersionString)));

  // This header is used to improve routing and project isolation by the
  // backend.
  model::DatabaseId db_id = database_info_->database_id();
  context->AddMetadata(kGoogleCloudResourcePrefix,
                       StringFormat("projects/%s/databases/%s",
                                    db_id.project_id(), db_id.database_id()));
  return context;
}

std::unique_ptr<grpc::GenericClientAsyncReaderWriter>
Datastore::CreateGrpcReaderWriter(grpc::ClientContext *context,
                                  absl::string_view path) {
  return grpc_stub_.PrepareCall(context, path.data(), &grpc_queue_);
}

util::Status Datastore::ConvertStatus(grpc::Status from) {
  if (from.ok()) {
    return {};
  }

  grpc::StatusCode error_code = from.error_code();
  HARD_ASSERT(
      error_code >= grpc::CANCELLED && error_code <= grpc::UNAUTHENTICATED,
      "Unknown gRPC error code: %s", error_code);

  return {static_cast<FirestoreErrorCode>(error_code), from.error_message()};
}

GrpcStream::MetadataT Datastore::ExtractWhitelistedHeaders(
    const GrpcStream::MetadataT &headers) {
  std::string whitelist[] = {"date", "x-google-backends",
                             "x-google-netmon-label", "x-google-service",
                             "x-google-gfe-request-trace"};

  GrpcStream::MetadataT whitelisted_headers;
  for (const auto &kv : headers) {
    auto found = std::find_if(std::begin(whitelist), std::end(whitelist),
                              [&](const std::string &str) {
                                return str.size() == kv.first.size() &&
                                       absl::StartsWithIgnoreCase(
                                           str, ToStringView(kv.first));
                              });
    if (found != std::end(whitelist)) {
      whitelisted_headers.emplace(kv.first, kv.second);
    }
  }

  return whitelisted_headers;
}

std::string Datastore::GetWhitelistedHeadersAsString(
    const GrpcStream::MetadataT &headers) {
  auto whitelisted_headers = ExtractWhitelistedHeaders(headers);

  std::string result;
  for (const auto &kv : whitelisted_headers) {
    result += ToString(kv.first);
    result += ": ";
    result += ToString(kv.second);
    result += "\n";
  }
  return result;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
